import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/algorithms/revenue_algorithm.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  bool _balanceVisible = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final data = await ApiService.getWalletBalance();
      if (mounted) {
        setState(() {
          _balance = ((data['balance'] ?? 0) as num).toDouble();
          final List<dynamic> raw = data['transactions'] ?? [];
          _transactions = raw.whereType<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        title: const Text('Mon Portefeuille'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              _balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _balanceVisible = !_balanceVisible),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadWallet,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C853), Color(0xFF009624)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            _balanceVisible ? '${_balance.toStringAsFixed(0)} FCFA' : '••••••',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.arrow_downward,
                            label: 'Retirer',
                            color: AppColors.primary,
                            onTap: () => _showWithdrawSheet(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.calculate_outlined,
                            label: 'Simuler',
                            color: Colors.purple,
                            onTap: () => _showSimulator(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const _SectionTitle('Dernières transactions'),
                    const SizedBox(height: 12),

                    if (_transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(children: [
                          Icon(Icons.receipt_long_outlined, color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text('Aucune transaction pour le moment',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                              textAlign: TextAlign.center),
                        ]),
                      )
                    else
                      ..._transactions.map((t) {
                        final isCredit = (t['type'] ?? '') == 'earning' || (t['type'] ?? '') == 'deposit';
                        final amount = ((t['amount'] ?? 0) as num).toInt();
                        final date = _formatDate(t['created_at']?.toString() ?? '');
                        final desc = t['description']?.toString() ?? t['type']?.toString() ?? 'Transaction';
                        return _TransactionItem(
                          label: desc,
                          amount: isCredit ? '+$amount' : '-$amount',
                          date: date,
                          isCredit: isCredit,
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "Aujourd'hui ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        return 'Hier ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  void _showWithdrawSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedMomo = 'MTN';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24, left: 24, right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Retrait Mobile Money', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Solde : ${_balance.toStringAsFixed(0)} FCFA · Min : 500 FCFA', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Montant à retirer (FCFA)',
                  labelStyle: TextStyle(color: Colors.white54),
                  filled: true, fillColor: Colors.white10,
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Numéro Mobile Money (ex: 229XXXXXXXX)',
                  labelStyle: TextStyle(color: Colors.white54),
                  filled: true, fillColor: Colors.white10,
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Via', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: GestureDetector(onTap: () => setSt(() => selectedMomo = 'MTN'), child: _MomoOption(label: 'MTN MoMo', color: AppColors.mtnYellow, isSelected: selectedMomo == 'MTN'))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(onTap: () => setSt(() => selectedMomo = 'MOOV'), child: _MomoOption(label: 'Moov Money', color: AppColors.moovBlue, isSelected: selectedMomo == 'MOOV'))),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                  final phone = phoneCtrl.text.trim();
                  if (amount < 500) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant minimum : 500 FCFA'), backgroundColor: AppColors.error));
                    return;
                  }
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrez votre numéro Mobile Money'), backgroundColor: AppColors.error));
                    return;
                  }
                  Navigator.pop(context);
                  final result = await ApiService.withdraw(amount: amount, phone: phone, operator: selectedMomo);
                  if (result['success'] == true) {
                    await _loadWallet();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Retrait en cours...'), backgroundColor: AppColors.primary, duration: const Duration(seconds: 4)));
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Erreur lors du retrait'), backgroundColor: AppColors.error));
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                child: const Text('Confirmer le retrait'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSimulator(BuildContext context) {
    int followers = 1000;
    int darkSubs = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final estimate = RevenueAlgorithm.estimateMonthlyEarnings(
            followers: followers,
            monthlyViews: followers * 10,
            darkSubscribers: darkSubs,
            tipsReceived: (followers * 0.01).round(),
            avgTipAmount: 500,
          );
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Simulateur de revenus', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text('Abonnés : $followers', style: const TextStyle(color: Colors.white70)),
                Slider(value: followers.toDouble(), min: 100, max: 100000, divisions: 100, activeColor: AppColors.primary, onChanged: (v) => setSt(() => followers = v.round())),
                Text('Abonnés Dark : $darkSubs', style: const TextStyle(color: Colors.white70)),
                Slider(value: darkSubs.toDouble(), min: 0, max: 500, divisions: 50, activeColor: AppColors.darkPrimary, onChanged: (v) => setSt(() => darkSubs = v.round())),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                EstimateRow(label: 'Abonnements Dark', value: '${estimate.fromSubscriptions} FCFA', color: AppColors.darkPrimary),
                EstimateRow(label: 'Tips', value: '${estimate.fromTips} FCFA', color: AppColors.accent),
                EstimateRow(label: 'Publicités', value: '${estimate.fromAds} FCFA', color: Colors.orange),
                const Divider(color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Revenu mensuel estimé', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${estimate.total} FCFA', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EstimateRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const EstimateRow({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _MomoOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  const _MomoOption({required this.label, required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? color : Colors.white24, width: isSelected ? 2 : 1),
      ),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? color : Colors.white60, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final String label;
  final String amount;
  final String date;
  final bool isCredit;
  const _TransactionItem({required this.label, required this.amount, required this.date, required this.isCredit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.normalSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? AppColors.success : AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          Text('$amount FCFA', style: TextStyle(color: isCredit ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}