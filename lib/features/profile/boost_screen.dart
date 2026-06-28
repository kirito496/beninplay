import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/benin_regions.dart';
import '../../shared/widgets/momo_pay_sheet.dart';

/// Écran complet de configuration d'un boost (façon TikTok/Facebook Ads) :
/// budget libre, audience (région/genre/âge), hashtags sponsorisés, portée estimée.
class BoostScreen extends StatefulWidget {
  final String videoId;
  const BoostScreen({super.key, required this.videoId});

  static Future<bool?> open(BuildContext context, String videoId) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BoostScreen(videoId: videoId)),
    );
  }

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  // Budget libre (500 FCFA = 1 jour)
  int _amount = 1000;
  final _amountCtrl = TextEditingController(text: '1000');

  // Audience
  bool _allBenin = true;
  final Set<String> _regions = {};
  String _gender = 'all';
  int _ageMin = 13;
  int _ageMax = 65;

  // Hashtags sponsorisés
  List<String> _popularTags = [];
  final Set<String> _tags = {};
  final _tagCtrl = TextEditingController();

  int? _reach;
  bool _loadingReach = false;
  Timer? _debounce;

  int get _days => (_amount / 500).floor().clamp(1, 365);

  @override
  void initState() {
    super.initState();
    _loadTags();
    _estimateReach();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tagCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final t = await ApiService.getPopularTags();
    if (mounted) setState(() => _popularTags = t);
  }

  List<String> get _targetRegions => _allBenin ? ['all'] : _regions.toList();

  void _estimateReach() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loadingReach = true);
      try {
        final r = await ApiService.getBoostReach(
          regions: _targetRegions.isEmpty ? ['all'] : _targetRegions,
          gender: _gender, ageMin: _ageMin, ageMax: _ageMax,
        );
        if (mounted) setState(() => _reach = r);
      } catch (_) {
        if (mounted) setState(() => _reach = null);
      } finally {
        if (mounted) setState(() => _loadingReach = false);
      }
    });
  }

  void _setAmount(int v) {
    setState(() {
      _amount = v.clamp(500, 1000000);
      _amountCtrl.text = '$_amount';
      _amountCtrl.selection = TextSelection.collapsed(offset: _amountCtrl.text.length);
    });
  }

  void _toggleRegion(String r) {
    setState(() {
      _allBenin = false;
      _regions.contains(r) ? _regions.remove(r) : _regions.add(r);
      if (_regions.isEmpty) _allBenin = true;
    });
    _estimateReach();
  }

  void _addTag(String raw) {
    final t = raw.trim().toLowerCase().replaceAll('#', '');
    if (t.isEmpty || _tags.length >= 10) return;
    setState(() { _tags.add(t); _tagCtrl.clear(); });
  }

  Future<void> _pay() async {
    if (_amount < 500) return;
    final zone = _allBenin ? 'tout le Bénin' : _regions.join(', ');
    final paid = await MomoPaySheet.show(
      context,
      amount: _amount,
      type: 'boost',
      description: 'Boost $_days j • $zone',
      videoId: widget.videoId,
      targetRegions: _targetRegions,
      targetGender: _gender,
      targetAgeMin: _ageMin,
      targetAgeMax: _ageMax,
      boostDays: _days,
      targetTags: _tags.toList(),
    );
    if (paid == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalBg,
        title: const Text('🚀 Booster ma vidéo', style: TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          // ── Portée estimée ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.25),
                AppColors.primary.withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.groups, color: AppColors.primary, size: 30),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Audience estimée', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 2),
                _loadingReach
                    ? const Text('Calcul…', style: TextStyle(color: Colors.white, fontSize: 22))
                    : Text(_reach == null ? '—' : '≈ ${_fmt(_reach!)} personnes',
                        style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$_days j', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('durée', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Budget libre ────────────────────────────────────
          _title('💰 Budget'),
          const Text('500 FCFA = 1 jour de mise en avant',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Padding(padding: EdgeInsets.all(14),
                  child: Text('FCFA', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) {
              final n = int.tryParse(v) ?? 0;
              setState(() => _amount = n);
            },
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [500, 1000, 2000, 5000, 10000].map((v) =>
            _chip('$v F', _amount == v, () => _setAmount(v))).toList()),
          const SizedBox(height: 24),

          // ── Régions ─────────────────────────────────────────
          _title('📍 Où ?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('🇧🇯 Tout le Bénin', _allBenin, () { setState(() { _allBenin = true; _regions.clear(); }); _estimateReach(); }),
            ...BeninRegions.all.map((r) => _chip(r, !_allBenin && _regions.contains(r), () => _toggleRegion(r))),
          ]),
          const SizedBox(height: 24),

          // ── Genre ───────────────────────────────────────────
          _title('👤 Qui ?'),
          Row(children: [
            _chip('Tous', _gender == 'all', () { setState(() => _gender = 'all'); _estimateReach(); }),
            const SizedBox(width: 8),
            _chip('Hommes', _gender == 'homme', () { setState(() => _gender = 'homme'); _estimateReach(); }),
            const SizedBox(width: 8),
            _chip('Femmes', _gender == 'femme', () { setState(() => _gender = 'femme'); _estimateReach(); }),
          ]),
          const SizedBox(height: 24),

          // ── Âge ─────────────────────────────────────────────
          _title('🎂 Âge : $_ageMin – $_ageMax ans'),
          RangeSlider(
            values: RangeValues(_ageMin.toDouble(), _ageMax.toDouble()),
            min: 13, max: 80, divisions: 67,
            activeColor: AppColors.primary, inactiveColor: Colors.white24,
            labels: RangeLabels('$_ageMin', '$_ageMax'),
            onChanged: (v) => setState(() { _ageMin = v.start.round(); _ageMax = v.end.round(); }),
            onChangeEnd: (_) => _estimateReach(),
          ),
          const SizedBox(height: 16),

          // ── Hashtags sponsorisés ────────────────────────────
          _title('# Hashtags sponsorisés'),
          const Text('Ta vidéo remonte en tête quand on cherche ces hashtags',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _tagCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ajouter un hashtag…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.tag, color: Colors.white38),
              suffixIcon: IconButton(icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _addTag(_tagCtrl.text)),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: _addTag,
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: _tags.map((t) => Chip(
              backgroundColor: AppColors.primary,
              label: Text('#$t', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.black),
              onDeleted: () => setState(() => _tags.remove(t)),
            )).toList()),
          ],
          if (_popularTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Populaires :', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _popularTags.take(15).map((t) =>
              _chip('#$t', _tags.contains(t), () => setState(() {
                _tags.contains(t) ? _tags.remove(t) : (_tags.length < 10 ? _tags.add(t) : null);
              }))).toList()),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_amount FCFA', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('$_days jour${_days > 1 ? 's' : ''} de boost', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
            ElevatedButton(
              onPressed: _amount >= 500 ? _pay : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: const Text('Payer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
          child: Text(label, style: TextStyle(
            color: selected ? Colors.black : Colors.white, fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      );

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
