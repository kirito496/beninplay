import 'dart:convert';
import 'package:flutter/material.dart';

/// Filtres couleur "à la Snapchat/TikTok".
///
/// Ils sont appliqués en temps réel via un [ColorFilter] — aucun rendu lourd,
/// aucun ffmpeg : le filtre est juste une métadonnée (son nom) enregistrée avec
/// la vidéo, puis réappliqué à la lecture. Zéro donnée supplémentaire.
class VideoFilters {
  const VideoFilters._();

  /// Matrices 4x5 (RGBA). `null` = aucun filtre (vidéo d'origine).
  static const Map<String, List<double>?> presets = {
    'aucun': null,
    'vif': [
      1.25, 0, 0, 0, 0,
      0, 1.25, 0, 0, 0,
      0, 0, 1.25, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'nb': [
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'chaud': [
      1.15, 0, 0, 0, 15,
      0, 1.05, 0, 0, 5,
      0, 0, 0.9, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'froid': [
      0.9, 0, 0, 0, 0,
      0, 1.0, 0, 0, 5,
      0, 0, 1.2, 0, 15,
      0, 0, 0, 1, 0,
    ],
    'vintage': [
      0.9, 0.5, 0.1, 0, 0,
      0.3, 0.8, 0.1, 0, 0,
      0.2, 0.3, 0.6, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'clair': [
      1.1, 0, 0, 0, 20,
      0, 1.1, 0, 0, 20,
      0, 0, 1.1, 0, 20,
      0, 0, 0, 1, 0,
    ],
    'sepia': [
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'dramatique': [
      1.4, 0, 0, 0, -45,
      0, 1.4, 0, 0, -45,
      0, 0, 1.4, 0, -45,
      0, 0, 0, 1, 0,
    ],
    'rose': [
      1.12, 0, 0, 0, 18,
      0, 0.95, 0, 0, 0,
      0, 0, 1.05, 0, 12,
      0, 0, 0, 1, 0,
    ],
    'cinema': [
      1.05, 0, 0, 0, -8,
      0, 1.0, 0, 0, 0,
      0, 0, 1.15, 0, 14,
      0, 0, 0, 1, 0,
    ],
  };

  /// Noms affichés à l'utilisateur.
  static const Map<String, String> labels = {
    'aucun': 'Normal',
    'vif': 'Vif',
    'nb': 'N&B',
    'chaud': 'Chaud',
    'froid': 'Froid',
    'vintage': 'Vintage',
    'clair': 'Clair',
    'sepia': 'Sépia',
    'dramatique': 'Drama',
    'rose': 'Rose',
    'cinema': 'Ciné',
  };

  /// Renvoie le [ColorFilter] correspondant, ou `null` si aucun/inconnu.
  static ColorFilter? filterFor(String? name) {
    if (name == null) return null;
    final m = presets[name];
    if (m == null) return null;
    return ColorFilter.matrix(m);
  }

  /// Enveloppe [child] dans le filtre `name` (ou le renvoie tel quel).
  static Widget apply(String? name, Widget child) {
    final f = filterFor(name);
    if (f == null) return child;
    return ColorFiltered(colorFilter: f, child: child);
  }
}

/// Un élément posé sur la vidéo : du texte OU un emoji/sticker.
///
/// Positions [dx]/[dy] sont RELATIVES (0..1) à la taille de l'aperçu, pour que
/// l'élément s'affiche au même endroit quelle que soit la taille de l'écran du
/// spectateur.
class VideoOverlayItem {
  final String type; // 'text' | 'emoji'
  final String value;
  double dx; // 0..1 (centre)
  double dy; // 0..1 (centre)
  double scale; // multiplicateur de taille
  final int color; // couleur du texte (ARGB), ignoré pour les emojis
  final int bg; // fond du texte (ARGB) ; 0 = aucun (façon Canva)
  final String style; // 'plain' | 'outline'

  VideoOverlayItem({
    required this.type,
    required this.value,
    this.dx = 0.5,
    this.dy = 0.5,
    this.scale = 1.0,
    this.color = 0xFFFFFFFF,
    this.bg = 0,
    this.style = 'plain',
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'dx': double.parse(dx.toStringAsFixed(4)),
        'dy': double.parse(dy.toStringAsFixed(4)),
        'scale': double.parse(scale.toStringAsFixed(3)),
        'color': color,
        'bg': bg,
        'style': style,
      };

  factory VideoOverlayItem.fromJson(Map<String, dynamic> j) => VideoOverlayItem(
        type: (j['type'] ?? 'text').toString(),
        value: (j['value'] ?? '').toString(),
        dx: (j['dx'] ?? 0.5).toDouble(),
        dy: (j['dy'] ?? 0.5).toDouble(),
        scale: (j['scale'] ?? 1.0).toDouble(),
        color: (j['color'] is int) ? j['color'] : 0xFFFFFFFF,
        bg: (j['bg'] is int) ? j['bg'] : 0,
        style: (j['style'] ?? 'plain').toString(),
      );

  /// Taille de base (avant [scale]) en pixels logiques.
  double get baseSize => type == 'emoji' ? 44 : 22;
}

/// Rendu d'un overlay (emoji ou texte stylé : couleur, contour, fond).
/// Utilisé À LA FOIS par l'éditeur et par la lecture → l'aperçu = le résultat.
/// L'appelant l'enveloppe dans `SizedBox(width: boxW)` + `Center` (retour ligne).
Widget overlayContent(VideoOverlayItem it, double fontSize) {
  if (it.type == 'emoji') {
    return Text(it.value, style: TextStyle(fontSize: fontSize));
  }
  // Contour (façon Canva) : 4 ombres noires ; sinon ombre portée douce.
  final List<Shadow> shadows = it.style == 'outline'
      ? const [
          Shadow(offset: Offset(-1.5, -1.5), color: Colors.black, blurRadius: 1),
          Shadow(offset: Offset(1.5, -1.5), color: Colors.black, blurRadius: 1),
          Shadow(offset: Offset(-1.5, 1.5), color: Colors.black, blurRadius: 1),
          Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 1),
        ]
      : const [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))];
  Widget text = Text(
    it.value,
    textAlign: TextAlign.center,
    softWrap: true,
    style: TextStyle(
      fontSize: fontSize,
      color: Color(it.color),
      fontWeight: FontWeight.w800,
      shadows: shadows,
    ),
  );
  if (it.bg != 0) {
    text = Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.4, vertical: fontSize * 0.18),
      decoration: BoxDecoration(
        color: Color(it.bg),
        borderRadius: BorderRadius.circular(fontSize * 0.35),
      ),
      child: text,
    );
  }
  return text;
}

/// Un trait de dessin à main levée : points RELATIFS (0..1) + couleur + épaisseur
/// (relative à la largeur → même rendu sur tous les écrans).
class DrawStroke {
  final List<Offset> points;
  final int color;
  final double width; // fraction de la largeur (ex: 0.012)
  DrawStroke({required this.points, this.color = 0xFFFFFFFF, this.width = 0.012});

