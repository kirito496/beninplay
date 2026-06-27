import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/video_model.dart';
import '../profile/creator_profile_screen.dart';

class VideoFeedScreen extends StatefulWidget {
  final bool isDark;
  final int startIndex;
  final bool isTabActive;
  final int refreshKey;
  final VoidCallback? onOpenLive;
  final VoidCallback? onOpenMessages;

  const VideoFeedScreen({
    super.key,
    this.isDark = false,
    this.startIndex = 0,
    this.isTabActive = true,
    this.refreshKey = 0,
    this.onOpenLive,
    this.onOpenMessages,
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

class _VideoFeedScreenState extends State<VideoFeedScreen> {
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
    _loadVideos();
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

  // Initialise le contrôleur pour un index donné (avec cache disque)
  Future<void> _initController(int index) async {
    if (_controllers.containsKey(index)) return;
    if (index < 0 || index >= _videos.length) return;
    final video = _videos[index];

    VideoPlayerController ctrl;
    try {
      // Récupère depuis le cache disque (télécharge 1 seule fois, puis 0 data)
      final fileInfo = await DefaultCacheManager().getSingleFile(video.videoUrl);
      if (!mounted) return;
      ctrl = VideoPlayerController.file(
        File(fileInfo.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
    } catch (_) {
      // Si le cache échoue, lecture réseau directe
      if (!mounted) return;
      ctrl = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
    }

    // Vérifie qu'on n'a pas été disposé pendant le téléchargement
    if (!_controllers.containsKey(index) && (index - _currentIndex).abs() > 1) {
      ctrl.dispose();
      return;
    }
    _controllers[index] = ctrl;
    await ctrl.initialize();
    ctrl.setLooping(true);
    if (index == _currentIndex && widget.isTabActive) {
      ctrl.play();
    }
    if (mounted) setState(() {});
  }

  // Nettoie les contrôleurs trop loin de l'index actuel (économise la RAM et le réseau)
  void _cleanupControllers(int currentIdx) {
    final toRemove = _controllers.keys
        .where((i) => (i - currentIdx).abs() > 1)
        .toList();
    for (final i in toRemove) {
      _controllers[i]?.dispose();
      _controllers.remove(i);
    }
  }

  void _onPageChanged(int index) {
    // Pause ancienne vidéo
    _controllers[_currentIndex]?.pause();

    setState(() => _currentIndex = index);

    // Joue la nouvelle
    _controllers[index]?.play();

    // Compte la vue
    _registerView(index);

    // Précharge la suivante
    _initController(index + 1);

    // Nettoie les anciennes
    _cleanupControllers(index);

    // Charge plus de vidéos si proche de la fin
    if (index >= _videos.length - 3) _loadVideos();
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
  }

  Future<void> _loadVideos() async {
    if (!_hasMore) return;
    try {
      final List<Map<String, dynamic>> raw;
      if (_showFollowing) {
        raw = await ApiService.getFollowingFeed(page: _page);
      } else {
        final data = await ApiService.getVideos(page: _page);
        final List<dynamic> list = data['videos'] ?? data['data'] ?? [];
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
        // Vidéo d'accueil seulement dans "Pour toi"
        if (!_showFollowing) _videos.add(_fallbackVideo);
        if (fetched.length < 20) _hasMore = false;
        _page++;
        _isLoading = false;
        if (_videos.isNotEmpty) {
          _currentIndex = widget.startIndex.clamp(0, _videos.length - 1);
        }
      });
      // Initialise la première vidéo + précharge la suivante
      await _initController(_currentIndex);
      await _initController(_currentIndex + 1);
      // Compte la vue de la première vidéo affichée
      _registerView(_currentIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_videos.isEmpty) _videos = [_fallbackVideo];
      });
      await _initController(0);
    }
  }

  @override
  void dispose() {
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabButton(label: 'Pour toi', isSelected: !_showFollowing, onTap: () => _switchTab(false)),
            const SizedBox(width: 20),
            _TabButton(label: 'Abonnements', isSelected: _showFollowing, onTap: () => _switchTab(true)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 26),
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
        ),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SearchSheet(),
    );
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
  const _VideoPage({
    required this.video,
    required this.isActive,
    this.controller,
    this.likedOverride,
    this.likeCountOverride,
    this.onLikeChanged,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  bool _isLiked = false;
  bool _isFollowing = false;
  int _likes = 0;
  bool _showPauseIcon = false;
  bool _isBuffering = false;
  bool _showDescription = false;

  VideoPlayerController? get _ctrl => widget.controller;
  bool get _isInitialized => _ctrl?.value.isInitialized ?? false;

  @override
  void initState() {
    super.initState();
    // Reprend l'état mémorisé s'il existe, sinon les données API
    _likes = widget.likeCountOverride ?? widget.video.likes;
    _isLiked = widget.likedOverride ?? widget.video.isLiked;
    _ctrl?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final buffering = _ctrl?.value.isBuffering ?? false;
    if (buffering != _isBuffering) {
      setState(() => _isBuffering = buffering);
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

  Future<void> _toggleLike() async {
    if (widget.video.id == 'bee_fallback') return;
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });
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
    try {
      final now = await ApiService.toggleFollow(widget.video.creatorId);
      if (mounted) setState(() => _isFollowing = now);
    } catch (_) {
      if (mounted) setState(() => _isFollowing = was);
    }
  }

  void _openCreator() {
    if (widget.video.id == 'bee_fallback') return;
    CreatorProfileScreen.open(context, widget.video.creatorId, name: widget.video.creatorName);
  }

  void _share() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Partager la vidéo',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareOption(
                  icon: Icons.link,
                  label: 'Copier lien',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lien copié !'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _ShareOption(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => Navigator.pop(context),
                ),
                _ShareOption(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () => Navigator.pop(context),
                ),
                _ShareOption(
                  icon: Icons.send,
                  label: 'Message',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _subscribe() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary,
              child: Text(
                widget.video.creatorName[0],
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.video.creatorName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Soutenez ce créateur',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Envoyer un tip',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [100, 250, 500, 1000].map((amount) =>
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tip de $amount FCFA envoyé à ${widget.video.creatorName} ❤️'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '$amount F',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('S\'abonner au créateur — 2 000 FCFA/mois'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Vidéo ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _togglePlayPause,
          // Glisser vers la gauche → ouvre le profil du créateur
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -250) _openCreator();
          },
          child: Container(
            color: Colors.black,
            child: _isInitialized && _ctrl != null
                ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child: VideoPlayer(_ctrl!),
              ),
            )
                : const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
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

        // ── Infos créateur + description (BAS GAUCHE) ────────────────────
        Positioned(
          left: 16,
          right: 80,
          bottom: bottomPadding + 60,
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
              const Row(
                children: [
                  Icon(Icons.music_note, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Musique béninoise originale',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Actions droite ────────────────────────────────────────────────
        Positioned(
          right: 10,
          bottom: bottomPadding + 65,
          child: Column(
            children: [
              _ActionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.white,
                label: _formatCount(_likes),
                onTap: _toggleLike,
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icons.comment_outlined,
                label: _formatCount(widget.video.comments),
                onTap: () => _showComments(context),
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icons.share_outlined,
                label: 'Partager',
                onTap: _share,
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icons.monetization_on_outlined,
                label: 'Soutenir',
                color: AppColors.accent,
                onTap: _subscribe,
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
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
                final author = (c['author_name'] ?? c['user_name'] ?? c['phone'] ?? 'Anonyme').toString();
                final content = (c['content'] ?? '').toString();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 16,
                    child: Text(
                      author.isNotEmpty ? author[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(author, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                );
              },
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

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
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
