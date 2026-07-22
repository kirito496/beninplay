import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../profile/creator_profile_screen.dart';
import '../stories/stories_bar.dart';
import '../challenges/challenge_banner.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _query = '';
  bool _loading = true;      // chargement de la page découverte (tendances)
  bool _searching = false;   // recherche en cours

  // Découverte (requête vide)
  List<Map<String, dynamic>> _trendingVideos = [];
  List<Map<String, dynamic>> _popularTags = [];

  // Résultats de recherche
  List<Map<String, dynamic>> _resultVideos = [];
  List<Map<String, dynamic>> _resultUsers = [];

  @override
  void initState() {
    super.initState();
    _loadDiscover();
  }

  Future<void> _loadDiscover() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getTrending(),
      ApiService.getTrendingTags(),
    ]);
    if (!mounted) return;
    setState(() {
      _trendingVideos = results[0];
      _popularTags = results[1];
      _loading = false;
    });
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() { _resultVideos = []; _resultUsers = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(v.trim()));
  }

  Future<void> _runSearch(String q) async {
    final results = await Future.wait([
      ApiService.searchVideos(q),
      ApiService.searchUsers(q),
    ]);
    if (!mounted || _query.trim() != q) return;
    setState(() {
      _resultVideos = results[0];
      _resultUsers = results[1];
      _searching = false;
    });
  }

  void _openCreatorOfVideo(Map<String, dynamic> v) {
    final creator = v['creator'];
    final id = (creator is Map ? creator['id'] : null) ?? v['creator_id'];
    if (id == null) return;
    CreatorProfileScreen.open(context, id.toString(), name: v['creator_name']?.toString());
  }

  void _searchTag(String tag) {
    final clean = tag.replaceAll('#', '');
    _searchController.text = clean;
    _onSearchChanged(clean);
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Rechercher des vidéos, créateurs, #hashtags...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                    onPressed: () { _searchController.clear(); _onSearchChanged(''); })
                : null,
            filled: true,
            fillColor: AppColors.normalSurface,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
      body: _query.trim().length >= 2 ? _buildResults() : _buildDiscover(),
    );
  }

  // ── Page découverte (pas de recherche) ────────────────────────────────────
  Widget _buildDiscover() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return RefreshIndicator(
      onRefresh: _loadDiscover,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Défi à Cagnotte en cours (invisible si aucun) ─────
          const ChallengeBanner(),
          // ── Stories (24 h) ────────────────────────────────────
          const Text('📸 Stories', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const StoriesBar(),
          const SizedBox(height: 20),
          if (_popularTags.isNotEmpty) ...[
            const Text('🔥 Tendances', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: _popularTags.map((t) {
              final tag = (t['tag'] ?? '').toString();
              return GestureDetector(onTap: () => _searchTag(tag), child: _TrendChip(tag: '#$tag'));
            }).toList()),
            const SizedBox(height: 24),
          ],
          if (_trendingVideos.isNotEmpty) ...[
            const Text('📈 Vidéos populaires', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _videoGrid(_trendingVideos),
          ],
          if (_trendingVideos.isEmpty && _popularTags.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Column(children: [
                Icon(Icons.explore_outlined, color: Colors.white24, size: 64),
                SizedBox(height: 12),
                Text('Rien à découvrir pour le moment', style: TextStyle(color: Colors.white38)),
              ])),
            ),
        ]),
      ),
    );
  }

  // ── Résultats de recherche ────────────────────────────────────────────────
  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_resultVideos.isEmpty && _resultUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off, color: Colors.white24, size: 64),
            const SizedBox(height: 12),
            Text('Aucun résultat pour « $_query »',
                style: const TextStyle(color: Colors.white38, fontSize: 15), textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_resultUsers.isNotEmpty) ...[
          const Text('👤 Créateurs', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._resultUsers.map(_creatorTile),
          const SizedBox(height: 20),
        ],
        if (_resultVideos.isNotEmpty) ...[
          const Text('📱 Vidéos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _videoGrid(_resultVideos),
        ],
      ]),
    );
  }

  Widget _creatorTile(Map<String, dynamic> u) {
    final name = (u['username'] ?? 'créateur').toString();
    final avatar = (u['avatar_url'] ?? '').toString();
    final followers = (u['followers_count'] is num) ? (u['followers_count'] as num).toInt() : 0;
    final isCreator = u['is_creator'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => CreatorProfileScreen.open(context, u['id'].toString(), name: name),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Row(children: [
        Flexible(child: Text('@$name', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        if (isCreator) const Padding(
          padding: EdgeInsets.only(left: 6),
          child: Icon(Icons.verified, color: AppColors.primary, size: 15),
        ),
      ]),
      subtitle: Text('$followers abonné${followers > 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }

  Widget _videoGrid(List<Map<String, dynamic>> videos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 9 / 16),
      itemCount: videos.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => _openCreatorOfVideo(videos[i]),
        child: _VideoThumb(video: videos[i]),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String tag;
  const _TrendChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(tag, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final Map<String, dynamic> video;
  const _VideoThumb({required this.video});

  @override
  Widget build(BuildContext context) {
    final thumb = (video['thumbnail_url'] ?? '').toString();
    final views = (video['views'] is num) ? (video['views'] as num).toInt() : 0;
    final locked = video['is_locked'] == true;
    return Container(
      decoration: const BoxDecoration(color: AppColors.normalSurface),
      child: Stack(fit: StackFit.expand, children: [
        if (thumb.isNotEmpty)
          Image.network(thumb, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36))
        else
          const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36),
        if (locked)
          const Positioned(top: 4, right: 4, child: Icon(Icons.lock, color: Colors.white, size: 14)),
        Positioned(
          bottom: 4, left: 4,
          child: Row(children: [
            const Icon(Icons.play_arrow, color: Colors.white70, size: 12),
            Text(views >= 1000 ? '${(views / 1000).toStringAsFixed(0)}K' : '$views',
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }
}