  Map<String, dynamic> toJson() => {
        'c': color,
        'w': double.parse(width.toStringAsFixed(4)),
        'p': points
            .map((o) => [double.parse(o.dx.toStringAsFixed(4)), double.parse(o.dy.toStringAsFixed(4))])
            .toList(),
      };

  factory DrawStroke.fromJson(Map<String, dynamic> j) => DrawStroke(
        color: (j['c'] is int) ? j['c'] : 0xFFFFFFFF,
        width: (j['w'] ?? 0.012).toDouble(),
        points: ((j['p'] as List?) ?? [])
            .map((e) => Offset((e[0] as num).toDouble(), (e[1] as num).toDouble()))
            .toList(),
      );

  static String encode(List<DrawStroke> strokes) =>
      jsonEncode(strokes.map((s) => s.toJson()).toList());

  static List<DrawStroke> decode(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list.whereType<Map>().map((e) => DrawStroke.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    return const [];
  }
}

/// Peint des traits (relatifs) sur une zone de taille [size].
class DrawPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  DrawPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.length < 2) {
        if (s.points.isNotEmpty) {
          final p = Paint()..color = Color(s.color);
          canvas.drawCircle(
              Offset(s.points.first.dx * size.width, s.points.first.dy * size.height),
              (s.width * size.width) / 2, p);
        }
        continue;
      }
      final paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(s.points.first.dx * size.width, s.points.first.dy * size.height);
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx * size.width, s.points[i].dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter old) => old.strokes != strokes;
}

/// Dessine les overlays par-dessus une vidéo, en lecture seule (dans le fil).
/// [size] = taille de la zone vidéo affichée.
class OverlayLayer extends StatelessWidget {
  final List<VideoOverlayItem> items;
  final Size size;
  const OverlayLayer({super.key, required this.items, required this.size});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: items.map((it) {
          // Dessin à main levée : peint sur toute la zone vidéo.
          if (it.type == 'draw') {
            return Positioned.fill(
              child: CustomPaint(painter: DrawPainter(DrawStroke.decode(it.value))),
            );
          }
          final fontSize = it.baseSize * it.scale;
          final isEmoji = it.type == 'emoji';
          // Même règle que l'éditeur : texte limité à 82% de la largeur (il
          // revient à la ligne), boîte centrée sur le point (dx, dy).
          final boxW = isEmoji ? fontSize * 1.4 : size.width * 0.82;
          final child = overlayContent(it, fontSize);
          final left = (it.dx * size.width - boxW / 2)
              .clamp(0.0, (size.width - boxW).clamp(0.0, size.width));
          return Positioned(
            left: left,
            top: (it.dy * size.height - fontSize).clamp(0.0, size.height),
            child: SizedBox(width: boxW, child: Center(child: child)),
          );
        }).toList(),
      ),
    );
  }
}
