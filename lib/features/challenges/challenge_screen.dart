import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../services/challenge_service.dart';
import '../profile/creator_profile_screen.dart';
import '../upload/quick_publish.dart';

/// Page d'un Défi à Cagnotte : cagnotte, compte à rebours, répartition des
/// prix, classement en direct et bouton « Participer ».
class ChallengeScreen extends StatefulWidget {
  final String challengeId;
  const ChallengeScreen({super.key, required this.challengeId});

  static void open(BuildContext context, String id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeScreen(challengeId: id)));
  }

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  Challenge? _ch;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ch = await ChallengeService.get(widget.challengeId);
    if (mounted) setState(() { _ch = ch; _loading = false; });
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final ch = _ch;
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalBg,
        title: const Text('🏆 Défi à Cagnotte', style: TextStyle(fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ch == null
              ? const Center(child: Text('Défi introuvable', style: TextStyle(color: Colors.white38)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Bannière cagnotte ──────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            const Color(0xFFF5A623).withValues(alpha: 0.30),
                            AppColors.primary.withValues(alpha: 0.12),
                          ]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.5)),
                        ),
                        child: Column(children: [
                          Text('#${ch.hashtag}',
                              style: const TextStyle(color: Color(0xFFF5A623), fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(ch.title, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          if (ch.description != null && ch.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(ch.description!, textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                          const SizedBox(height: 14),
                          Text('${ch.prizePool} FCFA',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                          const Text('de cagnotte réelle 💰', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black38, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              ch.status == 'finished' ? '🏁 Terminé' : '⏳ Fin dans ${ch.remainingLabel}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // ── Répartition ───────────────────────────────
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        _prizeChip('🥇 1er', (ch.prizePool * 0.5).floor()),
                        _prizeChip('🥈 2e', (ch.prizePool * 0.3).floor()),
                        _prizeChip('🥉 3e', (ch.prizePool * 0.2).floor()),
                      ]),
                      const SizedBox(height: 16),

                      if (ch.status != 'finished')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => QuickPublish.record(
                              context,
                              tags: [ch.hashtag],
                              label: 'Participer au défi #${ch.hashtag}',
                            ),
                            icon: const Icon(Icons.videocam, size: 20),
                            label: const Text('Participer maintenant 🎬',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF5A623),
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // ── Classement / Gagnants ─────────────────────
                      Text(ch.status == 'finished' ? '🏆 Les gagnants' : '📊 Classement en direct',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...(() {
                        final rows = ch.status == 'finished' ? ch.winners : ch.leaderboard;
                        if (rows.isEmpty) {
                          return [const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('Aucune participation pour l\'instant.\nSois le premier ! 🚀',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38))),
                          )];
                        }
                        return List<Widget>.generate(rows.length, (i) {
                          final r = rows[i];
                          final rank = r.rank ?? (i + 1);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => CreatorProfileScreen.open(context, r.creatorId, name: r.creatorName),
                            leading: SizedBox(
                              width: 66,
                              child: Row(children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank',
                                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 34, height: 48,
                                    child: (r.thumbnailUrl != null && r.thumbnailUrl!.isNotEmpty)
                                        ? CachedNetworkImage(imageUrl: r.thumbnailUrl!, fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(color: Colors.white10))
                                        : Container(color: Colors.white10,
                                            child: const Icon(Icons.play_arrow, color: Colors.white24, size: 16)),
                                  ),
                                ),
                              ]),
                            ),
                            title: Text('@${r.creatorName}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('${_fmt(r.likes)} ❤️ · ${_fmt(r.views)} vues',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: r.prize != null
                                ? Text('+${r.prize} F',
                                    style: const TextStyle(color: Color(0xFFF5A623), fontWeight: FontWeight.bold))
                                : null,
                          );
                        });
                      })(),
                      const SizedBox(height: 12),
                      const Text(
                        'Classement = ❤️ likes ×3 + vues. La cagnotte est partagée entre les 3 meilleurs créateurs à la fin, directement dans leur portefeuille.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _prizeChip(String label, int amount) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text('$amount F', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      );
}
