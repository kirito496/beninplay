import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_service.dart';
import '../../core/app_config.dart';
import '../../core/app_prefs.dart';
import '../../core/biometric.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

// Version affichée (à incrémenter à chaque release).
const String kAppVersion = '1.0.0';

/// Tuile interrupteur générique branchée sur une clé de préférence.
class _ToggleTile extends StatefulWidget {
  final String prefKey;
  final bool defaultValue;
  final String title;
  final String? subtitle;
  final IconData icon;
  const _ToggleTile({
    required this.prefKey,
    required this.defaultValue,
    required this.title,
    this.subtitle,
    required this.icon,
  });

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _v = AppPrefs.getBool(widget.prefKey, widget.defaultValue);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: _v,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      secondary: Icon(widget.icon, color: Colors.white70),
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      subtitle: widget.subtitle == null
          ? null
          : Text(widget.subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      onChanged: (nv) {
        setState(() => _v = nv);
        AppPrefs.setBool(widget.prefKey, nv);
      },
    );
  }
}

Widget _settingsScaffold(String title, List<Widget> children) => Builder(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.normalBg,
        appBar: AppBar(backgroundColor: AppColors.normalBg, title: Text(title, style: const TextStyle(fontSize: 18))),
        body: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    );

// ── Notifications ───────────────────────────────────────────────────────────
class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});
  static void open(BuildContext c) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()));

  @override
  Widget build(BuildContext context) => _settingsScaffold('Notifications', const [
        _ToggleTile(prefKey: 'notif_likes', defaultValue: true, icon: Icons.favorite_border, title: 'J\'aime'),
        _ToggleTile(prefKey: 'notif_comments', defaultValue: true, icon: Icons.comment_outlined, title: 'Commentaires'),
        _ToggleTile(prefKey: 'notif_follows', defaultValue: true, icon: Icons.person_add_alt, title: 'Nouveaux abonnés'),
        _ToggleTile(prefKey: 'notif_messages', defaultValue: true, icon: Icons.chat_bubble_outline, title: 'Messages'),
        _ToggleTile(prefKey: 'notif_lives', defaultValue: true, icon: Icons.live_tv, title: 'Lives'),
        Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('Tu choisis ce qui t\'intéresse. Tes préférences sont enregistrées sur ce téléphone.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
        Divider(color: Colors.white12, height: 32),
        _TestPushButton(),
      ]);
}

/// Bouton « Tester les notifications » : s'envoie un push et affiche le
/// diagnostic renvoyé par le serveur (config Azure + jeton de l'appareil).
class _TestPushButton extends StatefulWidget {
  const _TestPushButton();
  @override
  State<_TestPushButton> createState() => _TestPushButtonState();
}

class _TestPushButtonState extends State<_TestPushButton> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    final res = await ApiService.testPush();
    if (!mounted) return;
    setState(() => _loading = false);
    final ok = res['success'] == true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: Text(ok ? '✅ Test réussi' : '⚠️ Diagnostic',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(
          (res['message'] ?? 'Résultat inconnu').toString(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
      title: const Text('Tester les notifications', style: TextStyle(color: Colors.white)),
      subtitle: const Text('S\'envoyer un push de vérification', style: TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: _loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: _loading ? null : _run,
    );
  }
}

// ── Confidentialité ─────────────────────────────────────────────────────────
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});
  static void open(BuildContext c) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()));

  @override
  Widget build(BuildContext context) => _settingsScaffold('Confidentialité', const [
        _ToggleTile(prefKey: 'priv_private', defaultValue: false, icon: Icons.lock_outline,
            title: 'Compte privé', subtitle: 'Seuls tes abonnés voient tes vidéos'),
        _ToggleTile(prefKey: 'priv_comments', defaultValue: true, icon: Icons.mode_comment_outlined,
            title: 'Autoriser les commentaires'),
        _ToggleTile(prefKey: 'priv_messages', defaultValue: true, icon: Icons.forum_outlined,
            title: 'Autoriser les messages'),
        _ToggleTile(prefKey: 'priv_download', defaultValue: true, icon: Icons.download_outlined,
            title: 'Autoriser le téléchargement de mes vidéos'),
      ]);
}

