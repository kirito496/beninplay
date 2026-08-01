import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_service.dart';
import '../../core/app_config.dart';
import '../../core/screen_security.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/video_model.dart';
import '../../shared/widgets/momo_pay_sheet.dart';
import '../../shared/widgets/tip_sheet.dart';
import '../profile/creator_profile_screen.dart';
import '../upload/video_effects.dart';
import '../../shared/widgets/bp_logo.dart';
import '../../services/video_cache.dart';
import '../../services/saved_videos.dart';
import '../../services/seen_videos.dart';
import '../search/search_screen.dart';
import '../../main.dart' show routeObserver;
import '../../services/sound_service.dart';
import '../sounds/sound_page_screen.dart';
import '../upload/quick_publish.dart';

class VideoFeedScreen extends StatefulWidget {
  final bool isDark;
  final int startIndex;
  final bool isTabActive;
  final int refreshKey;
  final VoidCallback? onOpenLive;
  final VoidCallback? onOpenDiscover;

  const VideoFeedScreen({
    super.key,
    this.isDark = false,
    this.startIndex = 0,
    this.isTabActive = true,
    this.refreshKey = 0,
    this.onOpenLive,
    this.onOpenDiscover,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

const _beeVideoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
final _fallbackVideo = VideoModel(
  id: 'bee_fallback',
  creatorId: 'beninplay',
  creatorName: 'BeninPlay',
  title: 'Bienvenue sur BeninPlay ! 🇧🇯',
  description: 'Publie ta première vidéo et rejoins la communauté béninoise.',
  videoUrl: _beeVideoUrl,
  zone: VideoZone.normal,
  createdAt: DateTime(2024),
);

class _VideoFeedScreenState extends State<VideoFeedScreen> with RouteAware, WidgetsBindingObserver {
  bool _routeIsTop = true; // le fil est-il l'écran du dessus ?
  late final PageController _pageController;
  int _currentIndex = 0;
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;
  int _lastRefreshKey = 0;
  bool _showFollowing = false; // onglet Abonnements

  // Cache des contrôleurs : seulement current + next pour économiser la bande passante
  final Map<int, VideoPlayerController> _controllers = {};

  // Mémorise l'état des likes pour qu'ils persistent quand on revient sur une vidéo
  final Map<String, bool> _likeState = {};
  final Map<String, int> _likeCount = {};

  @override
  void initState() {
    super.initState();
    _lastRefreshKey = widget.refreshKey;
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this); // pause sur appel/notif/arrière-plan
    // Zone Dark : bloque captures d'écran + enregistrement d'écran
    if (widget.isDark) ScreenSecurity.enable();
    _loadVideos();
  }

  // Appel entrant, volet de notifications, bascule d'appli, écran verrouillé…
  // → tout ce qui interrompt met la vidéo en pause ; on ne reprend qu'au retour
  // réel dans l'appli, si le fil est bien l'écran actif.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.isTabActive && _routeIsTop) {
        final ctrl = _controllers[_currentIndex];
        if (ctrl != null && ctrl.value.isInitialized) ctrl.play();
      }
    } else {
      _controllers[_currentIndex]?.pause();
    }
  }

  @override
  void didUpdateWidget(VideoFeedScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshKey != _lastRefreshKey) {
      _lastRefreshKey = widget.refreshKey;
      _disposeAllControllers();
      setState(() {
        _videos = [];
        _page = 1;
        _hasMore = true;
        _isLoading = true;
      });
      _loadVideos();
    }
    // Pause/resume selon tab active
    if (widget.isTabActive != old.isTabActive) {
      final ctrl = _controllers[_currentIndex];
      if (ctrl != null && ctrl.value.isInitialized) {
        widget.isTabActive ? ctrl.play() : ctrl.pause();
      }
    }
  }

  void _disposeAllControllers() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _controllers.clear();
  }

  // ── Stratégie « toute la connexion pour LA vidéo affichée » ────────────────
  // À chaque défilement, _pageGen change : tout chargement lancé pour une
  // ancienne page devient périmé et est ABANDONNÉ immédiatement (le dispose
  // coupe les téléchargements en cours). Défiler vite = zéro data gaspillée.
  int _pageGen = 0;

  bool _stale(int gen, int index) =>
      !mounted || (gen != _pageGen && index != _currentIndex);

  // Indices dont la vidéo est en cours de téléchargement (évite de lancer
  // deux fois le même téléchargement pendant qu'il est en cours).
  final Set<int> _loading = {};

  // Initialise le contrôleur pour un index donné.
  //
  // CACHE DISQUE : la vidéo est d'abord TÉLÉCHARGÉE EN ENTIER sur le téléphone
  // (VideoCache), puis lue depuis ce fichier local. Donc :
  //  • la lecture en boucle ne reconsomme aucune data
  //  • re-scroller vers une vidéo déjà vue est instantané et hors-ligne
  //
  // [allowPreload] : la SUIVANTE n'est mise en cache qu'UNE FOIS la vidéo
  // affichée entièrement téléchargée — la connexion sert d'abord à finir la
  // vidéo en cours, jamais aux deux en même temps.
  Future<void> _initController(int index, {int? gen, bool allowPreload = true}) async {
    final g = gen ?? _pageGen;
    if (_controllers.containsKey(index) || _loading.contains(index)) return;
    if (index < 0 || index >= _videos.length) return;
    final video = _videos[index];
    if (_stale(g, index)) return;

    _loading.add(index);
    VideoPlayerController? ctrl;
    try {
      // 1) Télécharge la vidéo EN ENTIER vers le disque (ou récupère le cache).
      //    La vidéo REGARDÉE (index courant) = priorité HAUTE : elle passe
      //    devant tous les préchargements et reçoit toute la bande passante.
      final isCurrent = index == _currentIndex;
      // Choix HD / 480p selon la vitesse de connexion mesurée.
      final url = video.cacheUrlFor(fast: VideoCache.fastConnection);

      if (isCurrent) {
        // DÉMARRAGE RAPIDE : si la vidéo est DÉJÀ en cache, on la lit depuis le
        // disque (instantané). Sinon on la LIT EN STREAMING (lecture progressive
        // qui démarre dès les premiers octets) au lieu d'attendre le
        // téléchargement complet → plus d'attente sur connexion lente.
        final cached = await VideoCache.cachedFile(url);
        if (cached != null) {
          ctrl = VideoPlayerController.file(
            cached,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          );
        } else {
          ctrl = VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          );
        }
      } else {
        // Vidéo à venir : on la télécharge en entier sur le disque (priorité
        // basse) pour qu'elle démarre INSTANTANÉMENT quand on y arrivera.
        final file = await VideoCache.prefetch(url);
        if (_stale(g, index) && (index - _currentIndex).abs() > 1) return;
        ctrl = VideoPlayerController.file(
          file,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      }
    } catch (_) {
      // Échec du cache (hors-ligne, disque plein…) → repli : lecture réseau
      // directe pour ne jamais bloquer la lecture.
      if (_stale(g, index) && (index - _currentIndex).abs() > 1) return;
      ctrl = VideoPlayerController.networkUrl(
        Uri.parse(video.playbackUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
    } finally {
      _loading.remove(index);
    }

    if (ctrl == null) return; // abandonnée pendant le téléchargement
    _controllers[index] = ctrl;
    await ctrl.initialize();

    // Zappée pendant l'initialisation → on coupe et libère
    if (_stale(g, index) && (index - _currentIndex).abs() > 1) {
      _controllers.remove(index);
      ctrl.dispose();
      return;
    }

    ctrl.setLooping(true);
    if (index == _currentIndex && widget.isTabActive) {
      ctrl.play();
    }
    if (mounted) setState(() {});

    // La vidéo affichée est ENTIÈREMENT en cache → SEULEMENT MAINTENANT on
    // lance la chaîne de préchargement des suivantes.
    if (allowPreload && index == _currentIndex && g == _pageGen) {
      _prefetchChain(index, g);
    }
  }

  // Nombre de vidéos mises en cache À L'AVANCE au-delà de la suivante.
  // La connexion sert donc à prendre de l'avance pendant que tu regardes.
  static const int _prefetchAhead = 3;

  // Chaîne de préchargement SÉQUENTIELLE : pendant que tu regardes la vidéo
  // courante (déjà entièrement en cache), on télécharge les suivantes UNE PAR
  // UNE → toute la connexion va sur une seule vidéo à la fois (au plus vite),
  // et on prend plusieurs vidéos d'avance. Interrompue dès que tu défiles
  // (le changement de génération arrête la boucle).
  Future<void> _prefetchChain(int currentIdx, int gen) async {
    // 1) La SUIVANTE : contrôleur prêt (swipe instantané).
    await _initController(currentIdx + 1, gen: gen, allowPreload: false);
    // 2) Les vidéos d'après : juste en cache disque, une par une.
    for (int k = 2; k <= _prefetchAhead + 1; k++) {
      if (!mounted || gen != _pageGen) return; // tu as défilé → on arrête
      final i = currentIdx + k;
      if (i >= _videos.length) {
        if (_hasMore) _loadVideos(); // recharge la liste puis la boucle reprendra
        return;
      }
      try {
        final url = _videos[i].cacheUrlFor(fast: VideoCache.fastConnection);
        if (!await VideoCache.isCached(url)) {
          // Priorité basse : si tu arrives entre-temps sur une vidéo non
          // cachée, SON téléchargement (priorité haute) passera devant.
          await VideoCache.prefetch(url); // attend la fin AVANT la suivante
        }
      } catch (_) { /* réseau/disque : on tente la suivante */ }
    }
  }

  // Relance la chaîne de préchargement (quand la vidéo est déjà en cache).
  void _preloadNext(int index, int gen) {
    if (mounted && gen == _pageGen && _currentIndex == index) {
      _prefetchChain(index, gen);
    }
  }

  // Nettoie les contrôleurs : on ne garde QUE la vidéo courante et la
  // suivante. La vidéo PRÉCÉDENTE est libérée aussitôt — son dispose() coupe
  // tout téléchargement/bufferisation en cours → aucune data gaspillée pour
  // une vidéo déjà regardée qu'on ne reverra pas en remontant.
  void _cleanupControllers(int currentIdx) {
    final toRemove = _controllers.keys
        .where((i) => i != currentIdx && i != currentIdx + 1)
        .toList();
    for (final i in toRemove) {
      _controllers[i]?.dispose();
      _controllers.remove(i);
    }
  }

  void _onPageChanged(int index) {
    _pageGen++; // périme tous les chargements des pages précédentes
    final g = _pageGen;

    // Pause ancienne vidéo
    _controllers[_currentIndex]?.pause();

    setState(() => _currentIndex = index);

    // Nettoie d'abord : coupe les téléchargements des vidéos zappées
    _cleanupControllers(index);

    if (_controllers.containsKey(index)) {
      // Déjà prête (préchargée) → lecture immédiate, puis on prépare la suivante
      _controllers[index]?.play();
      _preloadNext(index, g);
    } else {
      // Anti-défilement-rapide : on attend 250 ms que l'utilisateur se pose
      // sur la vidéo avant de charger quoi que ce soit. S'il continue à
      // défiler, RIEN n'est téléchargé pour les vidéos survolées.
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && g == _pageGen && _currentIndex == index) {
          _initController(index, gen: g);
        }
      });
    }

    // Compte la vue
    _registerView(index);

    // (La vidéo suivante est préchargée automatiquement une fois l'actuelle prête.)

    // Charge plus de vidéos si proche de la fin
    if (index >= _videos.length - 3) _loadVideos();
  }

  // Recharge tout le feed (ex: après l'achat d'une vidéo verrouillée)
  void _hardRefresh() {
    _disposeAllControllers();
    setState(() {
      _videos = [];
      _page = 1;
      _hasMore = true;
      _isLoading = true;
      _currentIndex = 0;
    });
    _loadVideos();
  }

  void _switchTab(bool following) {
    if (_showFollowing == following) return;
    _disposeAllControllers();
    setState(() {
      _showFollowing = following;
      _videos = [];
      _page = 1;
      _hasMore = true;
      _isLoading = true;
      _currentIndex = 0;
    });
    _loadVideos();
  }

  // Vues déjà comptées dans cette session (évite le double comptage)
  final Set<String> _viewed = {};

  void _registerView(int index) {
    if (index < 0 || index >= _videos.length) return;
    final v = _videos[index];
    if (v.id == 'bee_fallback') return; // pas la vidéo de bienvenue
    if (_viewed.contains(v.id)) return;
    _viewed.add(v.id);
    ApiService.registerView(v.id);
    SeenVideos.add(v.id); // mémorise pour ne plus la reproposer
  }

  Future<void> _loadVideos() async {
    if (!_hasMore) return;
    try {
      final List<Map<String, dynamic>> raw;
      if (widget.isDark) {
        // Feed Dark : source totalement séparée
        raw = await ApiService.getDarkVideos(page: _page);
      } else if (_showFollowing) {
        raw = await ApiService.getFollowingFeed(page: _page);
      } else {
        // Fil "Pour toi" : on envoie les vidéos DÉJÀ VUES pour ne jamais
        // retomber sur les mêmes (même en rafraîchissant).
        final exclude = await SeenVideos.excludeParam();
        var data = await ApiService.getVideos(page: _page, exclude: exclude);
        List<dynamic> list = data['videos'] ?? data['data'] ?? [];
        // Plus rien de neuf (tout a été vu) → on repart pour un nouveau cycle.
        if (list.isEmpty && _page == 1 && exclude.isNotEmpty) {
          await SeenVideos.reset();
          data = await ApiService.getVideos(page: _page);
          list = data['videos'] ?? data['data'] ?? [];
        }
        raw = list.whereType<Map<String, dynamic>>().toList();
      }
      if (!mounted) return;
      final fetched = raw
          .where((v) => (v['video_url'] ?? '').toString().isNotEmpty)
          .map((v) => VideoModel.fromJson(v))
          .toList();
      setState(() {
        _videos.removeWhere((v) => v.id == 'bee_fallback');
        _videos.addAll(fetched);
        // Vidéo d'accueil seulement dans "Pour toi" (jamais en Zone Dark)
        if (!_showFollowing && !widget.isDark) _videos.add(_fallbackVideo);
        if (fetched.length < 20) _hasMore = false;
        _page++;
        _isLoading = false;
        if (_videos.isNotEmpty) {
          _currentIndex = widget.startIndex.clamp(0, _videos.length - 1);
        }
      });
      // Première vidéo en priorité ; la suivante se prépare une fois celle-ci prête.
      await _initController(_currentIndex);
      // Compte la vue de la première vidéo affichée
      _registerView(_currentIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Pas de vidéo d'accueil en Zone Dark
        if (_videos.isEmpty && !widget.isDark) _videos = [_fallbackVideo];
      });
      if (_videos.isNotEmpty) await _initController(0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // S'abonne à la route qui contient ce fil pour savoir quand un autre écran
    // s'ouvre par-dessus (didPushNext) ou se referme (didPopNext).
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  // Un autre écran vient de s'ouvrir PAR-DESSUS le fil → on coupe la vidéo
  // (sinon le son continue en arrière-plan).
  @override
  void didPushNext() {
    _routeIsTop = false;
    _controllers[_currentIndex]?.pause();
  }

  // On revient sur le fil (l'écran du dessus s'est refermé) → on reprend, si
  // l'onglet du fil est bien l'onglet actif.
  @override
  void didPopNext() {
    _routeIsTop = true;
    if (widget.isTabActive) {
      final ctrl = _controllers[_currentIndex];
      if (ctrl != null && ctrl.value.isInitialized) ctrl.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    // Retire la protection d'écran en quittant la Zone Dark
    if (widget.isDark) ScreenSecurity.disable();
    _disposeAllControllers();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isDark
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: widget.isDark
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Zone Dark ',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('🔞', style: TextStyle(fontSize: 18)),
                ],
              )
            // FittedBox : si jamais le titre est trop large, il rétrécit au
            // lieu de déborder → plus jamais d'« OVERFLOWED ».
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabButton(label: 'Pour toi', isSelected: !_showFollowing, onTap: () => _switchTab(false)),
                    const SizedBox(width: 18),
                    _TabButton(label: 'Abonnements', isSelected: _showFollowing, onTap: () => _switchTab(true)),
                  ],
                ),
              ),
        titleSpacing: 12,
        actions: widget.isDark
            ? const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.lock, color: Colors.white38, size: 20),
                ),
              ]
            : [
                // Icônes compactes (padding réduit) pour laisser de la place
                // au titre et éviter tout débordement.
                if (widget.onOpenLive != null)
                  IconButton(
                    icon: const _LiveIcon(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 40),
                    splashRadius: 20,
                    onPressed: widget.onOpenLive,
                  ),
                if (widget.onOpenDiscover != null)
                  IconButton(
                    icon: const Icon(Icons.explore_outlined, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 40),
                    splashRadius: 20,
                    tooltip: 'Découvrir',
                    onPressed: widget.onOpenDiscover,
                  ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 25),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 40),
                  splashRadius: 20,
                  onPressed: () => _showSearch(context),
                ),
                const SizedBox(width: 6),
              ],
      ),
      body: _isLoading
          ? const Center(child: _PulsingLogo())
          : _videos.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_showFollowing ? Icons.people_outline : Icons.video_library_outlined,
                color: Colors.white30, size: 64),
            const SizedBox(height: 16),
            Text(
              _showFollowing ? 'Tu ne suis personne' : 'Aucune vidéo pour le moment',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _showFollowing
                  ? 'Suis des créateurs pour voir leurs vidéos ici'
                  : 'Publie la première !',
              style: const TextStyle(color: Colors.white30, fontSize: 13),
            ),
          ],
        ),
      )
          : PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) => _VideoPage(
          video: _videos[index],
          controller: _controllers[index],
          isActive: index == _currentIndex && widget.isTabActive,
          likedOverride: _likeState[_videos[index].id],
          likeCountOverride: _likeCount[_videos[index].id],
          onLikeChanged: (liked, count) {
            _likeState[_videos[index].id] = liked;
            _likeCount[_videos[index].id] = count;
          },
          onUnlocked: _hardRefresh,
        ),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    // Recherche à onglets réelle (Top / Comptes / Vidéos).
    SearchScreen.open(context);
  }
}

