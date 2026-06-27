import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/benin_regions.dart';
import '../../shared/widgets/momo_pay_sheet.dart';

/// Sheet de boost complet : ciblage région (multi) + genre + âge,
/// estimation de portée en direct, puis paiement MoMo.
class BoostSheet extends StatefulWidget {
  final String videoId;
  const BoostSheet({super.key, required this.videoId});

  static Future<bool?> show(BuildContext context, String videoId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BoostSheet(videoId: videoId),
    );
  }

  @override
  State<BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends State<BoostSheet> {
  bool _allBenin = true;
  final Set<String> _regions = {};
  String _gender = 'all'; // all | homme | femme
  int _ageMin = 13;
  int _ageMax = 65;

  int? _reach;
  bool _loadingReach = false;

  @override
  void initState() {
    super.initState();
    _estimateReach();
  }

  List<String> get _targetRegions => _allBenin ? ['all'] : _regions.toList();

  Future<void> _estimateReach() async {
    setState(() => _loadingReach = true);
    try {
      final r = await ApiService.getBoostReach(
        regions: _targetRegions.isEmpty ? ['all'] : _targetRegions,
        gender: _gender,
        ageMin: _ageMin,
        ageMax: _ageMax,
      );
      if (mounted) setState(() => _reach = r);
    } catch (_) {
      if (mounted) setState(() => _reach = null);
    } finally {
      if (mounted) setState(() => _loadingReach = false);
    }
  }

  void _toggleRegion(String r) {
    setState(() {
      _allBenin = false;
      if (_regions.contains(r)) {
        _regions.remove(r);
      } else {
        _regions.add(r);
      }
      if (_regions.isEmpty) _allBenin = true;
    });
    _estimateReach();
  }

  Future<void> _pay(int amount, int days) async {
    if (!_allBenin && _regions.isEmpty) return;
    final zone = _allBenin ? 'tout le Bénin' : _regions.join(', ');
    Navigator.pop(context); // ferme ce sheet
    final paid = await MomoPaySheet.show(
      context,
      amount: amount,
      type: 'boost',
      description: 'Boost $days j • $zone',
      videoId: widget.videoId,
      targetRegions: _targetRegions,
      targetGender: _gender,
      targetAgeMin: _ageMin,
      targetAgeMax: _ageMax,
      boostDays: days,
    );
    if (paid == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.6, expand: false,
      builder: (_, sc) => SingleChildScrollView(
        controller: sc,
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Text('🚀', style: TextStyle(fontSize: 26)),
              SizedBox(width: 10),
              Text('Booster la vidéo',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),

            // ── Estimation de portée ────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.groups, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Audience estimée',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 2),
                    _loadingReach
                        ? const Text('Calcul…', style: TextStyle(color: Colors.white, fontSize: 18))
                        : Text(
                            _reach == null ? '—' : '≈ ${_fmt(_reach!)} utilisateurs',
                            style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Région ──────────────────────────────────────────
            _sectionTitle('Où ?'),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _chip('🇧🇯 Tout le Bénin', _allBenin, () {
                  setState(() { _allBenin = true; _regions.clear(); });
                  _estimateReach();
                }),
                ...BeninRegions.all.map((r) => _chip(r, !_allBenin && _regions.contains(r), () => _toggleRegion(r))),
              ],
            ),
            const SizedBox(height: 20),

            // ── Genre ───────────────────────────────────────────
            _sectionTitle('Qui ?'),
            Row(children: [
              _chip('Tous', _gender == 'all', () { setState(() => _gender = 'all'); _estimateReach(); }),
              const SizedBox(width: 8),
              _chip('Hommes', _gender == 'homme', () { setState(() => _gender = 'homme'); _estimateReach(); }),
              const SizedBox(width: 8),
              _chip('Femmes', _gender == 'femme', () { setState(() => _gender = 'femme'); _estimateReach(); }),
            ]),
            const SizedBox(height: 20),

            // ── Âge ─────────────────────────────────────────────
            _sectionTitle('Âge : $_ageMin – $_ageMax ans'),
            RangeSlider(
              values: RangeValues(_ageMin.toDouble(), _ageMax.toDouble()),
              min: 13, max: 80, divisions: 67,
              activeColor: AppColors.primary,
              inactiveColor: Colors.white24,
              labels: RangeLabels('$_ageMin', '$_ageMax'),
              onChanged: (v) => setState(() { _ageMin = v.start.round(); _ageMax = v.end.round(); }),
              onChangeEnd: (_) => _estimateReach(),
            ),
            const SizedBox(height: 12),

            // ── Durée + prix ────────────────────────────────────
            _sectionTitle('Durée'),
            _durationRow('1 jour', 500, 1),
            _durationRow('3 jours', 1500, 3),
            _durationRow('7 jours', 3500, 7),
            const SizedBox(height: 4),
            const Text('Qui paie le plus apparaît en premier. Le boost s\'active dès le paiement confirmé.',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : Colors.white24),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      );

  Widget _durationRow(String label, int price, int days) => GestureDetector(
        onTap: () => _pay(price, days),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
            Text('$price FCFA', style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ]),
        ),
      );

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
