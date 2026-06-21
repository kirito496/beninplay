import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../dark_zone/dark_gate_screen.dart' show DarkGateScreen;
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = 'GBETOHO José';
  String username = 'gbetoho_jose';
  String _bio = 'Créateur BeninPlay 🇧🇯';
  String statsVideos = '48';
  String statsFollowers = '12.4K';
  String statsFollowing = '3.2K';
  String statsLikes = '284K';

  final List<Map<String, dynamic>> _myVideos = List.generate(
    9,
        (i) => {'index': i, 'views': '${(i + 1) * 12}K', 'likes': '${(i + 1) * 3}K'},
  );

  final List<Map<String, dynamic>> _likedVideos = List.generate(
    6,
        (i) => {'index': i + 2, 'views': '${(i + 2) * 8}K', 'likes': '${(i + 2) * 2}K'},
  );

  final List<Map<String, dynamic>> _savedVideos = List.generate(
    4,
        (i) => {'index': i + 1, 'views': '${(i + 1) * 5}K', 'likes': '${(i + 1) * 1}K'},
  );

  void _editProfile() {
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
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
              'Modifier le profil',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _displayName[0],
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nom affiché',
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
              controller: bioCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _displayName = nameCtrl.text.trim().isEmpty ? _displayName : nameCtrl.text.trim();
                  _bio = bioCtrl.text.trim().isEmpty ? _bio : bioCtrl.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profil mis à jour ✓'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile() {
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
            const SizedBox(height: 16),
            const Text(
              'Partager mon profil',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'beninplay.app/@$username',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: 'beninplay.app/@$username'));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lien copié !'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    child: const Text(
                      'Copier',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareBtn(
                  icon: Icons.message,
                  label: 'Message',
                  color: Colors.green,
                  onTap: () => Navigator.pop(context),
                ),
                _ShareBtn(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () => Navigator.pop(context),
                ),
                _ShareBtn(
                  icon: Icons.send,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => Navigator.pop(context),
                ),
                _ShareBtn(
                  icon: Icons.more_horiz,
                  label: 'Autre',
                  color: Colors.white54,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showVideos(String title, List<Map<String, dynamic>> videos) {
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
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${videos.length} vidéos',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const Divider(color: Colors.white12, height: 24),
            if (videos.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 64),
                      SizedBox(height: 12),
                      Text(
                        'Aucune vidéo pour l\'instant',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  controller: sc,
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 9 / 16,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (_, i) => Container(
                    color: AppColors.normalSurface,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Row(
                            children: [
                              const Icon(Icons.play_arrow, color: Colors.white70, size: 12),
                              Text(
                                videos[i]['views'] as String,
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
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
              'Paramètres',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _SettingItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
            _SettingItem(icon: Icons.lock_outline, label: 'Confidentialité', onTap: () {}),
            _SettingItem(icon: Icons.security, label: 'Sécurité du compte', onTap: () {}),
            _SettingItem(icon: Icons.language, label: 'Langue : Français', onTap: () {}),
            _SettingItem(icon: Icons.info_outline, label: 'À propos de BeninPlay', onTap: () {}),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
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
              'Aide & Support',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ..._faqItems.map((faq) => _FaqItem(q: faq['q']!, a: faq['a']!)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.support_agent, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contacter le support',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'support@beninplay.app',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text('Déconnexion', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.normalBg,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: _showSettings,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A2E), AppColors.normalBg],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _editProfile,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              _displayName[0],
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(_bio, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(value: statsVideos, label: 'Vidéos'),
                      _StatItem(value: statsFollowers, label: 'Abonnés'),
                      _StatItem(value: statsFollowing, label: 'Abonnements'),
                      _StatItem(value: statsLikes, label: 'Likes'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _editProfile,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Modifier profil',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _shareProfile,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Partager profil',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DarkGateScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.darkPrimary.withValues(alpha: 0.4),
                            AppColors.darkBg,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.darkPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text('🔞', style: TextStyle(fontSize: 28)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zone Dark',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Accédez aux contenus exclusifs +18',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _MenuItem(
                    icon: Icons.videocam_outlined,
                    label: 'Mes vidéos',
                    badge: statsVideos,
                    onTap: () => _showVideos('Mes vidéos', _myVideos),
                  ),
                  _MenuItem(
                    icon: Icons.favorite_outline,
                    label: 'Vidéos aimées',
                    onTap: () => _showVideos('Vidéos aimées', _likedVideos),
                  ),
                  _MenuItem(
                    icon: Icons.bookmark_outline,
                    label: 'Enregistrées',
                    onTap: () => _showVideos('Vidéos enregistrées', _savedVideos),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline,
                    label: 'Aide & Support',
                    onTap: _showHelp,
                  ),
                  _MenuItem(
                    icon: Icons.logout,
                    label: 'Déconnexion',
                    color: AppColors.error,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.badge,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ShareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      onTap: onTap,
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          widget.q,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          _open ? Icons.expand_less : Icons.expand_more,
          color: Colors.white54,
        ),
        onTap: () => setState(() => _open = !_open),
        subtitle: _open
            ? Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            widget.a,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        )
            : null,
      ),
    );
  }
}

const _faqItems = [
  {
    'q': 'Comment publier une vidéo ?',
    'a': 'Appuyez sur le bouton + au centre de la barre de navigation. Choisissez d\'enregistrer une nouvelle vidéo ou d\'importer depuis votre galerie.',
  },
  {
    'q': 'Comment accéder à la Zone Dark ?',
    'a': 'La Zone Dark est réservée aux adultes (+18 ans). Vous devez vérifier votre identité avec une photo de votre CIP, puis souscrire un abonnement mensuel à 2 000 FCFA.',
  },
  {
    'q': 'Comment retirer mes gains ?',
    'a': 'Allez dans l\'onglet Portefeuille, appuyez sur "Retirer". Le minimum est 500 FCFA via MTN MoMo ou Moov Money. Des frais de 1% s\'appliquent.',
  },
  {
    'q': 'Comment gagner de l\'argent ?',
    'a': 'Vous pouvez gagner via les abonnements à votre Zone Dark, les tips (pourboires) de vos fans, les ventes de vidéos à l\'unité, et les publicités sur vos vidéos normales.',
  },
  {
    'q': 'Mon compte a été suspendu, pourquoi ?',
    'a': 'Votre compte peut être suspendu pour violation des conditions d\'utilisation : contenu illégal, spam, fausse identité, ou fraude aux paiements. Contactez le support pour plus d\'informations.',
  },
];
