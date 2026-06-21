import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../feed/video_feed_screen.dart';

class DarkGateScreen extends StatefulWidget {
  const DarkGateScreen({super.key});

  @override
  State<DarkGateScreen> createState() => _DarkGateScreenState();
}

class _DarkGateScreenState extends State<DarkGateScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_step) {
            0 => _IntroStep(onContinue: () => setState(() => _step = 1)),
            1 => _KycStep(onComplete: () => setState(() => _step = 2)),
            2 => _PaymentStep(onComplete: () => setState(() => _step = 3)),
            _ => _PendingStep(
              onAccessDark: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const VideoFeedScreen(isDark: true),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

// ── Étape 1 : Introduction ────────────────────────────────────────────────────

class _IntroStep extends StatelessWidget {
  final VoidCallback onContinue;
  const _IntroStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
          const Text('🔞', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            'Zone Dark',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Contenu exclusif réservé aux adultes (+18 ans)',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          _BenefitItem(icon: Icons.verified_user, text: 'Contenu légal entre adultes consentants'),
          _BenefitItem(icon: Icons.lock, text: 'Accès sécurisé par vérification d\'identité'),
          _BenefitItem(icon: Icons.attach_money, text: '80% des revenus reversés aux créateurs'),
          _BenefitItem(icon: Icons.block, text: 'Zéro tolérance pour les mineurs'),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkPrimary.withValues(alpha: 0.5)),
            ),
            child: const Text(
              '⚠️ En continuant, vous confirmez avoir 18 ans ou plus et acceptez nos conditions spéciales pour la Zone Dark.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'J\'ai 18 ans ou plus — Continuer',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ── Étape 2 : KYC ─────────────────────────────────────────────────────────────

class _KycStep extends StatefulWidget {
  final VoidCallback onComplete;
  const _KycStep({required this.onComplete});

  @override
  State<_KycStep> createState() => _KycStepState();
}

class _KycStepState extends State<_KycStep> {
  File? _frontImage;
  File? _backImage;
  bool _isLoading = false;

  Future<void> _pickImage(bool isFront) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked == null) return;
    setState(() {
      if (isFront) {
        _frontImage = File(picked.path);
      } else {
        _backImage = File(picked.path);
      }
    });
  }

  void _submit() async {
    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez prendre les deux photos de votre CIP'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isLoading = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            '📋 Vérification d\'identité',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prenez en photo votre Certificat d\'Identification Personnelle (CIP)',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 32),
          _PhotoCard(
            label: 'RECTO de votre CIP',
            icon: Icons.credit_card,
            image: _frontImage,
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: 16),
          _PhotoCard(
            label: 'VERSO de votre CIP',
            icon: Icons.credit_card_outlined,
            image: _backImage,
            onTap: () => _pickImage(false),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔒 Vos données sont sécurisées',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '• Photos chiffrées et stockées de façon sécurisée\n• Utilisées uniquement pour vérifier votre âge\n• Supprimées après vérification (max 48h)',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
                : const Text(
              AppStrings.kycSubmit,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? image;
  final VoidCallback onTap;

  const _PhotoCard({
    required this.label,
    required this.icon,
    this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: image != null ? AppColors.darkPrimary : Colors.white24,
            width: image != null ? 2 : 1,
          ),
        ),
        child: image != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(image!, fit: BoxFit.cover),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.darkPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white38, size: 40),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'Appuyez pour prendre en photo',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Étape 3 : Paiement ────────────────────────────────────────────────────────

class _PaymentStep extends StatefulWidget {
  final VoidCallback onComplete;
  const _PaymentStep({required this.onComplete});

  @override
  State<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends State<_PaymentStep> {
  int _selectedPlan = 0;
  int _selectedPayment = 0;
  bool _isLoading = false;

  final List<Map<String, String>> plans = const [
    {'label': 'Mensuel', 'price': '2 000 FCFA', 'period': '/mois'},
    {'label': 'Trimestriel', 'price': '5 000 FCFA', 'period': '/3 mois', 'save': '-17%'},
    {'label': 'Annuel', 'price': '18 000 FCFA', 'period': '/an', 'save': '-25%'},
  ];

  final List<Map<String, String>> payments = const [
    {'label': 'MTN MoMo', 'colorHex': 'FFCC00', 'icon': '📱'},
    {'label': 'Moov Money', 'colorHex': '0066CC', 'icon': '💳'},
  ];

  Color _hexColor(String hex) {
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _subscribe() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isLoading = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            '💳 Abonnement Zone Dark',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '80% reversés aux créateurs que vous soutenez',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Plans
          ...List.generate(plans.length, (i) {
            final plan = plans[i];
            final selected = i == _selectedPlan;
            return GestureDetector(
              onTap: () => setState(() => _selectedPlan = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.darkPrimary.withValues(alpha: 0.3)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.darkPrimary : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? AppColors.darkPrimary : Colors.white38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan['label']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${plan['price']}${plan['period']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (plan.containsKey('save'))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          plan['save']!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          const Text(
            'Mode de paiement',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),

          // Paiements
          Row(
            children: List.generate(payments.length, (i) {
              final pay = payments[i];
              final selected = i == _selectedPayment;
              final color = _hexColor(pay['colorHex']!);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPayment = i),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: i == 0 ? 8 : 0,
                      left: i == 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(pay['icon']!, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          pay['label']!,
                          style: TextStyle(
                            color: selected ? color : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isLoading ? null : _subscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
                : Text(
              'S\'abonner — ${plans[_selectedPlan]['price']}${plans[_selectedPlan]['period']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Étape 4 : En attente ──────────────────────────────────────────────────────

class _PendingStep extends StatelessWidget {
  final VoidCallback onAccessDark;
  const _PendingStep({required this.onAccessDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          const Text(
            'Inscription réussie !',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Votre identité est en cours de vérification (24-48h).\nEn attendant, vous pouvez accéder au contenu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: onAccessDark,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Accéder à la Zone Dark 🔞',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
