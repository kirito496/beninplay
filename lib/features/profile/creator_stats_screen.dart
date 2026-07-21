import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

class CreatorStatsScreen extends StatefulWidget {
  const CreatorStatsScreen({super.key});

  @override
  State<CreatorStatsScreen> createState() => _CreatorStatsScreenState();
}

class _CreatorStatsScreenState extends State<CreatorStatsScreen> {
  Map<String, dynamic> _s = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await ApiService.getCreatorStats();
    if (mounted) setState(() { _s = s; _loading = false; });
  }

  int _n(String k) => (_s[k] is num) ? (_s[k] as num).toInt() : 0;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final top = (_s['top_videos'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Mes statistiques',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Bandeau gains
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0.05),
                      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${_fmt(_n('wallet_balance'))} FCFA',
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text('Gains cumulés : ${_fmt(_n('earnings_total'))} FCFA',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Grille de métriques
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.7,
                    children: [
                      _stat('👁️ Vues totales', _fmt(_n('views'))),
                      _stat('📈 Vues (7 jours)', _fmt(_n('views_7d'))),
                      _stat('❤️ J\'aime', _fmt(_n('likes'))),
                      _stat('💬 Commentaires', _fmt(_n('comments'))),
                      _stat('👥 Abonnés', _fmt(_n('followers'))),
                      _stat('🎬 Vidéos', _fmt(_n('videos'))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text('🏆 Tes meilleures vidéos',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (top.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Publie des vidéos pour voir ton classement',
                          style: TextStyle(color: Colors.white38))),
                    )
                  else
                    ...top.asMap().entries.map((e) => _topRow(e.key + 1, e.value)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.normalSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _topRow(int rank, Map<String, dynamic> v) {
    final thumb = (v['thumbnail_url'] ?? '').toString();
    final views = (v['views'] is num) ? (v['views'] as num).toInt() : 0;
    final likes = (v['likes_count'] is num) ? (v['likes_count'] as num).toInt() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.normalSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Text('$rank',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44, height: 60,
            child: thumb.isNotEmpty
                ? Image.network(thumb, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.play_arrow, color: Colors.white30)))
                : Container(color: Colors.white10, child: const Icon(Icons.play_arrow, color: Colors.white30)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text((v['title'] ?? 'Sans titre').toString(),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13))),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmt(views)} vues', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('${_fmt(likes)} ❤️', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ]),
    );
  }
}
