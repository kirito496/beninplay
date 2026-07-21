import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

/// Enregistrement rapide + publication avec une référence (son / duo / stitch).
/// Filme depuis la caméra, demande un titre, envoie ; le montage éventuel
/// (Duo/Stitch) se fait ensuite côté serveur.
class QuickPublish {
  static Future<void> record(
    BuildContext context, {
    String? soundId,
    String? duetSourceId,
    String? stitchSourceId,
    required String label,
  }) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickVideo(
          source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
    } catch (_) {}
    if (file == null || !context.mounted) return;

    final title = await _askTitle(context, label);
    if (title == null || title.trim().isEmpty || !context.mounted) return;

    final status = ValueNotifier<String>('Préparation…');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(status: status),
    );

    final res = await ApiService.uploadVideo(
      filePath: file.path,
      title: title.trim(),
      soundId: soundId,
      duetSourceId: duetSourceId,
      stitchSourceId: stitchSourceId,
      onStatus: (s) => status.value = s,
    );

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? AppColors.primary : AppColors.error,
      content: Text(ok
          ? (duetSourceId != null || stitchSourceId != null
              ? 'Publié ! 🎬 Le montage se termine en arrière-plan.'
              : 'Publié ! 🎬')
          : (res['message']?.toString() ?? 'Échec de la publication')),
    ));
  }

  static Future<String?> _askTitle(BuildContext context, String label) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 120,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Titre de ta vidéo…',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 42), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<String> status;
  const _ProgressDialog({required this.status});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.normalSurface,
      content: Row(
        children: [
          const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          const SizedBox(width: 16),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (_, s, __) => Text(s, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
