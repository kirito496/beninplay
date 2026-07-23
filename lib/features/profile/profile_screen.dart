import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/benin_regions.dart';
import '../../shared/models/video_model.dart';
import 'boost_screen.dart';
import 'boosts_dashboard.dart';
import '../dark_zone/dark_gate_screen.dart' as dark_gate;
import '../discover/leaderboard_screen.dart';
import '../notifications/notifications_screen.dart';
import '../saved/saved_videos_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../friends/add_friends_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/app_prefs.dart';
import 'creator_stats_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '?';
  String username = '';
  String _bio = '';
  String _avatarUrl = '';
  String statsVideos = '0';
  String statsFollowers = '0';
  String statsFollowing = '0';
  String statsLikes = '0';
  bool _isCreator = false;
  String _creatorStatus = 'none'; // none | pending | approved | rejected
  String? _myRegion;
  String? _myGender;
  int? _myBirthYear;
  bool _gpsBusy = false;

  List<VideoModel> _myVideos = [];
  List<VideoModel> _likedVideos = [];
  bool _loadingVideos = false;
  int _unread = 0;

  final List<Map<String, dynamic>> _savedVideos = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMyVideos();
    _loadLikedVideos();
    _loadCreatorStatus();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final n = await ApiService.getUnreadCount();
    if (mounted) setState(() => _unread = n);
  }

  Future<void> _loadCreatorStatus() async {
    try {
      final data = await ApiService.getCreatorStatus();
      if (!mounted) return;
      setState(() {
        _isCreator = data['is_creator'] == true;
        _creatorStatus = data['status']?.toString() ?? 'none';
      });
    } catch (_) {}
  }

  Future<void> _applyCreator() async {
    final res = await ApiService.applyToBeCreator();
    if (!mounted) return;
    final ok = res['success'] == true;
    if (ok) setState(() => _creatorStatus = 'pending');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (ok ? 'Demande envoyée' : 'Erreur')),
        backgroundColor: ok ? AppColors.primary : AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildCreatorCard() {
    // Déjà créateur → badge doré
    if (_isCreator) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFFF5A623).withValues(alpha: 0.25),
            const Color(0xFFF5A623).withValues(alpha: 0.05),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.6)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFFF5A623)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Créateur vérifié',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Tu peux monétiser tes vidéos (gains, retraits)',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final pending = _creatorStatus == 'pending';
    return GestureDetector(
      onTap: pending ? null : _applyCreator,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pending ? Colors.white10 : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: pending ? Colors.white24 : AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(pending ? Icons.hourglass_top : Icons.workspace_premium,
                color: pending ? Colors.white54 : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pending ? 'Demande en cours d\'examen' : 'Devenir créateur de contenu',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    pending
                        ? 'Nous examinons ta demande (24-48 h)'
                        : 'Débloque la monétisation : gains, retraits, tableau de bord',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!pending)
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _loadLikedVideos() async {
    try {
      final videos = await ApiService.getLikedVideos();
      if (!mounted) return;
      setState(() {
        _likedVideos = videos.map((v) => VideoModel.fromJson(v)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getMyProfile();
      if (!mounted) return;
      final user = data['user'] as Map<String, dynamic>? ?? {};
      setState(() {
        username = user['username']?.toString() ?? '';
        _displayName = user['display_name']?.toString()
            ?? user['full_name']?.toString()
            ?? user['username']?.toString() ?? 'Moi';
        _bio = user['bio']?.toString() ?? '';
        _avatarUrl = user['avatar_url']?.toString() ?? '';
        _isCreator = user['is_creator'] == true;
        _myRegion = user['region']?.toString();
        _myGender = user['gender']?.toString();
        _myBirthYear = (user['birth_year'] as num?)?.toInt();
        statsFollowers = _fmt(user['followers_count'] ?? user['follower_count'] ?? 0);
        statsFollowing = _fmt(user['following_count'] ?? 0);
        statsLikes = _fmt(user['total_likes'] ?? 0);
      });
    } catch (_) {}
  }

  String _fmt(dynamic n) {
    final val = (n as num?)?.toInt() ?? 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return '$val';
  }

  Future<void> _loadMyVideos() async {
    setState(() => _loadingVideos = true);
    try {
      final videos = await ApiService.getMyVideos();
      if (!mounted) return;
      setState(() {
        _myVideos = videos.map((v) => VideoModel.fromJson(v)).toList();
        statsVideos = '${_myVideos.length}';
        _loadingVideos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingVideos = false);
    }
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);
    String localAvatar = _avatarUrl;
    bool uploading = false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
              child: GestureDetector(
                onTap: uploading ? null : () async {
                  final picker = ImagePicker();
                  final img = await picker.pickImage(
                      source: ImageSource.gallery, maxWidth: 720, imageQuality: 80);
                  if (img == null) return;
                  setSheet(() => uploading = true);
                  final url = await ApiService.uploadAvatar(img.path);
                  if (url != null) {
                    localAvatar = url;
                    if (mounted) setState(() => _avatarUrl = url); // maj immédiate
                  }
                  setSheet(() => uploading = false);
                  if (url == null && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('Échec de l\'envoi de la photo')));
                  }
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary,
                      backgroundImage: localAvatar.isNotEmpty ? NetworkImage(localAvatar) : null,
                      child: localAvatar.isNotEmpty
                          ? null
                          : Text(
                              _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.black, fontSize: 36, fontWeight: FontWeight.bold),
                            ),
                    ),
                    if (uploading)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.black45,
                          child: CircularProgressIndicator(color: Colors.white),
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
              onPressed: saving ? null : () async {
                final newName = nameCtrl.text.trim();
                final newBio = bioCtrl.text.trim();
                setSheet(() => saving = true);
                // Sauvegarde RÉELLE côté serveur (la photo est déjà enregistrée
                // au moment du choix). fullName = nom affiché.
                final res = await ApiService.updateProfile(
                  fullName: newName.isEmpty ? null : newName,
                  bio: newBio.isEmpty ? null : newBio,
                );
                final ok = res['success'] != false; // l'API renvoie l'user maj
                if (!ctx.mounted) return;
                if (ok) {
                  if (mounted) setState(() {
                    if (newName.isNotEmpty) _displayName = newName;
                    _bio = newBio;
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Profil mis à jour ✓'),
                      backgroundColor: AppColors.primary));
                } else {
                  setSheet(() => saving = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('Échec : ${res['message'] ?? 'réessaie'}')));
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
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
                  label: 'SMS',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse(
                        'sms:?body=${Uri.encodeComponent('Suis-moi sur BeninPlay 🎬 beninplay.app/@$username')}'));
                  },
                ),
                _ShareBtn(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse(
                          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent('https://beninplay.app/@$username')}'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                _ShareBtn(
                  icon: Icons.send,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse(
                          'https://wa.me/?text=${Uri.encodeComponent('Suis-moi sur BeninPlay 🎬 beninplay.app/@$username')}'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                _ShareBtn(
                  icon: Icons.more_horiz,
                  label: 'Autre',
                  color: Colors.white54,
                  onTap: () {
                    Navigator.pop(context);
                    Share.share('Suis-moi sur BeninPlay 🎬 beninplay.app/@$username');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _genderChip(String label, String value, StateSetter setSheet) {
    final sel = _myGender == value;
    return GestureDetector(
      onTap: () {
        setSheet(() => _myGender = value);
        ApiService.updateProfile(gender: value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppColors.primary : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(color: sel ? Colors.black : Colors.white, fontSize: 13,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Future<void> _saveRegion(String region) async {
    setState(() => _myRegion = region);
    try {
      await ApiService.updateProfile(region: region);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Région : $region'), backgroundColor: AppColors.primary),
      );
    }
  }

  // Détecte la région via GPS du téléphone
  Future<void> _detectRegionGps(StateSetter setSheet) async {
    setSheet(() => _gpsBusy = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Permission refusée';
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String? found;
      for (final p in places) {
        final candidates = [p.administrativeArea, p.subAdministrativeArea, p.locality, p.subLocality];
        for (final c in candidates) {
          if (c == null) continue;
          final match = BeninRegions.all.firstWhere(
            (r) => c.toLowerCase().contains(r.toLowerCase()) || r.toLowerCase().contains(c.toLowerCase()),
            orElse: () => '',
          );
          if (match.isNotEmpty) { found = match; break; }
          // villes connues
          final low = c.toLowerCase();
          if (low.contains('cotonou')) { found = 'Littoral'; break; }
          if (low.contains('porto') || low.contains('novo')) { found = 'Ouémé'; break; }
          if (low.contains('parakou')) { found = 'Borgou'; break; }
          if (low.contains('calavi')) { found = 'Atlantique'; break; }
        }
        if (found != null) break;
      }
      if (found != null) {
        if (mounted) Navigator.pop(context);
        await _saveRegion(found);
      } else {
        throw 'Région non reconnue';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS indisponible : choisis ta région manuellement'),
              backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setSheet(() => _gpsBusy = false);
    }
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5, expand: false,
          builder: (_, sc) => Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('Ma région',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Sert au ciblage du boost et au contenu local',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _gpsBusy ? null : () => _detectRegionGps(setSheet),
                  icon: _gpsBusy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.my_location, color: AppColors.primary),
                  label: Text(_gpsBusy ? 'Localisation…' : 'Détecter automatiquement (GPS)',
                      style: const TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 24),
              // ── Genre + âge (servent au ciblage du boost) ──────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Genre :', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(width: 10),
                    _genderChip('Homme', 'homme', setSheet),
                    const SizedBox(width: 8),
                    _genderChip('Femme', 'femme', setSheet),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Année de naissance :', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _myBirthYear,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1A2E),
                          hint: const Text('Choisir', style: TextStyle(color: Colors.white38)),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: List.generate(70, (i) => DateTime.now().year - 13 - i)
                              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                              .toList(),
                          onChanged: (y) {
                            if (y == null) return;
                            setSheet(() => _myBirthYear = y);
                            ApiService.updateProfile(birthYear: y);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 16, bottom: 8),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text('Département', style: TextStyle(color: Colors.white54, fontSize: 13))),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  children: BeninRegions.all.map((r) => ListTile(
                    leading: Icon(
                      _myRegion == r ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: _myRegion == r ? AppColors.primary : Colors.white38,
                    ),
                    title: Text(r, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(BeninRegions.capitals[r] ?? '',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    onTap: () { Navigator.pop(context); _saveRegion(r); },
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideos(String title, List<dynamic> videos, {bool boostable = false}) {
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
                  itemBuilder: (_, i) {
                    final v = videos[i];
                    final isVideoModel = v is VideoModel;
                    final thumb = isVideoModel ? v.thumbnailUrl : null;
                    final videoUrl = isVideoModel ? v.videoUrl : null;
                    final views = isVideoModel
                        ? '${v.views}'
                        : (v as Map)['views'] as String? ?? '0';
                    return Container(
                      color: AppColors.normalSurface,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumb != null && thumb.isNotEmpty)
                            Image.network(thumb, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _VideoThumb(videoUrl: videoUrl))
                          else
                            _VideoThumb(videoUrl: videoUrl),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Row(
                              children: [
                                const Icon(Icons.play_arrow, color: Colors.white70, size: 12),
                                Text(views, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                          ),
                          if (boostable && isVideoModel)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  final ok = await BoostScreen.open(context, v.id);
                                  if (ok == true && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Vidéo boostée ! 🚀'),
                                          backgroundColor: AppColors.primary),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🚀', style: TextStyle(fontSize: 10)),
                                      SizedBox(width: 2),
                                      Text('Boost',
                                          style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
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
            _SettingItem(icon: Icons.notifications_outlined, label: 'Notifications',
                onTap: () { Navigator.pop(context); NotificationsSettingsScreen.open(context); }),
            _SettingItem(icon: Icons.lock_outline, label: 'Confidentialité',
                onTap: () { Navigator.pop(context); PrivacySettingsScreen.open(context); }),
            _SettingItem(icon: Icons.security, label: 'Sécurité du compte',
                onTap: () { Navigator.pop(context); SecuritySettingsScreen.open(context); }),
            _SettingItem(icon: Icons.language, label: 'Langue : ${AppPrefs.labelFor(AppPrefs.language.value)}',
                onTap: () { Navigator.pop(context); LanguageSettingsScreen.open(context); }),
            _SettingItem(icon: Icons.info_outline, label: 'À propos de BeninPlay',
                onTap: () { Navigator.pop(context); AboutScreen.open(context); }),
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

  // Pages légales publiques (hébergées sur l'API)
  void _openLegal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.gavel, color: Colors.white70),
              title: const Text("Conditions générales d'utilisation",
                  style: TextStyle(color: Colors.white)),
              onTap: () => launchUrl(Uri.parse('${AppConfig.api}/cgu'),
                  mode: LaunchMode.externalApplication),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
              title: const Text('Politique de confidentialité',
                  style: TextStyle(color: Colors.white)),
              onTap: () => launchUrl(Uri.parse('${AppConfig.api}/confidentialite'),
                  mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Suppression DÉFINITIVE du compte (exigence Google Play) : double confirmation.
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: const Text('Supprimer ton compte ?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Cette action est DÉFINITIVE :\n\n'
          '• toutes tes vidéos seront supprimées\n'
          '• ton solde et tes gains restants seront perdus\n'
          '• ton profil sera effacé\n\n'
          'Pense à retirer ton argent avant.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reallyDeleteAccount();
            },
            child: const Text('Continuer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _reallyDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: const Text('Dernière confirmation',
            style: TextStyle(color: AppColors.error)),
        content: const Text(
          'Confirme la suppression définitive de ton compte BeninPlay.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.deleteAccount();
              if (!mounted) return;
              if (res['success'] == true) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res['message']?.toString() ?? 'Suppression impossible'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: const Text('Supprimer définitivement'),
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
                // Bannière créateur : profondeur verte + lueur (fini le plat)
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1.2),
                    radius: 1.6,
                    colors: [Color(0xFF11522B), Color(0xFF07200F), AppColors.normalBg],
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
                          // Anneau dégradé autour de l'avatar (façon story)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF00E676), AppColors.accent],
                              ),
                            ),
                            child: CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.primary,
                            backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                            child: _avatarUrl.isNotEmpty
                                ? null
                                : Text(
                                    _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                  // Stats en carte "vitrée" — vitrine du créateur
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(value: statsVideos, label: 'Vidéos'),
                        _StatItem(value: statsFollowers, label: 'Abonnés'),
                        _StatItem(value: statsFollowing, label: 'Abonnements'),
                        _StatItem(value: statsLikes, label: 'Likes'),
                      ],
                    ),
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

                  _buildCreatorCard(),

                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const dark_gate.DarkGateScreen()),
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
                    icon: Icons.location_on_outlined,
                    label: 'Ma région',
                    badge: _myRegion ?? 'Définir',
                    onTap: _showRegionPicker,
                  ),
                  _MenuItem(
                    icon: Icons.videocam_outlined,
                    label: 'Mes vidéos',
                    badge: statsVideos,
                    onTap: () => _showVideos('Mes vidéos', _myVideos.cast<dynamic>(), boostable: true),
                  ),
                  _MenuItem(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    badge: _unread > 0 ? '$_unread' : null,
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      _loadUnread();
                    },
                  ),
                  _MenuItem(
                    icon: Icons.rocket_launch_outlined,
                    label: 'Mes boosts',
                    onTap: () => BoostsDashboard.show(context),
                  ),
                  _MenuItem(
                    icon: Icons.insights_outlined,
                    label: 'Mes statistiques',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CreatorStatsScreen())),
                  ),
                  _MenuItem(
                    icon: Icons.leaderboard_outlined,
                    label: 'Classement des créateurs',
                    onTap: () => CreatorLeaderboard.show(context),
                  ),
                  _MenuItem(
                    icon: Icons.favorite_outline,
                    label: 'Vidéos aimées',
                    badge: '${_likedVideos.length}',
                    onTap: () => _showVideos('Vidéos aimées', _likedVideos.cast<dynamic>()),
                  ),
                  _MenuItem(
                    icon: Icons.bookmark_border,
                    label: 'Mes favoris',
                    onTap: () => SavedVideosScreen.open(context),
                  ),
                  _MenuItem(
                    icon: Icons.smart_toy_outlined,
                    label: 'Assistant IA 🤖',
                    onTap: () => AiChatScreen.open(context),
                  ),
                  _MenuItem(
                    icon: Icons.qr_code_2,
                    label: 'Ajouter des amis',
                    onTap: () => AddFriendsScreen.open(context),
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
                    icon: Icons.description_outlined,
                    label: 'CGU & Confidentialité',
                    onTap: _openLegal,
                  ),
                  _MenuItem(
                    icon: Icons.logout,
                    label: 'Déconnexion',
                    color: AppColors.error,
                    onTap: _confirmLogout,
                  ),
                  _MenuItem(
                    icon: Icons.delete_forever_outlined,
                    label: 'Supprimer mon compte',
                    color: AppColors.error,
                    onTap: _confirmDeleteAccount,
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

// Génère une miniature à partir de la vidéo (mise en cache mémoire)
class _VideoThumb extends StatefulWidget {
  final String? videoUrl;
  const _VideoThumb({this.videoUrl});

  static final Map<String, String> _cache = {};

  // ── Limiteur de concurrence ────────────────────────────────────────────
  // Générer une miniature = TÉLÉCHARGER + DÉCODER la vidéo distante. Dans une
  // grille (« Mes vidéos »), en lancer 10+ à la fois SATURE le fil principal
  // et gèle l'appli (l'écran ouvert par-dessus, ex. Boost, reste vide). On en
  // autorise donc 2 à la fois ; les autres attendent leur tour.
  static const _maxConcurrent = 2;
  static int _inFlight = 0;
  static final List<Completer<void>> _waiters = [];

  static Future<void> _acquire() async {
    if (_inFlight < _maxConcurrent) {
      _inFlight++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future; // le créneau nous est transmis à la libération
  }

  static void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(); // passe le créneau au suivant
    } else {
      _inFlight--;
    }
  }

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) return;
    // Déjà en cache ?
    if (_VideoThumb._cache.containsKey(url)) {
      setState(() => _path = _VideoThumb._cache[url]);
      return;
    }
    await _VideoThumb._acquire(); // au plus 2 générations simultanées
    try {
      final dir = await getTemporaryDirectory();
      final thumb = await VideoThumbnail.thumbnailFile(
        video: url,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 50,
      );
      if (thumb != null) {
        _VideoThumb._cache[url] = thumb;
        if (mounted) setState(() => _path = thumb);
      }
    } catch (_) {
    } finally {
      _VideoThumb._release();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_path != null) {
      return Image.file(File(_path!), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36));
    }
    return const Center(
      child: Icon(Icons.play_circle_fill, color: Colors.white24, size: 36),
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
