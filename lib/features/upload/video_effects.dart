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

  VideoOverlayItem({
    required this.type,
    required this.value,
    this.dx = 0.5,
    this.dy = 0.5,
    this.scale = 1.0,
    this.color = 0xFFFFFFFF,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'dx': double.parse(dx.toStringAsFixed(4)),
        'dy': double.parse(dy.toStringAsFixed(4)),
        'scale': double.parse(scale.toStringAsFixed(3)),
        'color': color,
      };

  factory VideoOverlayItem.fromJson(Map<String, dynamic> j) => VideoOverlayItem(
        type: (j['type'] ?? 'text').toString(),
        value: (j['value'] ?? '').toString(),
        dx: (j['dx'] ?? 0.5).toDouble(),
        dy: (j['dy'] ?? 0.5).toDouble(),
        scale: (j['scale'] ?? 1.0).toDouble(),
        color: (j['color'] is int) ? j['color'] : 0xFFFFFFFF,
      );

  /// Taille de base (avant [scale]) en pixels logiques.
  double get baseSize => type == 'emoji' ? 44 : 22;
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
          final fontSize = it.baseSize * it.scale;
          final isEmoji = it.type == 'emoji';
          // Même règle que l'éditeur : texte limité à 82% de la largeur (il
          // revient à la ligne), boîte centrée sur le point (dx, dy).
          final boxW = isEmoji ? fontSize * 1.4 : size.width * 0.82;
          final child = isEmoji
              ? Text(it.value, style: TextStyle(fontSize: fontSize))
              : Text(
                  it.value,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Color(it.color),
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                    ],
                  ),
                );
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
