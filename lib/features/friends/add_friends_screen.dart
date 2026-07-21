import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_service.dart';
import '../../core/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../profile/creator_profile_screen.dart';

/// « Ajouter des amis » : mon QR code à faire scanner + recherche par pseudo.
class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFriendsScreen()));
  }

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  String? _myLink;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadLink() async {
    final id = await ApiService.getCurrentUserId();
    if (mounted && id != null) {
      setState(() => _myLink = '${AppConfig.api}/u/$id');
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final r = await ApiService.searchUsers(q.trim());
    if (mounted) setState(() { _results = r; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = _myLink == null
        ? null
        : 'https://api.qrserver.com/v1/create-qr-code/?size=320x320&margin=8&data=${Uri.encodeQueryComponent(_myLink!)}';
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalBg,
        title: const Text('Ajouter des amis', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Mon QR code ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.18),
                AppColors.accent.withValues(alpha: 0.10),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                const Text('Mon code BeninPlay',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Fais-le scanner pour te suivre',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(10),
                  child: qrUrl == null
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : CachedNetworkImage(
                          imageUrl: qrUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary)),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.qr_code_2, color: Colors.black26, size: 120),
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _myLink == null
                        ? null
                        : () => Share.share('Suis-moi sur BeninPlay 🎬\n${_myLink!}'),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Partager mon profil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Recherche par pseudo ────────────────────────────────
          const Text('Rechercher un ami', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            onChanged: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Pseudo…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Center(child: Padding(padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary)))
          else
            ..._results.map(_userTile),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final id = (u['id'] ?? '').toString();
    final name = (u['username'] ?? 'créateur').toString();
    final avatar = (u['avatar_url'] ?? '').toString();
    final verified = u['is_creator'] == true;
    return _FollowTile(id: id, name: name, avatar: avatar, verified: verified);
  }
}

class _FollowTile extends StatefulWidget {
  final String id, name, avatar;
  final bool verified;
  const _FollowTile({required this.id, required this.name, required this.avatar, required this.verified});

  @override
  State<_FollowTile> createState() => _FollowTileState();
}

class _FollowTileState extends State<_FollowTile> {
  bool _following = false;
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    final now = await ApiService.toggleFollow(widget.id);
    if (mounted) setState(() { _following = now; _busy = false; });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => CreatorProfileScreen.open(context, widget.id, name: widget.name),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
        backgroundImage: widget.avatar.isNotEmpty ? NetworkImage(widget.avatar) : null,
        child: widget.avatar.isEmpty
            ? Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Row(children: [
        Flexible(child: Text('@${widget.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        if (widget.verified)
          const Padding(padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.verified, color: AppColors.primary, size: 15)),
      ]),
      trailing: SizedBox(
        height: 34,
        child: ElevatedButton(
          onPressed: _busy ? null : _toggle,
          style: ElevatedButton.styleFrom(
            backgroundColor: _following ? Colors.white24 : AppColors.primary,
            foregroundColor: _following ? Colors.white : Colors.black,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(_following ? 'Abonné' : 'Suivre', style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
