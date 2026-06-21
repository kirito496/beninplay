import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> _trends = [
    {'tag': '#DanceBénin',       'views': '2.4M', 'color': AppColors.primary,     'posts': '2 400'},
    {'tag': '#CuisineBéninoise', 'views': '1.8M', 'color': Colors.orange,         'posts': '1 800'},
    {'tag': '#HumourBénin',      'views': '3.1M', 'color': Colors.purple,         'posts': '3 100'},
    {'tag': '#CotoviMusique',    'views': '890K',  'color': Colors.blue,           'posts': '890'},
    {'tag': '#BeninPlay',        'views': '5.2M', 'color': AppColors.accent,      'posts': '5 200'},
    {'tag': '#VodounVibes',      'views': '420K',  'color': Colors.red,            'posts': '420'},
    {'tag': '#MusiqueAfro',      'views': '1.2M', 'color': Colors.teal,           'posts': '1 200'},
    {'tag': '#BeninFashion',     'views': '670K',  'color': Colors.pink,           'posts': '670'},
  ];

  final List<Map<String, dynamic>> _creators = [
    {'name': 'Akossi TV',      'followers': '12K',  'initial': 'A', 'color': AppColors.primary,  'videos': 48},
    {'name': 'Cotonou Vibes',  'followers': '24K',  'initial': 'C', 'color': Colors.orange,      'videos': 32},
    {'name': 'BeninDance',     'followers': '36K',  'initial': 'B', 'color': Colors.purple,      'videos': 65},
    {'name': 'AfroPlay',       'followers': '48K',  'initial': 'A', 'color': Colors.teal,        'videos': 21},
    {'name': 'GoroTV',         'followers': '60K',  'initial': 'G', 'color': Colors.red,         'videos': 87},
    {'name': 'YovoBénin',      'followers': '72K',  'initial': 'Y', 'color': Colors.blue,        'videos': 43},
    {'name': 'DjKofi',         'followers': '84K',  'initial': 'D', 'color': Colors.amber,       'videos': 29},
    {'name': 'AbiodunVlog',    'followers': '96K',  'initial': 'A', 'color': Colors.pink,        'videos': 56},
  ];

  List<Map<String, dynamic>> get _filteredTrends {
    if (_query.isEmpty) { return _trends; }
    return _trends
        .where((t) => t['tag'].toString().toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredCreators {
    if (_query.isEmpty) { return _creators; }
    return _creators
        .where((c) => c['name'].toString().toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  List<VideoModel> get _filteredVideos {
    if (_query.isEmpty) { return VideoModel.mockNormal; }
    return VideoModel.mockNormal
        .where((v) =>
    (v.description ?? '').toLowerCase().contains(_query.toLowerCase()) ||
        v.creatorName.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  void _openHashtag(Map<String, dynamic> trend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => Column(
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (trend['color'] as Color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (trend['color'] as Color).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      trend['tag'] as String,
                      style: TextStyle(
                        color: trend['color'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trend["views"]} vues',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${trend["posts"]} vidéos',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 24),
            Expanded(
              child: GridView.builder(
                controller: sc,
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: VideoModel.mockNormal.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoFeedScreen(isDark: false, startIndex: i),
                      ),
                    );
                  },
                  child: _VideoThumb(video: VideoModel.mockNormal[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreator(Map<String, dynamic> creator) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => StatefulBuilder(
          builder: (ctx, setSt) {
            bool isFollowing = false;
            return Column(
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
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: creator['color'] as Color,
                  child: Text(
                    creator['initial'] as String,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '@${(creator['name'] as String).toLowerCase().replaceAll(' ', '_')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${creator["followers"]} abonnés · ${creator["videos"]} vidéos',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: StatefulBuilder(
                    builder: (ctx2, setSt2) => ElevatedButton(
                      onPressed: () {
                        setSt2(() => isFollowing = !isFollowing);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isFollowing
                              ? 'Vous suivez ${creator["name"]}'
                              : 'Vous ne suivez plus ${creator["name"]}'),
                          backgroundColor: isFollowing ? AppColors.primary : Colors.red,
                          duration: const Duration(seconds: 2),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.white24 : AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(isFollowing ? 'Abonné ✓' : 'Suivre'),
                    ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 24),
                Expanded(
                  child: GridView.builder(
                    controller: sc,
                    padding: const EdgeInsets.all(4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 9 / 16,
                    ),
                    itemCount: VideoModel.mockNormal.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoFeedScreen(isDark: false, startIndex: i),
                          ),
                        );
                      },
                      child: _VideoThumb(
                        video: VideoModel.mockNormal[i % VideoModel.mockNormal.length],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
                ? IconButton(
              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            )
                : null,
            filled: true,
            fillColor: AppColors.normalSurface,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_filteredTrends.isNotEmpty) ...[
              const Text(
                '🔥 Tendances au Bénin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filteredTrends.map((t) => GestureDetector(
                  onTap: () => _openHashtag(t),
                  child: _TrendChip(
                    tag: t['tag'] as String,
                    views: t['views'] as String,
                    color: t['color'] as Color,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            if (_filteredCreators.isNotEmpty) ...[
              const Text(
                '⭐ Créateurs populaires',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredCreators.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openCreator(_filteredCreators[i]),
                    child: _CreatorAvatar(
                      name: _filteredCreators[i]['name'] as String,
                      followers: _filteredCreators[i]['followers'] as String,
                      initial: _filteredCreators[i]['initial'] as String,
                      color: _filteredCreators[i]['color'] as Color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_filteredVideos.isNotEmpty) ...[
              const Text(
                '📱 Vidéos populaires',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: _filteredVideos.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoFeedScreen(isDark: false, startIndex: i),
                    ),
                  ),
                  child: _VideoThumb(video: _filteredVideos[i]),
                ),
              ),
            ],

            if (_filteredTrends.isEmpty &&
                _filteredCreators.isEmpty &&
                _filteredVideos.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off, color: Colors.white24, size: 64),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun résultat pour "$_query"',
                        style: const TextStyle(color: Colors.white38, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String tag;
  final String views;
  final Color color;

  const _TrendChip({required this.tag, required this.views, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tag, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text('$views vues', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  final String name;
  final String followers;
  final String initial;
  final Color color;

  const _CreatorAvatar({
    required this.name,
    required this.followers,
    required this.initial,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Text(
              initial,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(name.split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 11)),
          Text(followers, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
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
          const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36),
          Positioned(
            bottom: 4,
            left: 4,
            child: Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.white70, size: 12),
                Text(
                  '${(video.views / 1000).toStringAsFixed(0)}K',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
