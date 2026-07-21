import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../profile/creator_profile_screen.dart';

/// Classement des créateurs par score d'impact (vues complétées, likes, etc.).
class CreatorLeaderboard extends StatefulWidget {
  const CreatorLeaderboard({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreatorLeaderboard(),
    );
  }

  @override
  State<CreatorLeaderboard> createState() => _CreatorLeaderboardState();
}

class _CreatorLeaderboardState extends State<CreatorLeaderboard> {
  List<Map<String, dynamic>> _creators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await ApiService.getLeaderboard();
      if (mounted) setState(() { _creators = c; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (_, sc) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('🏆 Classement des créateurs',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Basé sur l\'impact : vues regardées jusqu\'au bout, likes, abonnés',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const Divider(color: Colors.white12, height: 24),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _creators.isEmpty
                    ? const Center(
                        child: Text('Aucun créateur classé pour l\'instant',
                            style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _creators.length,
                        itemBuilder: (_, i) => _row(_creators[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final rank = (c['rank'] as num?)?.toInt() ?? 0;
    final name = (c['username'] ?? 'Créateur').toString();
    final completed = (c['completed_views'] as num?)?.toInt() ?? 0;
    final views = (c['total_views'] as num?)?.toInt() ?? 0;
    final followers = (c['followers'] as num?)?.toInt() ?? 0;
    final score = (c['score'] as num?)?.toInt() ?? 0;
    final id = (c['creator_id'] ?? '').toString();

    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';
    final top3 = rank <= 3;

    return GestureDetector(
      onTap: id.isEmpty ? null : () => CreatorProfileScreen.open(context, id, name: name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: top3 ? AppColors.primary.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: top3 ? AppColors.primary.withValues(alpha: 0.4) : Colors.white12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(medal,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: top3 ? AppColors.primary : Colors.white54,
                    fontSize: top3 ? 22 : 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20, backgroundColor: AppColors.primary,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@$name', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('👁 ${_fmt(completed)} complétées · ${_fmt(views)} vues · ${_fmt(followers)} abonnés',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$score', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('points', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
