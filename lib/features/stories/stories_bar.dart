import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../services/story_service.dart';
import 'story_viewer.dart';

/// Bande horizontale de stories (cercles) façon Snapchat/Instagram.
/// Premier cercle = « Ta story » (+) pour publier ; les autres ouvrent la
/// visionneuse plein écran.
class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  List<StoryGroup> _groups = [];
  bool _loading = true;
  bool _busy = false; // pendant l'upload

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await StoryService.getStories();
    if (mounted) setState(() { _groups = g; _loading = false; });
  }

  Future<void> _createStory() async {
    final source = await showModalBottomSheet<_Pick>(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Nouvelle story',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Prendre une photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, _Pick.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Photo depuis la galerie', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, _Pick.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: AppColors.primary),
              title: const Text('Vidéo depuis la galerie', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, _Pick.video),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    XFile? file;
    bool isVideo = false;
    try {
      if (source == _Pick.video) {
        isVideo = true;
        file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
      } else if (source == _Pick.camera) {
        file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1080, imageQuality: 85);
      } else {
        file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080, imageQuality: 85);
      }
    } catch (_) {}
    if (file == null || !mounted) return;

    final caption = await _askCaption();
    if (!mounted) return;

    setState(() => _busy = true);
    final ok = await StoryService.createStory(file.path, caption: caption, isVideo: isVideo);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? AppColors.primary : AppColors.error,
      content: Text(ok ? 'Story publiée ! Elle disparaîtra dans 24 h.' : 'Échec de la publication.'),
    ));
    if (ok) _load();
  }

  Future<String?> _askCaption() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: const Text('Légende (facultatif)', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 200,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ajoute un texte…',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Passer', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 42), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _groups.isEmpty) {
      return const SizedBox(height: 96);
    }
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _MyStoryCircle(busy: _busy, onTap: _createStory),
          for (int i = 0; i < _groups.length; i++)
            _StoryCircle(
              group: _groups[i],
              onTap: () async {
                await StoryViewer.open(context, _groups, i);
                if (mounted) _load();
              },
            ),
        ],
      ),
    );
  }
}

enum _Pick { camera, photo, video }

class _MyStoryCircle extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _MyStoryCircle({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 62, height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.normalSurface,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.person, color: Colors.white38, size: 30),
                ),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.primary,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.add, color: Colors.black, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Ta story',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  final StoryGroup group;
  final VoidCallback onTap;
  const _StoryCircle({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 62, height: 62,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                child: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  backgroundImage: (group.creatorAvatar != null && group.creatorAvatar!.isNotEmpty)
                      ? NetworkImage(group.creatorAvatar!)
                      : null,
                  child: (group.creatorAvatar == null || group.creatorAvatar!.isEmpty)
                      ? Text(group.creatorName.isNotEmpty ? group.creatorName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(group.creatorName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