// ── Sécurité ────────────────────────────────────────────────────────────────
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});
  static void open(BuildContext c) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()));

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _lock = AppPrefs.biometricLock;

  Future<void> _toggleLock(bool v) async {
    if (v) {
      final ok = await Biometric.confirm('Active le verrouillage de BeninPlay');
      if (!ok) return;
    }
    await AppPrefs.setBiometricLock(v);
    if (mounted) setState(() => _lock = v);
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: const Text('Supprimer mon compte ?', style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Cette action est DÉFINITIVE : ton compte, tes vidéos et tes données seront supprimés.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, minimumSize: const Size(0, 42), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await ApiService.deleteAccount();
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        content: Text(res['message']?.toString() ?? 'Suppression impossible')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(backgroundColor: AppColors.normalBg, title: const Text('Sécurité du compte', style: TextStyle(fontSize: 18))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
          value: _lock,
          activeColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          secondary: const Icon(Icons.fingerprint, color: Colors.white70),
          title: const Text('Verrouillage biométrique', style: TextStyle(color: Colors.white)),
          subtitle: const Text('Empreinte / visage à l\'ouverture de l\'app', style: TextStyle(color: Colors.white38, fontSize: 12)),
          onChanged: _toggleLock,
        ),
        const Divider(color: Colors.white12),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.delete_forever, color: AppColors.error),
          title: const Text('Supprimer mon compte', style: TextStyle(color: AppColors.error)),
          subtitle: const Text('Action définitive', style: TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: _deleteAccount,
        ),
      ]),
    );
  }
}

// ── Langue ──────────────────────────────────────────────────────────────────
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});
  static void open(BuildContext c) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()));

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  late String _code = AppPrefs.language.value;
  static const _langs = {'fr': 'Français', 'en': 'English', 'fon': 'Fɔngbè', 'yo': 'Yorùbá'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(backgroundColor: AppColors.normalBg, title: const Text('Langue', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._langs.entries.map((e) => RadioListTile<String>(
                value: e.key,
                groupValue: _code,
                activeColor: AppColors.primary,
                title: Text(e.value, style: const TextStyle(color: Colors.white)),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _code = v);
                  AppPrefs.setLanguage(v);
                },
              )),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Ton choix est enregistré. L\'interface est en français ; les autres langues arrivent progressivement.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── À propos ────────────────────────────────────────────────────────────────
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  static void open(BuildContext c) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => const AboutScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(backgroundColor: AppColors.normalBg, title: const Text('À propos', style: TextStyle(fontSize: 18))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 12),
        const Center(child: Text('🎬', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 8),
        const Center(child: Text('BeninPlay',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
        const Center(child: Text('Version $kAppVersion', style: TextStyle(color: Colors.white54))),
        const SizedBox(height: 8),
        const Center(child: Text('Le divertissement béninois 🇧🇯',
            style: TextStyle(color: Colors.white54, fontSize: 13))),
        const SizedBox(height: 28),
        ListTile(
          leading: const Icon(Icons.gavel, color: Colors.white70),
          title: const Text('Conditions générales', style: TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
          onTap: () => launchUrl(Uri.parse('${AppConfig.api}/cgu'), mode: LaunchMode.externalApplication),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
          title: const Text('Politique de confidentialité', style: TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
          onTap: () => launchUrl(Uri.parse('${AppConfig.api}/confidentialite'), mode: LaunchMode.externalApplication),
        ),
        ListTile(
          leading: const Icon(Icons.mail_outline, color: Colors.white70),
          title: const Text('Nous contacter', style: TextStyle(color: Colors.white)),
          onTap: () => launchUrl(Uri.parse('mailto:support@beninplay.app')),
        ),
      ]),
    );
  }
}

