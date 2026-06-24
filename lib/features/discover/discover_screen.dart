import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/video_model.dart';
import '../feed/video_feed_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<VideoModel> _videos = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _trends = [
    {'tag': '#DanceBénin',       'color': AppColors.primary},
    {'tag': '#CuisineBéninoise', 'color': Colors.orange},
    {'tag': '#HumourBénin',      'color': Colors.purple},
    {'tag': '#CotoviMusique',    'color': Colors.blue},
    {'tag': '#BeninPlay',        'color': AppColors.accent},
    {'tag': '#VodounVibes',      'color': Colors.red},
    {'tag': '#MusiqueAfro',      'color': Colors.teal},
    {'tag': '#BeninFashion',     'color': Colors.pink},
  ];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final data = await ApiService.getVideos(page: 1);
      final List<dynamic> raw = data['videos'] ?? [];
      final fetched = raw
          .whereType<Map<String, dynamic>>()
          .where((v) => (v['video_url'] ?? '').toString().isNotEmpty)
          .map((v) => VideoModel.fromJson(v))
          .toList();
      if (mounted) setState(() { _videos = fetched; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<VideoModel> get _filteredVideos {
    if (_query.isEmpty) return _videos;
    final q = _query.toLowerCase();
    return _videos.where((v) =>
        v.title.toLowerCase().contains(q) ||
        v.creatorName.toLowerCase().contains(q) ||
        (v.description ?? '').toLowerCase().contains(q)).toList();
  }

  List<Map<String, dynamic>> get _filteredTrends {
    if (_query.isEmpty) return _trends;
    return _trends.where((t) => t['tag'].toString().toLowerCase().contains(_query.toLowerCase())).toList();
  }

  void _openHashtag(Map<String, dynamic> trend) {
    final tag = (trend['tag'] as String).replaceAll('#', '');
    final tagVideos = _videos.where((v) =>
        v.title.toLowerCase().contains(tag.toLowerCase()) ||
        (v.description ?? '').toLowerCase().contains(tag.toLowerCase())).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (trend['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (trend['color'] as Color).withValues(alpha: 0.5)),
                  ),
                  child: Text(trend['tag'] as String, style: TextStyle(color: trend['color'] as Color, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Text('${tagVideos.length} vidéos', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ]),
            ),
            const Divider(color: Colors.white12, height: 24),
            Expanded(
              child: tagVideos.isEmpty
                  ? const Center(child: Text('Aucune vidéo pour ce hashtag', style: TextStyle(color: Colors.white38)))
                  : GridView.builder(
                      controller: sc,
                      padding: const EdgeInsets.all(4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 9 / 16),
                      itemCount: tagVideos.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => VideoFeedScreen(isDark: false, startIndex: _videos.indexOf(tagVideos[i]))));
                        },
                        child: _VideoThumb(video: tagVideos[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Rechercher des vidéos, créateurs...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            suffixIcon: _query.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18), onPressed: () { _searchController.clear(); setState(() => _query = ''); })
                : null,
            filled: true,
            fillColor: AppColors.normalSurface,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadVideos,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_filteredTrends.isNotEmpty) ...[
                      const Text('🔥 Tendances au Bénin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _filteredTrends.map((t) => GestureDetector(
                          onTap: () => _openHashtag(t),
                          child: _TrendChip(tag: t['tag'] as String, color: t['color'] as Color),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_filteredVideos.isNotEmpty) ...[
                      const Text('📱 Vidéos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 9 / 16),
                        itemCount: _filteredVideos.length,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoFeedScreen(isDark: false, startIndex: _videos.indexOf(_filteredVideos[i])))),
                          child: _VideoThumb(video: _filteredVideos[i]),
                        ),
                      ),
                    ],
                    if (_filteredVideos.isEmpty && _filteredTrends.isEmpty && _query.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(children: [
                            const Icon(Icons.search_off, color: Colors.white24, size: 64),
                            const SizedBox(height: 12),
                            Text('Aucun résultat pour "$_query"', style: const TextStyle(color: Colors.white38, fontSize: 15), textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
                    if (_videos.isEmpty && _query.isEmpty && !_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(children: [
                            Icon(Icons.video_library_outlined, color: Colors.white24, size: 64),
                            SizedBox(height: 12),
                            Text('Aucune vidéo pour le moment', style: TextStyle(color: Colors.white38, fontSize: 15)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String tag;
  final Color color;
  const _TrendChip({required this.tag, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(tag, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final VideoModel video;
  const _VideoThumb({required this.video});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.normalSurface),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video.thumbnailUrl != null)
            Image.network(video.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36))
          else
            const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36),
          Positioned(
            bottom: 4, left: 4,
            child: Row(children: [
              const Icon(Icons.play_arrow, color: Colors.white70, size: 12),
              Text(
                video.views >= 1000 ? '${(video.views / 1000).toStringAsFixed(0)}K' : '${video.views}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}