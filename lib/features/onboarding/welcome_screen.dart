import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_config.dart';
import '../../core/app_prefs.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';
import '../../shared/widgets/bp_logo.dart';

/// Écran d'accueil (première ouverture) : présente les avantages de BeninPlay
/// et invite à partager l'appli à ses amis. Purement informatif — s'affiche
/// une seule fois, puis mène à la connexion.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _benefits = [
    ['🎬', 'Vidéos courtes & fun', 'Filme, monte avec des filtres façon Snapchat, stickers et musique.'],
    ['💰', 'Gagne de l\'argent', 'Deviens créateur (10 000 abonnés) et sois payé pour ton contenu.'],
    ['🔴', 'Lives & cadeaux', 'Passe en direct, reçois des cadeaux de ta communauté.'],
    ['🏆', 'Défis à cagnotte', 'Participe à des concours avec de vrais prix en FCFA.'],
    ['🇧🇯', '100 % béninois', 'Une appli faite pour toi, légère même en petite connexion.'],
  ];

  Future<void> _done(BuildContext context) async {
    await AppPrefs.setBool('welcome_seen', true);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _invite() {
    Share.share(
      '🎬 Rejoins-moi sur BeninPlay, l\'appli de vidéos 100 % béninoise ! '
      'On y gagne de l\'argent, on fait des lives et des défis à cagnotte. '
      'Télécharge-la ici 👉 ${AppConfig.api}/telecharger',
      subject: 'Rejoins-moi sur BeninPlay 🇧🇯',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6), radius: 1.2,
            colors: [Color(0xFF07200F), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const BpLogo(size: 72),
              const SizedBox(height: 10),
              const Text('Bienvenue sur BeninPlay',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Le divertissement béninois 🇧🇯',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: _benefits.map((b) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Text(b[0], style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b[1], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(b[2], style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text('📣 Partage BeninPlay à tes amis !',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Plus on est nombreux, plus tu gagnes de vues et d\'abonnés.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _invite,
                        icon: const Icon(Icons.share, color: AppColors.primary, size: 18),
                        label: const Text('Inviter mes amis', style: TextStyle(color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: const Size(0, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  onPressed: () => _done(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Commencer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
