import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../services/sound_service.dart';
import '../profile/creator_profile_screen.dart';
import '../upload/quick_publish.dart';

/// Page d'un « son » (façon TikTok) : infos + toutes les vidéos qui l'utilisent
/// + bouton « Utiliser ce son ».
class SoundPageScreen extends StatefulWidget {
  final String soundId;
  const SoundPageScreen({super.key, required this.soundId});

  static void open(BuildContext context, String soundId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SoundPageScreen(soundId: soundId)));
  }

  @override
  State<SoundPageScreen> createState() => _SoundPageScreenState();
}

class _SoundPageScreenState extends State<SoundPageScreen> {
  Map<String, dynamic>? _sound;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SoundService.getSound(widget.soundId);
    if (!mounted) return;
    setState(() {
      _sound = data['sound'] is Map ? Map<String, dynamic>.from(data['sound']) : null;
      _videos = ((data['videos'] as List?) ?? [])
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = (_sound?['title'] ?? 'Son').toString();
    final creator = (_sound?['creator_name'] ?? '').toString();
    final uses = (_sound?['uses_count'] is num) ? (_sound!['uses_count'] as num).toInt() : _videos.length;
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(backgroundColor: AppColors.normalBg, title: const Text('Son', style: TextStyle(fontSize: 18))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── En-tête du son ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.black, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(creator.isEmpty ? '' : '@$creator',
                              style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          Text('$uses vidéo${uses > 1 ? 's' : ''}',
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => QuickPublish.record(context, soundId: widget.soundId, label: 'Utiliser ce son'),
                      icon: const Icon(Icons.videocam, size: 18),
                      label: const Text('Utiliser ce son'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _videos.isEmpty
                      ? const Center(child: Text('Aucune vidéo avec ce son', style: TextStyle(color: Colors.white38)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(4),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 9 / 16),
                          itemCount: _videos.length,
                          itemBuilder: (_, i) {
                            final v = _videos[i];
                            final thumb = (v['thumbnail_url'] ?? '').toString();
                            return GestureDetector(
                              onTap: () => CreatorProfileScreen.open(
                                  context, (v['creator_id'] ?? '').toString(),
                                  name: (v['creator_name'] ?? 'Créateur').toString()),
                              child: Container(
                                color: AppColors.normalSurface,
                                child: thumb.isNotEmpty
                                    ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(Icons.play_circle_outline, color: Colors.white24))
                                    : const Center(child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 28)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
