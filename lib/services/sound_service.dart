import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/api_service.dart';

class SoundInfo {
  final String id;
  final String title;
  final String creatorName;
  final int usesCount;
  SoundInfo({required this.id, required this.title, required this.creatorName, required this.usesCount});

  factory SoundInfo.fromJson(Map<String, dynamic> j) => SoundInfo(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? 'Son original').toString(),
        creatorName: (j['creator_name'] ?? 'Créateur').toString(),
        usesCount: (j['uses_count'] is num) ? (j['uses_count'] as num).toInt() : 0,
      );
}

class SoundService {
  static Future<String?> _token() => ApiService.getToken();

  /// Le son utilisé par une vidéo (ou null).
  static Future<SoundInfo?> byVideo(String videoId) async {
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/sounds/by-video/$videoId'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      if (data['sound'] == null) return null;
      return SoundInfo.fromJson(Map<String, dynamic>.from(data['sound']));
    } catch (_) {
      return null;
    }
  }

  /// Détail d'un son + vidéos qui l'utilisent.
  static Future<Map<String, dynamic>> getSound(String id) async {
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/sounds/$id'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      return {};
    }
  }
}
