import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

class PaymentScreen extends StatefulWidget {
  final int amount;
  final String type;
  final String? videoId;
  final String description;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.type,
    this.videoId,
    required this.description,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedOperator = 'mtn';
  bool _isLoading = false;
  String? _paymentId;
  String? _reference;
  String? _paymentNumber;
  bool _isPaid = false;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPolls = 36;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.initiatePayment(
        amount: widget.amount,
        type: widget.type,
        operator: _selectedOperator,
        videoId: widget.videoId,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final p = result['payment'];
        setState(() {
          _paymentId = p['id'];
          _reference = p['reference'];
          _paymentNumber = p['paymentNumber'];
          _isLoading = false;
        });
        _startPolling();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Erreur'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_paymentId == null || _pollCount >= _maxPolls) { _pollTimer?.cancel(); return; }
      _pollCount++;
      final result = await ApiService.checkPaymentStatus(_paymentId!);
      if (!mounted) return;
      if (result['payment']?['status'] == 'confirmed') {
        _pollTimer?.cancel();
        setState(() => _isPaid = true);
      }
    });
  }

  void _copyNumber() {
    if (_paymentNumber != null) {
      Clipboard.setData(ClipboardData(text: _paymentNumber!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro copié !'), backgroundColor: AppColors.primary, duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Paiement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isPaid ? _buildSuccess() : _buildPayment(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.black, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('Paiement confirmé !', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.description, style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayment() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text('${widget.amount} FCFA', style: const TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(widget.description, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 24),
          if (_paymentId == null) ...[
            const Text('Choisir l\'opérateur', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _OperatorCard(label: 'MTN MoMo', color: const Color(0xFFFFCC00), isSelected: _selectedOperator == 'mtn', onTap: () => setState(() => _selectedOperator = 'mtn'))),
              const SizedBox(width: 12),
              Expanded(child: _OperatorCard(label: 'Moov Money', color: const Color(0xFF0066CC), isSelected: _selectedOperator == 'moov', onTap: () => setState(() => _selectedOperator = 'moov'))),
            ]),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _initiatePayment,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('Instructions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 16),
                Text('1. Ouvre ${_selectedOperator == 'mtn' ? 'MTN MoMo' : 'Moov Money'}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('2. Envoie au numéro :', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _copyNumber,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.5))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_paymentNumber ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const Icon(Icons.copy, color: AppColors.primary, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Text('3. Montant exact : ${widget.amount} FCFA', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text('4. Référence : $_reference', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
              child: const Row(children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('En attente de votre paiement...\nLa confirmation est automatique.', style: TextStyle(color: Colors.orange, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('⏱ Valable 30 minutes', style: TextStyle(color: Colors.white38, fontSize: 12))),
          ],
        ],
      ),
    );
  }
}

class _OperatorCard extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _OperatorCard({required this.label, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
        ),
        child: Column(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: const Icon(Icons.phone_android, color: Colors.white, size: 20)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}