import 'package:shared_preferences/shared_preferences.dart';

/// Mémoire des vidéos DÉJÀ VUES (persistée sur le téléphone).
///
/// À chaque chargement du fil, l'app envoie ces IDs au serveur (`exclude`),
/// qui ne les repropose pas → même en rafraîchissant, on tombe sur d'AUTRES
/// vidéos. Quand tout a été vu (le serveur ne renvoie plus rien), on vide la
/// liste pour pouvoir recommencer un nouveau cycle.
class SeenVideos {
  SeenVideos._();

  static const _key = 'bp_seen_videos_v1';
  static const _max = 300; // on garde les 300 plus récentes (borne l'URL)

  static final List<String> _order = []; // du plus ancien au plus récent
  static final Set<String> _set = {};
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    _order
      ..clear()
      ..addAll(list);
    _set
      ..clear()
      ..addAll(list);
    _loaded = true;
  }

  /// Marque une vidéo comme vue.
  static Future<void> add(String id) async {
    if (id.isEmpty || id == 'bee_fallback') return;
    await init();
    if (_set.contains(id)) return;
    _set.add(id);
    _order.add(id);
    while (_order.length > _max) {
      final old = _order.removeAt(0);
      _set.remove(old);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _order);
  }

  /// IDs à exclure du prochain chargement (chaîne séparée par des virgules).
  static Future<String> excludeParam() async {
    await init();
    return _order.join(',');
  }

  /// Vide la mémoire (nouveau cycle quand tout a été vu).
  static Future<void> reset() async {
    _order.clear();
    _set.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
