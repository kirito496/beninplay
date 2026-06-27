import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

/// Tableau de bord des boosts : vidéos boostées + performances (vues gagnées, temps restant).
class BoostsDashboard extends StatefulWidget {
  const BoostsDashboard({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BoostsDashboard(),
    );
  }

  @override
  State<BoostsDashboard> createState() => _BoostsDashboardState();
}

class _BoostsDashboardState extends State<BoostsDashboard> {
  List<Map<String, dynamic>> _boosts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ApiService.getMyBoosts();
      if (mounted) setState(() { _boosts = b; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (_, sc) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Mes boosts',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Suis les performances de tes vidéos boostées',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const Divider(color: Colors.white12, height: 24),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _boosts.isEmpty
                    ? const Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('🚀', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('Aucun boost pour l\'instant',
                              style: TextStyle(color: Colors.white54)),
                          SizedBox(height: 4),
                          Text('Booste une vidéo depuis « Mes vidéos »',
                              style: TextStyle(color: Colors.white30, fontSize: 12)),
                        ]),
                      )
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _boosts.length,
                        itemBuilder: (_, i) => _BoostCard(boost: _boosts[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _BoostCard extends StatelessWidget {
  final Map<String, dynamic> boost;
  const _BoostCard({required this.boost});

  @override
  Widget build(BuildContext context) {
    final active = boost['active'] == true;
    final title = (boost['title'] ?? 'Vidéo').toString();
    final gained = (boost['views_gained'] as num?)?.toInt() ?? 0;
    final total = (boost['views_total'] as num?)?.toInt() ?? 0;
    final amount = (boost['amount'] as num?)?.toInt() ?? 0;
    final daysLeft = (boost['days_left'] as num?)?.toInt() ?? 0;
    final hoursLeft = (boost['hours_left'] as num?)?.toInt() ?? 0;
    final regions = (boost['regions'] as List?)?.cast<dynamic>().map((e) => e.toString()).toList() ?? ['all'];
    final regionLabel = regions.contains('all') ? 'Tout le Bénin' : regions.join(', ');
    final gender = (boost['gender'] ?? 'all').toString();
    final genderLabel = gender == 'all' ? 'Tous' : (gender == 'homme' ? 'Hommes' : 'Femmes');

    final remaining = daysLeft >= 1
        ? '$daysLeft j restant${daysLeft > 1 ? 's' : ''}'
        : '$hoursLeft h restantes';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.5) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(active ? '🚀 Actif' : 'Terminé',
                  style: TextStyle(color: active ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            if (active)
              Text(remaining, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            _stat('👁 Vues gagnées', '+$gained'),
            _stat('Vues totales', '$total'),
            _stat('Payé', '$amount F'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.location_on_outlined, color: Colors.white38, size: 14),
            const SizedBox(width: 4),
            Expanded(child: Text(regionLabel, style: const TextStyle(color: Colors.white54, fontSize: 12))),
            const Icon(Icons.person_outline, color: Colors.white38, size: 14),
            const SizedBox(width: 4),
            Text(genderLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      );
}
