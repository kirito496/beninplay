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

  // Stickers par catégories (façon Canva/TikTok).
  static const Map<String, List<String>> _stickerCats = {
    'Populaire': ['🔥', '😂', '❤️', '😍', '💯', '👏', '🎉', '✨', '👑', '🙌', '🥰', '😎'],
    'Visages': ['😀', '😅', '😇', '😜', '🤩', '😱', '🤣', '😭', '😡', '🥳', '😴', '🤔', '🤗', '😏', '🙃', '😬'],
    'Amour': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '💖', '💘', '💝', '💕', '😻'],
    'Fête': ['🎉', '🎊', '🥳', '🎈', '🎂', '🍾', '🥂', '🪅', '🎁', '💃', '🕺', '🎶'],
    'Bénin 🇧🇯': ['🇧🇯', '⚽', '🏆', '🥇', '🌍', '🌴', '🥁', '🎤', '🙏', '💪', '🫶', '👊'],
    'Objets': ['💸', '💰', '🚀', '⭐', '🌟', '💎', '📱', '🎥', '📸', '🔔', '⚡', '☀️'],
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Sécurité : si l'aperçu ne se charge pas en 7 s, on affiche le repli
    // (l'écran n'est JAMAIS bloqué en noir, la publication reste possible).
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted && !_ready) setState(() => _previewFailed = true);
    });
    try {
      final c = VideoPlayerController.file(widget.videoFile);
      _ctrl = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (mounted) setState(() { _ready = true; _previewFailed = false; });
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
      isScrollControlled: true,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            for (final cat in _stickerCats.entries) ...[
              Text(cat.key, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: cat.value
                    .map((e) => GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _items.add(VideoOverlayItem(type: 'emoji', value: e)));
                          },
                          child: Text(e, style: const TextStyle(fontSize: 32)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ],
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
        child: Column(
          children: [
            // ══ BARRE HAUTE (toujours visible) : Fermer + Suivant ══
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _round(Icons.close, () => Navigator.pop(context)),
                  ElevatedButton.icon(
                    onPressed: _finish, // toujours actif
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Suivant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      // IMPORTANT : le theme global impose minimumSize
                      // Size(infinity, 52) (bon pour les gros boutons pleine
                      // largeur), mais dans une Row ça force une « largeur
                      // infinie » et fait planter tout l'éditeur (bouton +
                      // outils + filtres invisibles). On le remet à une taille
                      // finie ici.
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ],
              ),
            ),

            // ══ ZONE VIDÉO (au milieu) : aperçu + overlays + outils ══
            Expanded(
              child: Container(
                // Fond gris foncé (jamais tout noir) : on voit qu'on est bien
                // dans l'éditeur même si l'aperçu met du temps à charger.
                color: const Color(0xFF141414),
                child: LayoutBuilder(builder: (context, cts) {
                final area = Size(cts.maxWidth, cts.maxHeight);
                return Stack(
                  children: [
                    // Aperçu vidéo (avec filtre)
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

                    // Overlays déplaçables (texte / emoji)
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

                    // Outils (droite) : Texte, Emoji
                    Positioned(
                      top: 12,
                      right: 10,
                      child: Column(
                        children: [
                          _tool(Icons.title, 'Texte', _addText),
                          const SizedBox(height: 14),
                          _tool(Icons.emoji_emotions_outlined, 'Emoji', _addEmoji),
                        ],
                      ),
                    ),

                    // Corbeille (visible en glissant un élément)
                    if (_overTrash)
                      Positioned(
                        bottom: 20,
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
                  ],
                );
              }),
              ),
            ),

            // ══ BARRE BASSE (toujours visible) : filtres ══
            Container(
              height: 78,
              width: double.infinity,
              color: Colors.black,
              alignment: Alignment.center,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: VideoFilters.presets.keys.map((name) {
                  final sel = name == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = name),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 16),
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
          ],
        ),
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
    // Largeur max d'un texte = 82% de l'écran → il revient à la ligne au lieu
    // d'être coupé à droite. Cette même règle est utilisée à la lecture.
    final boxW = it.type == 'emoji' ? fontSize * 1.4 : widget.area.width * 0.82;
    final w = overlayContent(it, fontSize);
    // Ancré par son CENTRE (dx, dy) : la boîte de largeur fixe est centrée sur
    // le point → position identique à la lecture dans le fil.
    final left = (it.dx * widget.area.width - boxW / 2)
        .clamp(0.0, (widget.area.width - boxW).clamp(0.0, widget.area.width));
    return Positioned(
      left: left,
      top: (it.dy * widget.area.height - fontSize)
          .clamp(0.0, widget.area.height),
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
        child: SizedBox(
          width: boxW,
          child: Center(child: w),
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
  int _bg = 0; // 0 = aucun fond
  String _style = 'plain'; // 'plain' | 'outline'

  static const _colors = [
    0xFFFFFFFF, 0xFF000000, 0xFF00C853, 0xFFFFD600,
    0xFFFF5252, 0xFF2196F3, 0xFFE91E63, 0xFF9C27B0,
    0xFFFF9800, 0xFF00BCD4, 0xFF8BC34A, 0xFF795548,
  ];
  // Fonds : aucun + quelques pastilles (façon Canva).
  static const _bgs = [
    0, 0xFF000000, 0xFFFFFFFF, 0xFF00C853,
    0xFFFF5252, 0xFF2196F3, 0xFFE91E63, 0xFFFFD600,
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  VideoOverlayItem get _preview =>
      VideoOverlayItem(type: 'text', value: _ctrl.text.isEmpty ? 'Aperçu' : _ctrl.text, color: _color, bg: _bg, style: _style);

  Widget _swatch(int c, bool selected, VoidCallback onTap, {bool isNone = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: isNone ? Colors.transparent : Color(c),
            shape: BoxShape.circle,
            border: Border.all(color: selected ? AppColors.primary : Colors.white24, width: selected ? 3 : 1),
          ),
          child: isNone ? const Icon(Icons.block, color: Colors.white54, size: 16) : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.normalSurface,
      title: const Text('Ajouter du texte', style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aperçu en direct
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: overlayContent(_preview, 22)),
            ),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 80,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Color(_color), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Votre texte…',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true, fillColor: Colors.white10,
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 4),
            // Style : Plein / Contour
            Row(children: [
              _styleChip('Plein', 'plain'),
              const SizedBox(width: 8),
              _styleChip('Contour', 'outline'),
            ]),
            const SizedBox(height: 12),
            const Text('Couleur du texte', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: _colors.map((c) => _swatch(c, _color == c, () => setState(() => _color = c))).toList()),
            const SizedBox(height: 12),
            const Text('Fond', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: _bgs.map((c) => _swatch(c, _bg == c, () => setState(() => _bg = c), isNone: c == 0)).toList()),
          ],
        ),
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
            Navigator.pop(context,
                VideoOverlayItem(type: 'text', value: t, color: _color, bg: _bg, style: _style));
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _styleChip(String label, String value) {
    final sel = _style == value;
    return GestureDetector(
      onTap: () => setState(() => _style = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
