import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

/// Écran de vérification d'identité (KYC) autonome.
/// Utilisé notamment avant un retrait : le créateur photographie sa pièce
/// (recto + verso), les photos partent dans le bucket privé du serveur.
class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  File? _front;
  File? _back;
  bool _loading = false;

  Future<void> _pick(bool isFront) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() {
      if (isFront) {
        _front = File(picked.path);
      } else {
        _back = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    if (_front == null) {
      _snack('Prends au moins la photo recto de ta pièce', false);
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.submitKyc(
      frontPath: _front!.path,
      backPath: _back?.path,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    final ok = res['success'] == true;
    _snack(res['message']?.toString() ?? (ok ? 'Vérification envoyée' : 'Erreur'), ok);
    if (ok) Navigator.pop(context, true);
  }

  void _snack(String m, bool ok) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: ok ? AppColors.primary : AppColors.error,
        duration: const Duration(seconds: 4),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Vérification d'identité",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📋 Pièce d\'identité (CIP / passeport)',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Photographie ta pièce pour prouver que tu es bien toi. '
            'Cela garantit qu\'un seul compte par personne peut gagner de l\'argent. '
            'Tes photos restent privées et ne servent qu\'à la vérification.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          _PhotoCard(label: 'Recto (obligatoire)', icon: Icons.badge_outlined, image: _front, onTap: () => _pick(true)),
          const SizedBox(height: 14),
          _PhotoCard(label: 'Verso (recommandé)', icon: Icons.flip_to_back, image: _back, onTap: () => _pick(false)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Envoyer pour vérification',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Validation manuelle sous 24-48 h.',
              style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? image;
  final VoidCallback onTap;

  const _PhotoCard({required this.label, required this.icon, this.image, required this.onTap});

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
            color: image != null ? AppColors.primary : Colors.white24,
            width: image != null ? 2 : 1,
          ),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(image!, fit: BoxFit.cover),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
                ]),
              )
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.white38, size: 40),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Appuyez pour prendre en photo',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
      ),
    );
  }
}
