import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/momo_pay_sheet.dart';

/// Feuille de sélection des stickers de soutien + rechargement de pièces.
/// [onSend] est appelé avec la clé du sticker choisi.
class GiftSheet extends StatefulWidget {
  final void Function(String giftKey) onSend;
  const GiftSheet({super.key, required this.onSend});

  static Future<void> show(BuildContext context, {required void Function(String) onSend}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => GiftSheet(onSend: onSend),
    );
  }

  @override
  State<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet> {
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _packs = [];
  int _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ApiService.getGiftCatalog();
    if (!mounted) return;
    setState(() {
      _gifts = (c['gifts'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      _packs = (c['packs'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      _balance = (c['coin_balance'] is num) ? (c['coin_balance'] as num).toInt() : 0;
      _loading = false;
    });
  }

  Future<void> _recharge() async {
    // Choix rapide d'un paquet de pièces
    final pack = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16),
              child: Text('Recharger des pièces 🪙',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          ..._packs.map((p) => ListTile(
                leading: const Icon(Icons.monetization_on, color: Color(0xFFFFC107)),
                title: Text('${p['coins']} pièces', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: Text('${p['fcfa']} FCFA', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context, p),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pack == null || !mounted) return;
    final paid = await MomoPaySheet.show(
      context,
      amount: (pack['fcfa'] as num).toInt(),
      type: 'coins',
      coins: (pack['coins'] as num).toInt(),
      description: 'Achat de ${pack['coins']} pièces',
    );
    if (paid == true) _load(); // recharge le solde
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(children: [
            const Text('Envoyer un sticker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            GestureDetector(
              onTap: _recharge,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 16),
                  const SizedBox(width: 6),
                  Text('$_balance', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  const Icon(Icons.add_circle, color: AppColors.primary, size: 16),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _loading
              ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: AppColors.primary))
              : GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                  children: _gifts.map((g) {
                    final coins = (g['coins'] as num?)?.toInt() ?? 0;
                    return GestureDetector(
                      onTap: () {
                        widget.onSend((g['key'] ?? '').toString());
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text((g['emoji'] ?? '🎁').toString(), style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 12),
                            const SizedBox(width: 2),
                            Text('$coins', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ]),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
        ]),
      ),
    );
  }
}
