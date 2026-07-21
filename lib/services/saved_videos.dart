import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/models/video_model.dart';

/// Favoris (« Enregistrer ») — façon TikTok, mais 100 % LOCAL.
///
/// On stocke sur le téléphone un petit instantané de chaque vidéo enregistrée
/// (titre, miniature, créateur, URL) au format des clés de l'API, pour pouvoir
/// reconstruire des [VideoModel] et les rejouer SANS aucun appel serveur ni
/// migration de base de données. Les favoris survivent au redémarrage de l'app.
class SavedVideos {
  SavedVideos._();

  static const _key = 'bp_saved_videos_v1';

  /// Notifie l'UI (badge/état des boutons) quand la liste change.
  static final ValueNotifier<Set<String>> ids = ValueNotifier<Set<String>>({});
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).whereType<Map>().toList();
        ids.value = list.map((e) => (e['id'] ?? '').toString()).toSet();
      } catch (_) {}
    }
    _loaded = true;
  }

  static Future<List<Map<String, dynamic>>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeAll(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
    ids.value = list.map((e) => (e['id'] ?? '').toString()).toSet();
  }

  /// Vrai si la vidéo est déjà dans les favoris.
  static bool isSaved(String id) => ids.value.contains(id);

  /// Enregistre / retire la vidéo. Renvoie l'état final (true = enregistrée).
  static Future<bool> toggle(VideoModel v) async {
    await _ensureLoaded();
    final list = await _readAll();
    final exists = list.any((e) => e['id'] == v.id);
    if (exists) {
      list.removeWhere((e) => e['id'] == v.id);
      await _writeAll(list);
      return false;
    }
    // Instantané minimal (mêmes clés que l'API → VideoModel.fromJson marche).
    list.insert(0, {
      'id': v.id,
      'creator_id': v.creatorId,
      'creator_name': v.creatorName,
      'creator_avatar': v.creatorAvatar,
      'title': v.title,
      'description': v.description,
      'video_url': v.videoUrl,
      'hls_url': v.hlsUrl,
      'thumbnail_url': v.thumbnailUrl,
      'zone': v.zone.name,
      'likes_count': v.likes,
      'comments_count': v.comments,
      'views': v.views,
      'filter': v.filter,
      'created_at': v.createdAt.toIso8601String(),
    });
    await _writeAll(list);
    return true;
  }

  /// Liste complète des vidéos enregistrées (les plus récentes d'abord).
  static Future<List<VideoModel>> all() async {
    await _ensureLoaded();
    final list = await _readAll();
    return list.map((e) => VideoModel.fromJson(e)).toList();
  }

  /// Précharge l'état au démarrage (pour que les boutons soient à jour).
  static Future<void> init() => _ensureLoaded();

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    ids.value = {};
  }
}
