import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/video_model.dart';

/// Profil public d'un créateur : infos + bouton Suivre + grille de ses vidéos.
class CreatorProfileScreen extends StatefulWidget {
  final String creatorId;
  final String? creatorName;
  const CreatorProfileScreen({super.key, required this.creatorId, this.creatorName});

  static Future<void> open(BuildContext context, String creatorId, {String? name}) {
    return Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreatorProfileScreen(creatorId: creatorId, creatorName: name),
    ));
  }

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  Map<String, dynamic> _profile = {};
  List<VideoModel> _videos = [];
  bool _loading = true;
  bool _following = false;
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ApiService.getUserProfile(widget.creatorId);
      final v = await ApiService.getCreatorVideos(widget.creatorId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _following = p['is_following'] == true;
        _isMe = p['is_me'] == true;
        _videos = v.map((e) => VideoModel.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final was = _following;
    setState(() => _following = !was);
    try {
      final now = await ApiService.toggleFollow(widget.creatorId);
      if (mounted) setState(() => _following = now);
    } catch (_) {
      if (mounted) setState(() => _following = was);
    }
  }

  String _fmt(dynamic n) {
    final v = (n as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile['username']?.toString() ?? widget.creatorName ?? 'Créateur';
    final bio = _profile['bio']?.toString() ?? '';
    final avatar = _profile['avatar_url']?.toString();

    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('@$name', style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary,
                    backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.black, fontSize: 34, fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: Text('@$name',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(bio, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('${_videos.length}', 'Vidéos'),
                    _stat(_fmt(_profile['followers_count']), 'Abonnés'),
                    _stat(_fmt(_profile['following_count']), 'Abonnements'),
                    _stat(_fmt(_profile['total_likes']), 'Likes'),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_isMe)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _following ? Colors.white12 : AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _following ? 'Abonné ✓' : 'Suivre',
                          style: TextStyle(
                            color: _following ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                if (_videos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('Aucune vidéo', style: TextStyle(color: Colors.white38))),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 9 / 16),
                    itemCount: _videos.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _SingleVideoPlayer.open(context, _videos[i]),
                      child: Container(
                        color: AppColors.normalSurface,
                        child: Stack(fit: StackFit.expand, children: [
                          _CreatorThumb(videoUrl: _videos[i].videoUrl),
                          Positioned(bottom: 4, left: 4, child: Row(children: [
                            const Icon(Icons.play_arrow, color: Colors.white70, size: 12),
                            Text('${_videos[i].views}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ])),
                        ]),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _stat(String value, String label) => Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]);
}

// Miniature générée depuis la vidéo (cache mémoire)
class _CreatorThumb extends StatefulWidget {
  final String videoUrl;
  const _CreatorThumb({required this.videoUrl});
  static final Map<String, String> _cache = {};
  @override
  State<_CreatorThumb> createState() => _CreatorThumbState();
}

class _CreatorThumbState extends State<_CreatorThumb> {
  String? _path;
  @override
  void initState() {
    super.initState();
    _gen();
  }

  Future<void> _gen() async {
    if (_CreatorThumb._cache.containsKey(widget.videoUrl)) {
      setState(() => _path = _CreatorThumb._cache[widget.videoUrl]);
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final t = await VideoThumbnail.thumbnailFile(
        video: widget.videoUrl, thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG, maxWidth: 200, quality: 50);
      if (t != null && mounted) { _CreatorThumb._cache[widget.videoUrl] = t; setState(() => _path = t); }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => _path != null
      ? Image.file(File(_path!), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.white24, size: 30))
      : const Center(child: Icon(Icons.play_circle_fill, color: Colors.white24, size: 30));
}

// Lecteur plein écran pour une vidéo (cache disque, boucle)
class _SingleVideoPlayer extends StatefulWidget {
  final VideoModel video;
  const _SingleVideoPlayer({required this.video});

  static void open(BuildContext context, VideoModel v) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _SingleVideoPlayer(video: v)));
  }

  @override
  State<_SingleVideoPlayer> createState() => _SingleVideoPlayerState();
}

class _SingleVideoPlayerState extends State<_SingleVideoPlayer> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    await _c!.initialize();
    _c!.setLooping(true);
    _c!.play();
    ApiService.registerView(widget.video.id);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _c!.value.isPlaying ? _c!.pause() : _c!.play()),
        child: Stack(fit: StackFit.expand, children: [
          if (_ready && _c != null)
            FittedBox(fit: BoxFit.cover, child: SizedBox(
              width: _c!.value.size.width, height: _c!.value.size.height, child: VideoPlayer(_c!)))
          else
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          SafeArea(child: Align(alignment: Alignment.topLeft, child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)))),
          Positioned(left: 16, right: 16, bottom: 40, child: Text(
            widget.video.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}
