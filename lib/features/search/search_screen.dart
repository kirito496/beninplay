import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../profile/creator_profile_screen.dart';

/// Recherche à onglets (façon TikTok) : Top / Comptes / Vidéos.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _users = [];

  final List<String> _trending = const [
    'DanceBénin', 'CuisineBéninoise', 'HumourBénin', 'Cotonou', 'VodounVibes', 'Afrobeats',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    if (q.trim().length < 2) {
      setState(() { _videos = []; _users = []; });
      return;
    }
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.searchVideos(q.trim()),
      ApiService.searchUsers(q.trim()),
    ]);
    if (!mounted) return;
    setState(() {
      _videos = results[0];
      _users = results[1];
      _loading = false;
    });
  }

  void _searchTag(String tag) {
    _ctrl.text = tag;
    _run(tag);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _ctrl.text.trim().length >= 2;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.normalBg,
        appBar: AppBar(
          backgroundColor: AppColors.normalBg,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher vidéos, créateurs, #hashtags…',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () { _ctrl.clear(); _run(''); setState(() {}); },
                      )
                    : null,
                filled: true, fillColor: Colors.white12,
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          bottom: hasQuery
              ? const TabBar(
                  indicatorColor: AppColors.primary,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: [Tab(text: 'Top'), Tab(text: 'Comptes'), Tab(text: 'Vidéos')],
                )
              : null,
        ),
        body: !hasQuery
            ? _buildTrending()
            : _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    children: [
                      _buildTop(),
                      _buildAccounts(),
                      _buildVideos(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTrending() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔥 Tendances', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _trending.map((t) => GestureDetector(
          onTap: () => _searchTag(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Text('#$t', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        )).toList()),
      ]),
    );
  }

  Widget _buildTop() {
    if (_users.isEmpty && _videos.isEmpty) return _empty();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_users.isNotEmpty) ...[
          const Text('👤 Créateurs', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._users.take(4).map(_userTile),
          const SizedBox(height: 16),
        ],
        if (_videos.isNotEmpty) ...[
          const Text('📱 Vidéos', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _videoGrid(_videos),
        ],
      ],
    );
  }

  Widget _buildAccounts() {
    if (_users.isEmpty) return _empty();
    return ListView(padding: const EdgeInsets.all(16), children: _users.map(_userTile).toList());
  }

  Widget _buildVideos() {
    if (_videos.isEmpty) return _empty();
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: _videoGrid(_videos));
  }

  Widget _empty() => const Center(
      child: Text('Aucun résultat', style: TextStyle(color: Colors.white38)));

  Widget _userTile(Map<String, dynamic> u) {
    final id = (u['id'] ?? '').toString();
    final name = (u['username'] ?? 'créateur').toString();
    final avatar = (u['avatar_url'] ?? '').toString();
    final verified = u['is_creator'] == true;
    final followers = (u['followers_count'] is num) ? (u['followers_count'] as num).toInt() : 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => CreatorProfileScreen.open(context, id, name: name),
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
        if (verified)
          const Padding(padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.verified, color: AppColors.primary, size: 15)),
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
      itemBuilder: (_, i) {
        final v = videos[i];
        final thumb = (v['thumbnail_url'] ?? '').toString();
        return GestureDetector(
          onTap: () => CreatorProfileScreen.open(
              context, (v['creator_id'] ?? '').toString(),
              name: (v['creator_name'] ?? 'Créateur').toString()),
          child: Container(
            color: AppColors.normalSurface,
            child: thumb.isNotEmpty
                ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.play_circle_outline, color: Colors.white24))
                : const Center(child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 30)),
          ),
        );
      },
    );
  }
}
