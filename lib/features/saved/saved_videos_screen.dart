import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/video_model.dart';
import '../../services/saved_videos.dart';
import '../../services/video_cache.dart';
import '../upload/video_effects.dart';

/// Écran « Favoris » : la grille des vidéos enregistrées (façon onglet
/// enregistré de TikTok). Tout est local — aucun appel serveur.
class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedVideosScreen()));
  }

  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  List<VideoModel> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await SavedVideos.all();
    if (mounted) setState(() { _videos = v; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Mes favoris'),
        actions: [
          if (_videos.isNotEmpty)
            IconButton(
              tooltip: 'Tout retirer',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                await SavedVideos.clear();
                _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.bookmark_border, color: Colors.white24, size: 64),
                      SizedBox(height: 16),
                      Text('Aucune vidéo enregistrée',
                          style: TextStyle(color: Colors.white54, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Appuie sur 🔖 sous une vidéo pour la garder ici',
                          style: TextStyle(color: Colors.white30, fontSize: 13)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (_, i) {
                    final v = _videos[i];
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => _SavedPlayer(video: v)),
                        );
                        _load(); // au retour : reflète un éventuel retrait
                      },
                      child: Container(
                        color: const Color(0xFF141414),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (v.thumbnailUrl != null && v.thumbnailUrl!.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: v.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.play_circle_outline, color: Colors.white24),
                              )
                            else
                              const Center(
                                  child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 32)),
                            const Positioned(
                              left: 4, bottom: 4,
                              child: Icon(Icons.bookmark, color: AppColors.accent, size: 16),
                            ),
                            Positioned(
                              left: 6, right: 6, bottom: 22,
                              child: Text(
                                v.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Lecteur plein écran d'UNE vidéo enregistrée (boucle), avec bouton retirer.
class _SavedPlayer extends StatefulWidget {
  final VideoModel video;
  const _SavedPlayer({required this.video});

  @override
  State<_SavedPlayer> createState() => _SavedPlayerState();
}

class _SavedPlayerState extends State<_SavedPlayer> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _saved = true;

  @override
  void initState() {
    super.initState();
    _saved = SavedVideos.isSaved(widget.video.id);
    _init();
  }

  Future<void> _init() async {
    try {
      final file = await VideoCache.getForPlayback(
          widget.video.cacheUrlFor(fast: VideoCache.fastConnection));
      _ctrl = VideoPlayerController.file(file);
    } catch (_) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.video.playbackUrl));
    }
    try {
      await _ctrl!.initialize();
      _ctrl!..setLooping(true)..play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              if (_ctrl == null) return;
              setState(() => _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play());
            },
            child: _ready && _ctrl != null && _ctrl!.value.isInitialized
                ? VideoFilters.apply(
                    widget.video.filter,
                    FittedBox(
                      fit: _ctrl!.value.aspectRatio < 1.0 ? BoxFit.cover : BoxFit.contain,
                      child: SizedBox(
                        width: _ctrl!.value.size.width,
                        height: _ctrl!.value.size.height,
                        child: VideoPlayer(_ctrl!),
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border,
                      color: _saved ? AppColors.accent : Colors.white),
                  onPressed: () async {
                    final now = await SavedVideos.toggle(widget.video);
                    if (mounted) setState(() => _saved = now);
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: Text(
              widget.video.title,
              style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
