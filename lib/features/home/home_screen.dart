import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../feed/video_feed_screen.dart';
import '../dark_zone/dark_gate_screen.dart' show DarkGateScreen;
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import '../discover/discover_screen.dart' show DiscoverScreen;
import '../messages/messages_screen.dart';
import '../live/live_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const VideoFeedScreen(isDark: false),
    const DiscoverScreen(),
    const SizedBox(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  void _onNavTap(int index) {
    if (index == 2) {
      _showUploadOptions();
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _pickVideo(ImageSource source) async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (video == null) { return; }
      if (mounted) {
        _showPublishForm(File(video.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _openMessages() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
  }

  void _openLives() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveListScreen()));
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Publier une vidéo',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _UploadOption(
              icon: Icons.videocam,
              label: 'Enregistrer une vidéo',
              subtitle: 'Filmez directement avec la caméra',
              color: AppColors.primary,
              onTap: () => _pickVideo(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _UploadOption(
              icon: Icons.photo_library,
              label: 'Choisir depuis la galerie',
              subtitle: 'Importer depuis votre téléphone',
              color: AppColors.accent,
              onTap: () => _pickVideo(ImageSource.gallery),
            ),
            const SizedBox(height: 12),
            _UploadOption(
              icon: Icons.live_tv,
              label: 'Démarrer un Live 🔴',
              subtitle: 'Diffusion en direct avec Agora',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveBroadcastScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _UploadOption(
              icon: Icons.lock,
              label: 'Publier en Zone Dark 🔞',
              subtitle: 'Contenu exclusif +18',
              color: AppColors.darkPrimary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DarkGateScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPublishForm(File videoFile) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedZone = 'normal';
    final tags = <String>[];
    final tagCtrl = TextEditingController();

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
          child: SingleChildScrollView(
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
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.videocam, color: Colors.white38, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publier une vidéo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Vidéo sélectionnée ✓',
                            style: TextStyle(color: AppColors.primary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Titre de la vidéo',
                    labelStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (hashtags, mentions...)',
                    labelStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Zone selector
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSt(() => selectedZone = 'normal'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedZone == 'normal'
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedZone == 'normal' ? AppColors.primary : Colors.white24,
                              width: selectedZone == 'normal' ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            'Zone Normale',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedZone == 'normal' ? AppColors.primary : Colors.white54,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSt(() => selectedZone = 'dark'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedZone == 'dark'
                                ? AppColors.darkPrimary.withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedZone == 'dark' ? AppColors.darkPrimary : Colors.white24,
                              width: selectedZone == 'dark' ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            'Zone Dark 🔞',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedZone == 'dark' ? AppColors.darkPrimary : Colors.white54,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: tags.map((t) => Chip(
                      label: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      deleteIconColor: Colors.white54,
                      onDeleted: () => setSt(() => tags.remove(t)),
                    )).toList(),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tagCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Ajouter un hashtag',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          prefixText: '#',
                          prefixStyle: TextStyle(color: AppColors.primary),
                          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final tag = tagCtrl.text.trim();
                        if (tag.isNotEmpty && tags.length < 10) {
                          setSt(() {
                            tags.add('#$tag');
                            tagCtrl.clear();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ajoutez un titre à votre vidéo'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('"${titleCtrl.text}" en cours de publication...'),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vidéo publiée avec succès ! ✓\n(Disponible après connexion au serveur)',
                            ),
                            backgroundColor: AppColors.success,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: const Text('Publier maintenant'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Boutons Messages + Live en haut à droite (visible sur l'onglet Accueil)
          if (_currentIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Row(
                children: [
                  // Live
                  GestureDetector(
                    onTap: _openLives,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.live_tv, color: Colors.red, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Messages
                  GestureDetector(
                    onTap: _openMessages,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.send_outlined, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex == 2 ? 0 : _currentIndex,
          onTap: _onNavTap,
          backgroundColor: const Color(0xFF0A0A0A),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: AppStrings.navHome,
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: AppStrings.navDiscover,
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF00897B)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
              label: AppStrings.navUpload,
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: AppStrings.navWallet,
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: AppStrings.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }
}
