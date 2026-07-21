import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import 'momo_pay_sheet.dart';

/// Feuille « Soutenir » : envoyer un tip à un créateur, payé en pièces.
/// Les pièces s'achètent d'abord en MoMo (bouton Recharger).
class TipSheet extends StatefulWidget {
  final String creatorId;
  final String creatorName;
  final String? videoId;

  const TipSheet({super.key, required this.creatorId, required this.creatorName, this.videoId});

  static Future<void> show(BuildContext context,
      {required String creatorId, required String creatorName, String? videoId}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => TipSheet(creatorId: creatorId, creatorName: creatorName, videoId: videoId),
    );
  }

  @override
  State<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<TipSheet> {
  static const _amounts = [50, 100, 250, 500, 1000, 2000];
  int _balance = 0;
  List<Map<String, dynamic>> _packs = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ApiService.getGiftCatalog();
    if (!mounted) return;
    setState(() {
      _balance = (c['coin_balance'] is num) ? (c['coin_balance'] as num).toInt() : 0;
      _packs = (c['packs'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      _loading = false;
    });
  }

  Future<void> _recharge() async {
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
    if (paid == true) _load();
  }

  Future<void> _sendTip(int coins) async {
    if (_sending) return;
    if (coins > _balance) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Pièces insuffisantes — recharge pour soutenir'),
        backgroundColor: AppColors.error,
        action: SnackBarAction(label: 'Recharger', textColor: Colors.white, onPressed: _recharge),
      ));
      return;
    }
    setState(() => _sending = true);
    final res = await ApiService.sendTip(creatorId: widget.creatorId, coins: coins, videoId: widget.videoId);
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true) {
      setState(() => _balance = (res['coin_balance'] is num) ? (res['coin_balance'] as num).toInt() : _balance);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tip de $coins pièces envoyé à @${widget.creatorName} ❤️'),
        backgroundColor: AppColors.primary));
    } else if (res['code'] == 'no_coins') {
      _recharge();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Échec du tip'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Soutenir @${widget.creatorName}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Envoie un tip payé en pièces 🪙',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _recharge,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 18),
                const SizedBox(width: 6),
                Text('$_balance pièces', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.add_circle, color: AppColors.primary, size: 18),
                const SizedBox(width: 2),
                const Text('Recharger', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _loading
              ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary))
              : Wrap(
                  spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                  children: _amounts.map((a) => GestureDetector(
                    onTap: _sending ? null : () => _sendTip(a),
                    child: Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      child: Column(children: [
                        const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 20),
                        const SizedBox(height: 4),
                        Text('$a', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ),
                  )).toList(),
                ),
        ]),
      ),
    );
  }
}
