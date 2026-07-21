import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../../services/story_service.dart';

/// Visionneuse de stories plein écran (façon Snapchat/Instagram) :
/// barres de progression en haut, avance automatique, photo (5 s) ou vidéo,
/// tap gauche/droite pour naviguer, appui long pour mettre en pause.
class StoryViewer extends StatefulWidget {
  final List<StoryGroup> groups;
  final int startGroup;
  const StoryViewer({super.key, required this.groups, this.startGroup = 0});

  static Future<void> open(BuildContext context, List<StoryGroup> groups, int startGroup) {
    return Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => StoryViewer(groups: groups, startGroup: startGroup),
    ));
  }

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  static const _imageDuration = 5.0; // secondes par photo

  late int _g; // index du groupe (créateur)
  int _i = 0; // index de l'item dans le groupe
  double _progress = 0;
  bool _paused = false;
  Timer? _timer;
  VideoPlayerController? _video;

  StoryGroup get _group => widget.groups[_g];
  StoryItem get _item => _group.items[_i];

  @override
  void initState() {
    super.initState();
    _g = widget.startGroup.clamp(0, widget.groups.length - 1);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    _video?.dispose();
    _video = null;
    _progress = 0;
    if (mounted) setState(() {});

    final item = _item;
    if (item.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(item.mediaUrl));
      _video = c;
      try {
        await c.initialize();
        if (!mounted) return;
        c.play();
        setState(() {});
      } catch (_) {
        _next(); // vidéo illisible → on passe
        return;
      }
    }
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _paused) return;
      final v = _video;
      if (v != null && v.value.isInitialized) {
        final dur = v.value.duration.inMilliseconds;
        _progress = dur > 0 ? v.value.position.inMilliseconds / dur : 0;
      } else {
        _progress += 0.05 / _imageDuration;
      }
      if (_progress >= 1.0) {
        _next();
      } else {
        setState(() {});
      }
    });
  }

  void _next() {
    if (_i < _group.items.length - 1) {
      setState(() => _i++);
      _load();
    } else if (_g < widget.groups.length - 1) {
      setState(() { _g++; _i = 0; });
      _load();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
      _load();
    } else if (_g > 0) {
      setState(() { _g--; _i = widget.groups[_g].items.length - 1; });
      _load();
    } else {
      // déjà au tout début : on relance l'item courant
      _load();
    }
  }

  void _setPaused(bool p) {
    _paused = p;
    if (_video != null && _video!.value.isInitialized) {
      p ? _video!.pause() : _video!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w * 0.33) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _setPaused(true),
        onLongPressEnd: (_) => _setPaused(false),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 250) Navigator.of(context).maybePop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Média ────────────────────────────────────────────────
            Center(
              child: item.isVideo
                  ? (_video != null && _video!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _video!.value.aspectRatio,
                          child: VideoPlayer(_video!))
                      : const CircularProgressIndicator(color: AppColors.primary))
                  : CachedNetworkImage(
                      imageUrl: item.mediaUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: AppColors.primary)),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white24, size: 48),
                    ),
            ),

            // ── Barres de progression ────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8, right: 8,
              child: Row(
                children: List.generate(_group.items.length, (k) {
                  double v;
                  if (k < _i) {
                    v = 1;
                  } else if (k == _i) {
                    v = _progress.clamp(0.0, 1.0);
                  } else {
                    v = 0;
                  }
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── En-tête créateur ─────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 12, right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    backgroundImage: (_group.creatorAvatar != null && _group.creatorAvatar!.isNotEmpty)
                        ? NetworkImage(_group.creatorAvatar!)
                        : null,
                    child: (_group.creatorAvatar == null || _group.creatorAvatar!.isEmpty)
                        ? Text(_group.creatorName.isNotEmpty ? _group.creatorName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '@${_group.creatorName.toLowerCase().replaceAll(' ', '_')}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),

            // ── Légende ──────────────────────────────────────────────
            if (item.caption != null && item.caption!.isNotEmpty)
              Positioned(
                left: 16, right: 16, bottom: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
