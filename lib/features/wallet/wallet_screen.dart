import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/algorithms/revenue_algorithm.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 12500;
  bool _balanceVisible = true;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Carte solde
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
                  const Text(
                    'Solde disponible',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _balanceVisible ? '${_balance.toStringAsFixed(0)} FCFA' : '••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ce mois', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          Text(
                            '3 200 FCFA',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total gagné', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          Text(
                            '48 750 FCFA',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Abonnés Dark', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          Text(
                            '1 240',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions
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
                    icon: Icons.bar_chart,
                    label: 'Statistiques',
                    color: AppColors.accent,
                    onTap: () => _showStats(context),
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

            // Revenus par source
            const _SectionTitle('Revenus par source'),
            const SizedBox(height: 12),
            const _RevenueRow(
              label: 'Abonnements Zone Dark',
              amount: '8 500 FCFA',
              percent: 68,
              color: AppColors.darkPrimary,
            ),
            const _RevenueRow(
              label: 'Tips reçus',
              amount: '2 800 FCFA',
              percent: 22,
              color: AppColors.accent,
            ),
            const _RevenueRow(
              label: 'Ventes vidéos',
              amount: '1 200 FCFA',
              percent: 10,
              color: AppColors.primary,
            ),

            const SizedBox(height: 24),

            // Historique
            const _SectionTitle('Dernières transactions'),
            const SizedBox(height: 12),
            ..._mockTransactions.map((t) => _TransactionItem(
              label: t['label']!,
              amount: t['amount']!,
              date: t['date']!,
              isCredit: t['type'] == 'credit',
            )),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    String selectedMomo = 'mtn';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Retrait Mobile Money',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Solde : ${_balance.toStringAsFixed(0)} FCFA · Min : 500 FCFA',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Montant à retirer (FCFA)',
                  labelStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Via', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSt(() => selectedMomo = 'mtn'),
                      child: _MomoOption(
                        label: 'MTN MoMo',
                        color: AppColors.mtnYellow,
                        isSelected: selectedMomo == 'mtn',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSt(() => selectedMomo = 'moov'),
                      child: _MomoOption(
                        label: 'Moov Money',
                        color: AppColors.moovBlue,
                        isSelected: selectedMomo == 'moov',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  final result = RevenueAlgorithm.canWithdraw(
                    balance: _balance,
                    requestedAmount: amount,
                    trustScore: 75,
                    kycApproved: false,
                  );

                  if (result.approved) {
                    setState(() => _balance -= amount);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        'Retrait de ${amount.toStringAsFixed(0)} FCFA en cours...\n'
                            'Vous recevrez ${result.netAmount!.toStringAsFixed(0)} FCFA sur '
                            '${selectedMomo == "mtn" ? "MTN MoMo" : "Moov Money"}',
                      ),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 4),
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result.reason),
                      backgroundColor: AppColors.error,
                    ));
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

  void _showStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Statistiques',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const _StatsCard(
              title: 'Cette semaine',
              items: [
                {'label': 'Vues totales', 'value': '48 200', 'icon': '👁'},
                {'label': 'Nouveaux abonnés', 'value': '+142', 'icon': '👤'},
                {'label': 'Revenus', 'value': '3 200 FCFA', 'icon': '💰'},
                {'label': 'Engagement', 'value': '8.4%', 'icon': '📊'},
              ],
            ),
            const SizedBox(height: 16),
            const _StatsCard(
              title: 'Ce mois',
              items: [
                {'label': 'Vues totales', 'value': '189 400', 'icon': '👁'},
                {'label': 'Nouveaux abonnés', 'value': '+580', 'icon': '👤'},
                {'label': 'Revenus', 'value': '12 500 FCFA', 'icon': '💰'},
                {'label': 'Abonnés Dark', 'value': '1 240', 'icon': '🔞'},
              ],
            ),
            const SizedBox(height: 16),
            const _StatsCard(
              title: 'Meilleures vidéos',
              items: [
                {'label': 'Vidéo #1 - DanceBénin', 'value': '24K vues', 'icon': '🥇'},
                {'label': 'Vidéo #2 - Cuisine', 'value': '18K vues', 'icon': '🥈'},
                {'label': 'Vidéo #3 - Humour', 'value': '12K vues', 'icon': '🥉'},
              ],
            ),
          ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Simulateur de revenus',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text('Abonnés : $followers', style: const TextStyle(color: Colors.white70)),
                Slider(
                  value: followers.toDouble(),
                  min: 100,
                  max: 100000,
                  divisions: 100,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setSt(() => followers = v.round()),
                ),
                Text('Abonnés Dark : $darkSubs', style: const TextStyle(color: Colors.white70)),
                Slider(
                  value: darkSubs.toDouble(),
                  min: 0,
                  max: 500,
                  divisions: 50,
                  activeColor: AppColors.darkPrimary,
                  onChanged: (v) => setSt(() => darkSubs = v.round()),
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                EstimateRow(
                  label: 'Abonnements Dark',
                  value: '${estimate.fromSubscriptions} FCFA',
                  color: AppColors.darkPrimary,
                ),
                EstimateRow(
                  label: 'Tips',
                  value: '${estimate.fromTips} FCFA',
                  color: AppColors.accent,
                ),
                EstimateRow(
                  label: 'Publicités',
                  value: '${estimate.fromAds} FCFA',
                  color: Colors.orange,
                ),
                const Divider(color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Revenu mensuel estimé',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${estimate.total} FCFA',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
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

// Renamed from _EstimateRow function to EstimateRow StatelessWidget
class EstimateRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const EstimateRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

final _mockTransactions = [
  {'label': 'Abonnement de Kouadio A.', 'amount': '+2 000', 'date': 'Aujourd\'hui 14:32', 'type': 'credit'},
  {'label': 'Retrait MTN MoMo',         'amount': '-5 000', 'date': 'Hier 09:15',          'type': 'debit'},
  {'label': 'Tip de Fatou K.',           'amount': '+500',   'date': '17/06 16:40',          'type': 'credit'},
  {'label': 'Abonnement de Romuald B.', 'amount': '+2 000', 'date': '15/06 11:20',          'type': 'credit'},
  {'label': 'Retrait Moov Money',        'amount': '-3 000', 'date': '10/06 08:00',          'type': 'debit'},
];

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

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
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
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
        border: Border.all(
          color: isSelected ? color : Colors.white24,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelected ? color : Colors.white60,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RevenueRow extends StatelessWidget {
  final String label;
  final String amount;
  final int percent;
  final Color color;

  const _RevenueRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                amount,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final String label;
  final String amount;
  final String date;
  final bool isCredit;

  const _TransactionItem({
    required this.label,
    required this.amount,
    required this.date,
    required this.isCredit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.normalSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? AppColors.success : AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '$amount FCFA',
            style: TextStyle(
              color: isCredit ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final List<Map<String, String>> items;

  const _StatsCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['label']!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Text(
                  item['value']!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