// ── Recherche ─────────────────────────────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  List<String> _results = [];
  final List<String> _trending = [
    '#DanceBénin', '#CuisineBéninoise', '#HumourBénin',
    '#BeninPlay', '#CotoviVibes', '#VodounVibes',
  ];

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = [
        'Vidéo : $query au Bénin',
        'Créateur : @${query.toLowerCase()}',
        '#${query.replaceAll(' ', '')}',
        'Son : $query remix',
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Rechercher vidéos, créateurs, #hashtags...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_results.isEmpty) ...[
                    const Text(
                      '🔥 Tendances',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _trending.map((t) => GestureDetector(
                        onTap: () {
                          _controller.text = t;
                          _search(t);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ] else
                    ..._results.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        r.startsWith('#') ? Icons.tag
                            : r.startsWith('Créateur') ? Icons.person
                            : r.startsWith('Son') ? Icons.music_note
                            : Icons.play_circle_outline,
                        color: Colors.white54,
                      ),
                      title: Text(r, style: const TextStyle(color: Colors.white)),
                      onTap: () => Navigator.pop(context),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page vidéo ────────────────────────────────────────────────────────────────

class _VideoPage extends StatefulWidget {
  final VideoModel video;
  final VideoPlayerController? controller;
  final bool isActive;
  final bool? likedOverride;
  final int? likeCountOverride;
  final void Function(bool liked, int count)? onLikeChanged;
  final VoidCallback? onUnlocked;
  const _VideoPage({
    required this.video,
    required this.isActive,
    this.controller,
    this.likedOverride,
    this.likeCountOverride,
    this.onLikeChanged,
    this.onUnlocked,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  // Cache d'abonnement partagé entre TOUTES les vidéos du fil (par créateur) :
  // suivre un créateur sur une vidéo se reflète aussitôt sur ses autres vidéos
  // et survit à un rafraîchissement du fil pendant la session.
  static final Map<String, bool> _followCache = {};

  bool _isLiked = false;
  bool _likePop = false; // animation "pop" du cœur au like
  bool _savePop = false; // animation "pop" du bouton Enregistrer
  bool _bigHeart = false; // grand cœur au double-tap (façon TikTok)
  int _heartBurst = 0; // clé incrémentale : relance la volée de cœurs
  bool _isFollowing = false;
  int _likes = 0;
  bool _showPauseIcon = false;
  bool _isBuffering = false;
  bool _showDescription = false;
  bool _reportedComplete = false;

  VideoPlayerController? get _ctrl => widget.controller;
  bool get _isInitialized => _ctrl?.value.isInitialized ?? false;

  @override
  void initState() {
    super.initState();
    // Reprend l'état mémorisé s'il existe, sinon les données API
    _likes = widget.likeCountOverride ?? widget.video.likes;
    _isLiked = widget.likedOverride ?? widget.video.isLiked;
    // État d'abonnement : mémorisé pour la session (voir _followCache) sinon API.
    _isFollowing = _followCache[widget.video.creatorId] ?? widget.video.isFollowing;
    _ctrl?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final buffering = _ctrl?.value.isBuffering ?? false;
    if (buffering != _isBuffering) {
      setState(() => _isBuffering = buffering);
    }
    // Vue "complétée" : regardée à ≥ 90% → signal d'impact créateur (une fois)
    final val = _ctrl?.value;
    if (!_reportedComplete && val != null && val.isInitialized &&
        val.duration.inMilliseconds > 0 &&
        val.position.inMilliseconds >= val.duration.inMilliseconds * 0.9) {
      _reportedComplete = true;
      if (widget.video.id != 'bee_fallback') {
        ApiService.markVideoCompleted(widget.video.id);
      }
    }
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      old.controller?.removeListener(_onControllerUpdate);
      _ctrl?.addListener(_onControllerUpdate);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _togglePlayPause() {
    if (_ctrl == null || !_isInitialized) return;
    setState(() {
      if (_ctrl!.value.isPlaying) {
        _ctrl!.pause();
      } else {
        _ctrl!.play();
      }
      _showPauseIcon = true;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) { setState(() => _showPauseIcon = false); }
    });
  }

  // Double-tap sur la vidéo = like + grand cœur + volée de petits cœurs
  // qui s'envolent (façon TikTok/Instagram).
  void _onDoubleTapLike() {
    if (widget.video.id == 'bee_fallback') return;
    if (!_isLiked) _toggleLike();
    setState(() {
      _bigHeart = true;
      _heartBurst++; // relance une nouvelle volée de cœurs
    });
    Future.delayed(const Duration(milliseconds: 620), () {
      if (mounted) setState(() => _bigHeart = false);
    });
  }

  // Enregistrer / retirer des favoris (persistance locale, aucun serveur).
  Future<void> _toggleSave() async {
    if (widget.video.id == 'bee_fallback') return;
    final now = await SavedVideos.toggle(widget.video);
    if (!mounted) return;
    setState(() => _savePop = true);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _savePop = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 1200),
      behavior: SnackBarBehavior.floating,
      backgroundColor: now ? AppColors.accent : Colors.white24,
      content: Text(now ? 'Ajouté à tes favoris 🔖' : 'Retiré des favoris'),
    ));
  }

  Future<void> _toggleLike() async {
    if (widget.video.id == 'bee_fallback') return;
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
      if (_isLiked) _likePop = true; // le cœur "pop" à l'appui
    });
    if (_isLiked) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) setState(() => _likePop = false);
      });
    }
    // Mémorise tout de suite pour que le like persiste au retour
    widget.onLikeChanged?.call(_isLiked, _likes);
    try {
      await ApiService.likeVideo(widget.video.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likes += wasLiked ? 1 : -1;
        });
        widget.onLikeChanged?.call(_isLiked, _likes);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.video.id == 'bee_fallback') return;
    final was = _isFollowing;
    setState(() => _isFollowing = !was);
    _followCache[widget.video.creatorId] = !was; // reflète sur ses autres vidéos
    final r = await ApiService.toggleFollowResult(widget.video.creatorId);
    if (!mounted) return;
    if (r['success'] == true) {
      final now = r['following'] == true;
      _followCache[widget.video.creatorId] = now;
      setState(() => _isFollowing = now);
    } else {
      // Échec réel → on revient en arrière ET on montre la cause exacte.
      _followCache[widget.video.creatorId] = was;
      setState(() => _isFollowing = was);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        content: Text('Abonnement impossible : ${r['message'] ?? 'erreur inconnue'}'),
      ));
    }
  }

  void _openCreator() {
    if (widget.video.id == 'bee_fallback') return;
    CreatorProfileScreen.open(context, widget.video.creatorId, name: widget.video.creatorName);
  }

  // Ouvre la page du son de cette vidéo (toutes les vidéos qui l'utilisent).
  Future<void> _openSound() async {
    if (widget.video.id == 'bee_fallback') return;
    final sound = await SoundService.byVideo(widget.video.id);
    if (!mounted) return;
    if (sound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Son indisponible pour cette vidéo')));
      return;
    }
    SoundPageScreen.open(context, sound.id);
  }

  void _share() {
    // ⚠️ Règle stricte : les vidéos de la Zone Dark ne sont JAMAIS partageables.
    if (widget.video.isDark) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les vidéos de la Zone Dark ne peuvent pas être partagées.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Lien d'aperçu web (ouvre une page avec miniature + accès à l'app)
    final link = '${AppConfig.api}/v/${widget.video.id}';
    final text = 'Regarde cette vidéo sur BeninPlay 🎬\n"${widget.video.title}"\n$link';
    Share.share(text, subject: widget.video.title);
  }

  // ── Menu « Plus » : signaler la vidéo / bloquer le créateur ────────────────
  // Exigences Google Play pour les applis à contenu utilisateur (UGC).
  void _showMoreMenu(BuildContext context) {
    if (widget.video.id == 'bee_fallback') return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Duo / Stitch (pas sur la Zone Dark).
            if (!widget.video.isDark) ...[
              ListTile(
                leading: const Icon(Icons.dynamic_feed, color: AppColors.primary),
                title: const Text('Duo (côte à côte)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Filme-toi à côté de cette vidéo',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  QuickPublish.record(context, duetSourceId: widget.video.id, label: 'Duo');
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_cut, color: AppColors.accent),
                title: const Text('Stitch (à la suite)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Enchaîne ta vidéo après celle-ci',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  QuickPublish.record(context, stitchSourceId: widget.video.id, label: 'Stitch');
                },
              ),
              const Divider(color: Colors.white12, height: 8),
            ],
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
              title: const Text('Signaler cette vidéo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.error),
              title: Text('Bloquer @${widget.video.creatorName}',
                  style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Ses vidéos disparaîtront de ton fil',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _blockCreator();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
    const reasons = <String, String>{
      'nudite': '🔞 Nudité ou contenu sexuel',
      'violence': '⚔️ Violence',
      'haine': '😡 Discours haineux',
      'arnaque': '💸 Arnaque ou fraude',
      'spam': '📢 Spam',
      'mineur': '🚨 Mineur en danger',
      'autre': '❓ Autre',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Pourquoi signales-tu cette vidéo ?',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...reasons.entries.map((e) => ListTile(
                  dense: true,
                  title: Text(e.value, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final res = await ApiService.reportVideo(widget.video.id, e.key);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res['message']?.toString() ??
                          'Signalement envoyé. Merci !'),
                      backgroundColor: res['success'] == true
                          ? AppColors.success
                          : AppColors.error,
                    ));
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _blockCreator() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: Text('Bloquer @${widget.video.creatorName} ?',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Ses vidéos disparaîtront de ton fil. Tu pourras le débloquer plus tard depuis son profil.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bloquer')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.blockUser(widget.video.creatorId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] == true
          ? '@${widget.video.creatorName} bloqué. Actualise ton fil.'
          : (res['message']?.toString() ?? 'Blocage impossible')),
      backgroundColor:
          res['success'] == true ? AppColors.success : AppColors.error,
    ));
  }

  // Écran de déblocage payant (vidéo vendue à l'unité)
  Widget _buildPaywall(BuildContext context) {
    final price = widget.video.price.toInt();
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF101018)),
        if (widget.video.thumbnailUrl != null && widget.video.thumbnailUrl!.isNotEmpty)
          Image.network(widget.video.thumbnailUrl!, fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.6), colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => const SizedBox()),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 56),
                const SizedBox(height: 16),
                Text(widget.video.title,
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('par @${widget.video.creatorName.toLowerCase().replaceAll(' ', '_')}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final paid = await MomoPaySheet.show(
                      context,
                      amount: price,
                      type: 'video',
                      description: 'Achat vidéo : ${widget.video.title}',
                      videoId: widget.video.id,
                    );
                    if (paid == true) widget.onUnlocked?.call();
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 20),
                  label: Text('Débloquer pour $price FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Paiement unique — accès à vie à cette vidéo',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Vidéo payante non achetée → écran de déblocage
    if (widget.video.isLocked) {
      return _buildPaywall(context);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Vidéo ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTap: _onDoubleTapLike,
          // Glisser vers la gauche → ouvre le profil du créateur
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -250) _openCreator();
          },
          child: Container(
            color: Colors.black,
            child: _isInitialized && _ctrl != null
                ? LayoutBuilder(builder: (context, cts) {
                    final area = Size(cts.maxWidth, cts.maxHeight);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Filtre couleur "façon Snapchat" appliqué à la lecture.
                        VideoFilters.apply(
                          widget.video.filter,
                          SizedBox.expand(
                            child: FittedBox(
                              // Vidéo verticale (aspect < 1) → remplit tout l'écran.
                              // Vidéo horizontale → affichée en entier, sans couper.
                              fit: _ctrl!.value.aspectRatio < 1.0
                                  ? BoxFit.cover
                                  : BoxFit.contain,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: _ctrl!.value.size.width,
                                height: _ctrl!.value.size.height,
                                child: VideoPlayer(_ctrl!),
                              ),
                            ),
                          ),
                        ),
                        // Textes / emojis posés lors de l'édition.
                        OverlayLayer(items: widget.video.overlays, size: area),
                      ],
                    );
                  })
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // Miniature affichée INSTANTANÉMENT pendant que la
                      // vidéo charge (comme TikTok) — fini l'écran noir.
                      if (widget.video.thumbnailUrl != null &&
                          widget.video.thumbnailUrl!.isNotEmpty)
                        VideoFilters.apply(
                          widget.video.filter,
                          CachedNetworkImage(
                            imageUrl: widget.video.thumbnailUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 80),
                            errorWidget: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2.5),
                      ),
                    ],
                  ),
          ),
        ),

        // ── Volée de petits cœurs qui s'envolent (façon TikTok) ──────────
        if (_heartBurst > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: _FloatingHearts(key: ValueKey(_heartBurst)),
            ),
          ),

        // ── Grand cœur du double-tap (façon TikTok) ──────────────────────
        IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              opacity: _bigHeart ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: AnimatedScale(
                scale: _bigHeart ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.redAccent,
                  size: 96,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 24)],
                ),
              ),
            ),
          ),
        ),

        // ── Icône pause/play ─────────────────────────────────────────────
        if (_showPauseIcon && _ctrl != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _ctrl!.value.isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),

        // ── Buffering ────────────────────────────────────────────────────
        if (_isBuffering && _isInitialized)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ),
          ),

        // ── Gradient bas ─────────────────────────────────────────────────
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Colors.black38, Colors.black87],
                  stops: [0, 0.45, 0.75, 1],
                ),
              ),
            ),
          ),
        ),

        // ── Voile dégradé en bas : le texte reste lisible même sur une
        //    vidéo claire (comme TikTok) ─────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 190,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x59000000),
                    Color(0xA6000000),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Infos créateur + description (BAS GAUCHE) ────────────────────
        Positioned(
          left: 16,
          right: 80,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _openCreator,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        widget.video.creatorName[0],
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: GestureDetector(
                      onTap: _openCreator,
                      child: Text(
                        '@${widget.video.creatorName.toLowerCase().replaceAll(' ', '_')}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (widget.video.creatorVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: AppColors.primary, size: 15),
                  ],
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleFollow,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isFollowing ? Colors.white24 : Colors.transparent,
                        border: Border.all(
                          color: _isFollowing ? Colors.white54 : Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isFollowing ? 'Abonné ✓' : 'Suivre',
                        style: TextStyle(
                          color: _isFollowing ? Colors.white70 : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (widget.video.isBoosted)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.black, size: 11),
                      SizedBox(width: 4),
                      Text('Sponsorisé',
                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              Text(
                widget.video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (widget.video.description != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _showDescription = !_showDescription),
                  child: Text(
                    _showDescription
                        ? widget.video.description!
                        : '${widget.video.description!.substring(0, widget.video.description!.length.clamp(0, 40))}... voir plus',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: _showDescription ? 5 : 1,
                  ),
                ),
              ],

              const SizedBox(height: 6),
              GestureDetector(
                onTap: _openSound,
                child: const Row(
                  children: [
                    Icon(Icons.music_note, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Son original — appuie pour voir',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: Colors.white54, size: 13),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Actions droite ────────────────────────────────────────────────
        Positioned(
          right: 10,
          bottom: 24,
          child: Column(
            children: [
              AnimatedScale(
                scale: _likePop ? 1.35 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: _ActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.white,
                  label: _formatCount(_likes),
                  onTap: _toggleLike,
                ),
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icons.comment_outlined,
                label: _formatCount(widget.video.comments),
                onTap: () => _showComments(context),
              ),
              const SizedBox(height: 18),
              // ── Enregistrer / Favoris (façon TikTok) ────────────────────
              if (widget.video.id != 'bee_fallback') ...[
                ValueListenableBuilder<Set<String>>(
                  valueListenable: SavedVideos.ids,
                  builder: (_, ids, __) {
                    final saved = ids.contains(widget.video.id);
                    return AnimatedScale(
                      scale: _savePop ? 1.35 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: _ActionButton(
                        icon: saved ? Icons.bookmark : Icons.bookmark_border,
                        color: saved ? AppColors.accent : Colors.white,
                        label: saved ? 'Enregistré' : 'Enregistrer',
                        onTap: _toggleSave,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
              ],
              // La Zone Dark n'est jamais partageable → pas de bouton Partager
              if (!widget.video.isDark) ...[
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Partager',
                  onTap: _share,
                ),
                const SizedBox(height: 18),
              ],
              _ActionButton(
                icon: Icons.monetization_on_outlined,
                label: 'Soutenir',
                color: AppColors.accent,
                onTap: () => TipSheet.show(
                  context,
                  creatorId: widget.video.creatorId,
                  creatorName: widget.video.creatorName,
                  videoId: widget.video.id,
                ),
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icons.more_horiz,
                label: 'Plus',
                onTap: () => _showMoreMenu(context),
              ),
              const SizedBox(height: 18),
              _RotatingDisk(
                creatorName: widget.video.creatorName,
                isPlaying: _isInitialized && (_ctrl?.value.isPlaying ?? false),
              ),
            ],
          ),
        ),

        // ── Barre progression ─────────────────────────────────────────────
        if (_isInitialized)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _ctrl!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) { return '${(count / 1000000).toStringAsFixed(1)}M'; }
    if (count >= 1000) { return '${(count / 1000).toStringAsFixed(1)}K'; }
    return count.toString();
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(
        videoId: widget.video.id,
        commentCount: widget.video.comments,
      ),
    );
  }
}

// ── Commentaires (vrais depuis API) ───────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String videoId;
  final int commentCount;
  const _CommentsSheet({required this.videoId, required this.commentCount});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _replyingTo; // @auteur auquel on répond (affiché au-dessus du champ)
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Prépare une réponse : préremplit le champ avec @auteur et donne le focus.
  void _startReply(String author) {
    final handle = '@${author.toLowerCase().replaceAll(' ', '_')}';
    setState(() => _replyingTo = author);
    _ctrl.text = '$handle ';
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    _focus.requestFocus();
  }

  Future<void> _loadComments() async {
    if (widget.videoId == 'bee_fallback') {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await ApiService.getComments(widget.videoId);
      if (mounted) setState(() { _comments = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiService.addComment(widget.videoId, text);
      _ctrl.clear();
      setState(() => _replyingTo = null);
      await _loadComments();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatCount(widget.commentCount)} commentaires',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _comments.isEmpty
                ? const Center(
              child: Text('Aucun commentaire. Sois le premier !',
                  style: TextStyle(color: Colors.white54)),
            )
                : ListView.builder(
              controller: scrollCtrl,
              itemCount: _comments.length,
              itemBuilder: (_, i) {
                final c = _comments[i];
                // Le nom peut arriver aplati (author_name) ou imbriqué
                // (user: {username}) selon la version de l'API.
                final nested = (c['user'] is Map) ? (c['user']['username'] ?? '').toString() : '';
                final author = (c['author_name'] ??
                        (nested.isNotEmpty ? nested : null) ??
                        c['user_name'] ??
                        'Utilisateur')
                    .toString();
                final content = (c['content'] ?? '').toString();
                return _CommentTile(
                  author: author,
                  content: content,
                  onReply: () => _startReply(author),
                );
              },
            ),
          ),
          // Bandeau "Réponse à @x" avec bouton pour annuler.
          if (_replyingTo != null)
            Container(
              width: double.infinity,
              color: Colors.white10,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text('Réponse à @${_replyingTo!.toLowerCase().replaceAll(' ', '_')}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _replyingTo = null);
                      _ctrl.clear();
                    },
                    child: const Icon(Icons.close, color: Colors.white38, size: 16),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 12, right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tuile de commentaire : like (local) + Répondre ──────────────────────────

class _CommentTile extends StatefulWidget {
  final String author;
  final String content;
  final VoidCallback onReply;
  const _CommentTile({
    required this.author,
    required this.content,
    required this.onReply,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _liked = false;
  int _likes = 0;

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 16,
            child: Text(
              widget.author.isNotEmpty ? widget.author[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.author,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(widget.content,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: widget.onReply,
                  child: const Text('Répondre',
                      style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? Colors.red : Colors.white38,
                  size: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(_likes > 0 ? '$_likes' : '',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color = Colors.white,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Volée de cœurs qui montent et s'estompent (double-tap) ──────────────────

class _FloatingHearts extends StatefulWidget {
  const _FloatingHearts({super.key});

  @override
  State<_FloatingHearts> createState() => _FloatingHeartsState();
}

class _FloatingHeartsState extends State<_FloatingHearts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..forward();

  // 6 cœurs avec un décalage horizontal, une taille et une rotation aléatoires
  // (déterministes à partir de l'index → pas besoin d'import random).
  static const _n = 6;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, cts) {
        final cx = cts.maxWidth / 2;
        final cy = cts.maxHeight / 2;
        return AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            return Stack(
              children: List.generate(_n, (i) {
                final delay = i * 0.06;
                final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
                if (p <= 0) return const SizedBox.shrink();
                final dir = (i.isEven ? 1 : -1);
                final spread = 26.0 + (i % 3) * 18.0;
                final dx = dir * spread * p;
                final dy = -160.0 * p * (1 + (i % 2) * 0.25);
                final size = 22.0 + (i % 3) * 8.0;
                final opacity = (1 - p).clamp(0.0, 1.0);
                return Positioned(
                  left: cx + dx - size / 2,
                  top: cy + dy - size / 2,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: dir * 0.25 * p,
                      child: Icon(Icons.favorite,
                          color: i.isEven ? Colors.redAccent : Colors.pinkAccent,
                          size: size),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          if (isSelected) Container(width: 20, height: 2, color: Colors.white),
        ],
      ),
    );
  }
}

class _RotatingDisk extends StatefulWidget {
  final String creatorName;
  final bool isPlaying;
  const _RotatingDisk({required this.creatorName, required this.isPlaying});

  @override
  State<_RotatingDisk> createState() => _RotatingDiskState();
}

class _RotatingDiskState extends State<_RotatingDisk>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) { _ctrl.repeat(); }
  }

  @override
  void didUpdateWidget(_RotatingDisk old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !old.isPlaying) {
      _ctrl.repeat();
    } else if (!widget.isPlaying && old.isPlaying) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          color: AppColors.primary,
        ),
        child: ClipOval(
          child: Center(
            child: Text(
              widget.creatorName[0],
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo pulsant (chargement "hypnotique" du fil) ────────────────────────────

class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25 + t * 0.35),
                blurRadius: 30 + t * 40,
                spreadRadius: 4 + t * 10,
              ),
            ],
          ),
          child: Transform.scale(
            scale: 0.92 + t * 0.16,
            child: const BpLogo(size: 74),
          ),
        );
      },
    );
  }
}

// ── Icône Live avec point rouge qui "respire" ───────────────────────────────

class _LiveIcon extends StatefulWidget {
  const _LiveIcon();

  @override
  State<_LiveIcon> createState() => _LiveIconState();
}

class _LiveIconState extends State<_LiveIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Taille fixe : le point rouge reste À L'INTÉRIEUR des limites (pas d'overflow).
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.live_tv_outlined, color: Colors.white, size: 25),
          Positioned(
            top: 1,
            right: 1,
            child: FadeTransition(
              opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.redAccent.withValues(alpha: 0.7), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
