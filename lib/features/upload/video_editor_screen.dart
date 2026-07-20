import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import 'video_effects.dart';

/// Résultat de l'édition : filtre choisi + overlays (texte / emojis).
class EditResult {
  final String? filter; // null = aucun
  final List<VideoOverlayItem> overlays;
  const EditResult({this.filter, this.overlays = const []});
}

/// Éditeur vidéo "façon Snapchat" : filtres couleur, texte et emojis
/// déplaçables. Léger — tout se joue à la lecture, rien n'est ré-encodé.
class VideoEditorScreen extends StatefulWidget {
  final File videoFile;
  const VideoEditorScreen({super.key, required this.videoFile});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _previewFailed = false; // l'aperçu n'a pas pu se charger (on continue quand même)
  String _filter = 'aucun';
  final List<VideoOverlayItem> _items = [];
  bool _overTrash = false;

  static const _emojis = [
    '🔥', '😂', '❤️', '😍', '🇧🇯', '💯', '👏', '🎉',
    '😎', '🙌', '💃', '🕺', '⚽', '🎶', '✨', '👑',
    '😱', '🥰', '💸', '🚀', '🌟', '🤣', '👀', '💚',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.file(widget.videoFile);
      _ctrl = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      // L'aperçu a échoué : on NE bloque PAS la publication. La vidéo reste
      // valable, l'utilisateur peut choisir un filtre / du texte et publier.
      if (mounted) setState(() => _previewFailed = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _addText() async {
    final res = await showDialog<VideoOverlayItem>(
      context: context,
      builder: (_) => const _TextComposer(),
    );
    if (res != null) setState(() => _items.add(res));
  }

  void _addEmoji() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: _emojis
              .map((e) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _items.add(
                          VideoOverlayItem(type: 'emoji', value: e)));
                    },
                    child: Text(e, style: const TextStyle(fontSize: 34)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _finish() {
    Navigator.pop(
      context,
      EditResult(
        filter: _filter == 'aucun' ? null : _filter,
        overlays: List.of(_items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, cts) {
          final area = Size(cts.maxWidth, cts.maxHeight);
          return Stack(
            children: [
              // ── Aperçu vidéo (avec filtre) ──
              Positioned.fill(
                child: _ready && _ctrl != null
                    ? VideoFilters.apply(
                        _filter,
                        FittedBox(
                          fit: _ctrl!.value.aspectRatio < 1.0
                              ? BoxFit.cover
                              : BoxFit.contain,
                          child: SizedBox(
                            width: _ctrl!.value.size.width,
                            height: _ctrl!.value.size.height,
                            child: VideoPlayer(_ctrl!),
                          ),
                        ),
                      )
                    : _previewFailed
                        // Aperçu impossible → on affiche un repli mais on laisse
                        // publier (le bouton Suivant reste actif).
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.movie_outlined,
                                    color: Colors.white38, size: 56),
                                SizedBox(height: 12),
                                Text('Aperçu indisponible',
                                    style: TextStyle(color: Colors.white54)),
                                SizedBox(height: 4),
                                Text('Tu peux quand même publier ta vidéo',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
              ),

              // ── Overlays déplaçables ──
              ..._items.map((it) => _DraggableItem(
                    item: it,
                    area: area,
                    onMove: (dx, dy, overTrash) => setState(() {
                      it.dx = dx;
                      it.dy = dy;
                      _overTrash = overTrash;
                    }),
                    onDrop: () {
                      if (_overTrash) {
                        setState(() => _items.remove(it));
                      }
                      setState(() => _overTrash = false);
                    },
                  )),

              // ── Barre haute : retour + Suivant ──
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _round(Icons.close, () => Navigator.pop(context)),
                    ElevatedButton.icon(
                      // Toujours actif : on ne bloque JAMAIS l'accès au
                      // formulaire de publication, même si l'aperçu charge encore.
                      onPressed: _finish,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Suivant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Outils (droite) : texte, emoji ──
              Positioned(
                top: 70,
                right: 10,
                child: Column(
                  children: [
                    _tool(Icons.title, 'Texte', _addText),
                    const SizedBox(height: 14),
                    _tool(Icons.emoji_emotions_outlined, 'Emoji', _addEmoji),
                  ],
                ),
              ),

              // ── Corbeille (visible en glissant un élément) ──
              if (_overTrash)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                ),

              // ── Carrousel de filtres (bas) ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: VideoFilters.presets.keys.map((name) {
                      final sel = name == _filter;
                      return GestureDetector(
                        onTap: () => setState(() => _filter = name),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              VideoFilters.labels[name] ?? name,
                              style: TextStyle(
                                color: sel ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      );

  Widget _tool(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      );
}

/// Élément déplaçable + pincement pour redimensionner.
class _DraggableItem extends StatefulWidget {
  final VideoOverlayItem item;
  final Size area;
  final void Function(double dx, double dy, bool overTrash) onMove;
  final VoidCallback onDrop;
  const _DraggableItem({
    required this.item,
    required this.area,
    required this.onMove,
    required this.onDrop,
  });

  @override
  State<_DraggableItem> createState() => _DraggableItemState();
}

class _DraggableItemState extends State<_DraggableItem> {
  double _baseScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final fontSize = it.baseSize * it.scale;
    final w = it.type == 'emoji'
        ? Text(it.value, style: TextStyle(fontSize: fontSize))
        : Text(
            it.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              color: Color(it.color),
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
              ],
            ),
          );
    return Positioned(
      left: it.dx * widget.area.width - 60,
      top: it.dy * widget.area.height - fontSize,
      child: GestureDetector(
        onScaleStart: (_) => _baseScale = it.scale,
        onScaleUpdate: (d) {
          final nx = (it.dx * widget.area.width + d.focalPointDelta.dx)
              .clamp(0.0, widget.area.width);
          final ny = (it.dy * widget.area.height + d.focalPointDelta.dy)
              .clamp(0.0, widget.area.height);
          final overTrash = ny > widget.area.height - 170 &&
              (nx - widget.area.width / 2).abs() < 60;
          setState(() => it.scale = (_baseScale * d.scale).clamp(0.4, 4.0));
          widget.onMove(
              nx / widget.area.width, ny / widget.area.height, overTrash);
        },
        onScaleEnd: (_) => widget.onDrop(),
        child: Container(
          constraints: const BoxConstraints(minWidth: 120),
          alignment: Alignment.center,
          child: w,
        ),
      ),
    );
  }
}

/// Dialogue de saisie de texte + choix de couleur.
class _TextComposer extends StatefulWidget {
  const _TextComposer();

  @override
  State<_TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<_TextComposer> {
  final _ctrl = TextEditingController();
  int _color = 0xFFFFFFFF;

  static const _colors = [
    0xFFFFFFFF, 0xFF00C853, 0xFFFFD600, 0xFFFF5252,
    0xFF2196F3, 0xFFE91E63, 0xFF9C27B0, 0xFF000000,
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.normalSurface,
      title: const Text('Ajouter du texte',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 60,
            style: TextStyle(color: Color(_color), fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Votre texte…',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colors
                .map((c) => GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? AppColors.primary
                                : Colors.white24,
                            width: _color == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () {
            final t = _ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(
              context,
              VideoOverlayItem(type: 'text', value: t, color: _color),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
