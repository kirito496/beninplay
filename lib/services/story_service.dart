import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/api_service.dart';

/// Un élément de story (photo ou vidéo).
class StoryItem {
  final String id;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final String? caption;
  final DateTime createdAt;

  StoryItem({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
  });

  bool get isVideo => mediaType == 'video';

  factory StoryItem.fromJson(Map<String, dynamic> j) => StoryItem(
        id: (j['id'] ?? '').toString(),
        mediaUrl: AppConfig.cdn((j['media_url'] ?? '').toString()),
        mediaType: (j['media_type'] ?? 'image').toString(),
        caption: j['caption']?.toString(),
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}

/// Les stories d'UN créateur (regroupées).
class StoryGroup {
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final List<StoryItem> items;

  StoryGroup({
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    required this.items,
  });

  factory StoryGroup.fromJson(Map<String, dynamic> j) => StoryGroup(
        creatorId: (j['creator_id'] ?? '').toString(),
        creatorName: (j['creator_name'] ?? 'Créateur').toString(),
        creatorAvatar: j['creator_avatar']?.toString(),
        items: ((j['items'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => StoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class StoryService {
  /// Stories actives (< 24 h) des créateurs suivis + les miennes.
  static Future<List<StoryGroup>> getStories() async {
    try {
      final token = await ApiService.getToken();
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/stories'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(res.body);
      final groups = (data['groups'] as List?) ?? [];
      return groups
          .whereType<Map>()
          .map((g) => StoryGroup.fromJson(Map<String, dynamic>.from(g)))
          .where((g) => g.items.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Publie une story (photo ou courte vidéo). Renvoie true si OK.
  static Future<bool> createStory(String filePath,
      {String? caption, bool isVideo = false}) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final form = FormData.fromMap({
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        'media': await MultipartFile.fromFile(filePath,
            filename: isVideo ? 'story.mp4' : 'story.jpg'),
      });
      final res = await Dio().post(
        '${AppConfig.api}/api/stories',
        data: form,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (_) => true,
        ),
      );
      return res.statusCode == 200 &&
          res.data is Map &&
          res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteStory(String id) async {
    try {
      final token = await ApiService.getToken();
      await http.delete(
        Uri.parse('${AppConfig.api}/api/stories/$id'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }
}
