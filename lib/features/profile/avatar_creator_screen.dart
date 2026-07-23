import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

/// Créateur d'avatar « emoji + fond » : l'utilisateur choisit un emoji (ou sa
/// première lettre) et un fond dégradé ; l'app génère une image ronde et la
/// définit comme photo de profil. Léger, joli, sans aucune image externe.
///
/// Renvoie l'URL de l'avatar créé (ou null si annulé).
class AvatarCreatorScreen extends StatefulWidget {
  final String initial; // lettre de repli (première lettre du nom)
  const AvatarCreatorScreen({super.key, this.initial = '?'});

  @override
  State<AvatarCreatorScreen> createState() => _AvatarCreatorScreenState();
}

class _AvatarCreatorScreenState extends State<AvatarCreatorScreen> {
  final GlobalKey _previewKey = GlobalKey();
  String _emoji = ''; // '' = utiliser la lettre
  int _bg = 0;
  bool _saving = false;

  // Fonds dégradés proposés.
  static const List<List<Color>> _backgrounds = [
    [Color(0xFF00E676), Color(0xFF00B248)],
    [Color(0xFF7C4DFF), Color(0xFF3F1DCB)],
    [Color(0xFFFF5252), Color(0xFFB71C1C)],
    [Color(0xFFFFB300), Color(0xFFFF6F00)],
    [Color(0xFF29B6F6), Color(0xFF0277BD)],
    [Color(0xFFFF4081), Color(0xFFC2185B)],
    [Color(0xFF26C6DA), Color(0xFF00838F)],
    [Color(0xFF66BB6A), Color(0xFF2E7D32)],
    [Color(0xFF8D6E63), Color(0xFF4E342E)],
    [Color(0xFF455A64), Color(0xFF1C313A)],
  ];

  static const List<String> _emojis = [
    '😀', '😎', '🥳', '😍', '🤩', '😇', '🤠', '🥸',
    '🔥', '⭐', '👑', '💎', '🚀', '⚽', '🎧', '🎬',
    '🦁', '🐯', '🐼', '🦊', '🐸', '🦄', '🐲', '🦅',
    '❤️', '💜', '💚', '💙', '🧡', '🇧🇯', '🏆', '💯',
  ];

  Widget _avatarPreview({double size = 160}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backgrounds[_bg],
        ),
      ),
      alignment: Alignment.center,
      child: _emoji.isNotEmpty
          ? Text(_emoji, style: TextStyle(fontSize: size * 0.5))
          : Text(
              widget.initial.isNotEmpty ? widget.initial[0].toUpperCase() : '?',
              style: TextStyle(fontSize: size * 0.45, color: Colors.white, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Rend l'aperçu en image PNG.
      final boundary = _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      final url = await ApiService.uploadAvatar(file.path);
      if (!mounted) return;
      if (url != null) {
        Navigator.pop(context, url);
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.error, content: Text('Échec de l\'enregistrement de l\'avatar')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.error, content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalBg,
        title: const Text('Créer mon avatar', style: TextStyle(fontSize: 18)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          // Aperçu (capturé tel quel en image).
          RepaintBoundary(key: _previewKey, child: _avatarPreview()),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const Text('Fond', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12, runSpacing: 12,
                  children: List.generate(_backgrounds.length, (i) {
                    final sel = i == _bg;
                    return GestureDetector(
                      onTap: () => setState(() => _bg = i),
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: _backgrounds[i]),
                          border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                const Text('Symbole', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    // Option « lettre ».
                    GestureDetector(
                      onTap: () => setState(() => _emoji = ''),
                      child: Container(
                        width: 46, height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _emoji.isEmpty ? AppColors.primary : Colors.transparent, width: 2),
                        ),
                        child: Text(widget.initial.isNotEmpty ? widget.initial[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    ..._emojis.map((e) => GestureDetector(
                          onTap: () => setState(() => _emoji = e),
                          child: Container(
                            width: 46, height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _emoji == e ? AppColors.primary : Colors.transparent, width: 2),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 24)),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Utiliser comme photo de profil', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
