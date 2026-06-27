import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() => _storage.read(key: 'auth_token');
  static Future<void> saveToken(String token) => _storage.write(key: 'auth_token', value: token);
  static Future<void> clearToken() => _storage.delete(key: 'auth_token');

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static String? _decodeUserId(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['userId']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getCurrentUserId() async {
    final token = await getToken();
    if (token == null) return null;
    return _decodeUserId(token);
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/auth/send-otp'),
      headers: await _headers(),
      body: jsonEncode({'phone': phone}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/auth/verify-otp'),
      headers: await _headers(),
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] == true && data['token'] != null) {
      await saveToken(data['token']);
    }
    return data;
  }

  // ── Vidéos ──────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMyVideos() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos/mine'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['videos'] ?? data['data'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  static Future<List<Map<String, dynamic>>> getLikedVideos() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos/liked'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['videos'] ?? data['data'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Enregistre une vue sur une vidéo (non bloquant)
  static Future<void> registerView(String videoId) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.api}/api/videos/$videoId/view'),
        headers: await _headers(auth: true),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getVideos({int page = 1}) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos?page=$page&limit=20'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> uploadVideo({
    required String filePath,
    required String title,
    String? description,
    String zone = 'normal',
    List<String> tags = const [],
    void Function(String)? onStatus,
    void Function(int percent)? onProgress,
  }) async {
    try {
      onStatus?.call('Lecture du fichier...');
      final bytes = await File(filePath).readAsBytes();
      final ext = filePath.split('.').last.toLowerCase();
      final mimeType = ext == 'mp4'
          ? 'video/mp4'
          : ext == 'mov'
          ? 'video/quicktime'
          : 'video/mp4';

      final userId = await getCurrentUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Non connecté — reconnecte-toi'};
      }

      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      onStatus?.call('Upload en cours...');
      onProgress?.call(0);

      final dio = Dio();
      Response<dynamic> dioRes;
      try {
        dioRes = await dio.post(
          '${AppConfig.supabaseUrl}/storage/v1/object/${AppConfig.storageBucket}/$fileName',
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              'Content-Type': mimeType,
              'Content-Length': '${bytes.length}',
              'x-upsert': 'false',
            },
            sendTimeout: const Duration(minutes: 10),
            receiveTimeout: const Duration(minutes: 2),
          ),
          onSendProgress: (sent, total) {
            if (total > 0) onProgress?.call((sent / total * 100).round());
          },
        );
      } on DioException catch (e) {
        final msg = e.response?.data?.toString() ?? e.message ?? 'Erreur upload';
        // ignore: avoid_print
        print('[uploadVideo] Dio error: $msg');
        return {'success': false, 'message': 'Stockage: $msg'};
      }

      if (dioRes.statusCode != 200 && dioRes.statusCode != 201) {
        return {'success': false, 'message': 'Stockage: erreur ${dioRes.statusCode} — ${dioRes.data}'};
      }

      onProgress?.call(100);
      onStatus?.call('Enregistrement en base...');

      final videoUrl = Supabase.instance.client.storage
          .from(AppConfig.storageBucket)
          .getPublicUrl(fileName);

      final token = await getToken();
      // ignore: avoid_print
      print('[register] token present: ${token != null}, userId: $userId');

      final res = await http.post(
        Uri.parse('${AppConfig.api}/api/videos/register'),
        headers: await _headers(auth: true),
        body: jsonEncode({
          'title': title,
          'video_url': videoUrl,
          'description': description ?? '',
          'zone': zone,
          'tags': tags,
        }),
      );
      // ignore: avoid_print
      print('[register] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 && res.statusCode != 201) {
        return {'success': false, 'message': 'Serveur: ${data['message'] ?? res.statusCode}'};
      }
      return data;
    } catch (e) {
      // ignore: avoid_print
      print('[uploadVideo] ERREUR: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> likeVideo(String videoId) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/videos/$videoId/like'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addComment(String videoId, String content) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/videos/$videoId/comment'),
      headers: await _headers(auth: true),
      body: jsonEncode({'content': content}),
    );
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getComments(String videoId) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos/$videoId/comments'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['comments'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  // ── Payments ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> initiatePayment({
    required int amount,
    required String type,
    required String operator,
    String? videoId,
    String? targetRegion,
    List<String>? targetRegions,
    String? targetGender,
    int? targetAgeMin,
    int? targetAgeMax,
    int? boostDays,
    List<String>? targetTags,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/payments/initiate'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'amount': amount,
        'type': type,
        'operator': operator,
        if (videoId != null) 'videoId': videoId,
        if (targetRegion != null) 'targetRegion': targetRegion,
        if (targetRegions != null) 'targetRegions': targetRegions,
        if (targetGender != null) 'targetGender': targetGender,
        if (targetAgeMin != null) 'targetAgeMin': targetAgeMin,
        if (targetAgeMax != null) 'targetAgeMax': targetAgeMax,
        if (boostDays != null) 'boostDays': boostDays,
        if (targetTags != null) 'targetTags': targetTags,
      }),
    );
    return jsonDecode(res.body);
  }

  // ── Créateurs / Abonnements ───────────────────────────────────────────────

  /// Profil public d'un créateur (+ compteurs + is_following)
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/users/$userId'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    return (data['user'] as Map<String, dynamic>?) ?? {};
  }

  /// Suivre / ne plus suivre un créateur (toggle). Retourne true si suivi.
  static Future<bool> toggleFollow(String userId) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/users/$userId/follow'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    return data['following'] == true;
  }

  /// Vidéos d'un créateur
  static Future<List<Map<String, dynamic>>> getCreatorVideos(String userId) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos?creator_id=$userId&limit=50'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['videos'] ?? data['data'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Feed "Abonnements" : vidéos des créateurs suivis
  static Future<List<Map<String, dynamic>>> getFollowingFeed({int page = 1}) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos/following?page=$page&limit=20'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['videos'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Hashtags les plus populaires (pour le ciblage du boost)
  static Future<List<String>> getPopularTags() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/videos/popular-tags'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      final List<dynamic> list = data['tags'] ?? [];
      return list.map((e) => (e['tag'] ?? '').toString()).where((t) => t.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Estime le nombre d'utilisateurs touchés par un ciblage de boost
  static Future<int> getBoostReach({
    required List<String> regions,
    String gender = 'all',
    int ageMin = 0,
    int ageMax = 120,
  }) async {
    final qp = {
      'regions': regions.join(','),
      'gender': gender,
      'ageMin': '$ageMin',
      'ageMax': '$ageMax',
    };
    final uri = Uri.parse('${AppConfig.api}/api/videos/boost-reach').replace(queryParameters: qp);
    final res = await http.get(uri, headers: await _headers(auth: true));
    final data = jsonDecode(res.body);
    return (data['reach'] as num?)?.toInt() ?? 0;
  }

  /// Tableau de bord : les vidéos boostées de l'utilisateur + performances
  static Future<List<Map<String, dynamic>>> getMyBoosts() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos/my-boosts'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['boosts'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Met à jour le profil (région, genre, année de naissance, pseudo, bio…)
  static Future<Map<String, dynamic>> updateProfile({
    String? region,
    String? username,
    String? bio,
    String? gender,
    int? birthYear,
  }) async {
    final res = await http.put(
      Uri.parse('${AppConfig.api}/api/auth/profile'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        if (region != null) 'region': region,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (gender != null) 'gender': gender,
        if (birthYear != null) 'birthYear': birthYear,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/payments/status/$paymentId'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  // ── Profil ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMyProfile() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/auth/me'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  // ── Wallet ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/wallet/balance'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> withdraw({
    required int amount,
    required String phone,
    required String operator,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/wallet/withdraw'),
      headers: await _headers(auth: true),
      body: jsonEncode({'amount': amount, 'phone': phone, 'operator': operator}),
    );
    return jsonDecode(res.body);
  }

  // ── Boost ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createBoost({
    required String videoId,
    required int amount,
    required int days,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/boost'),
      headers: await _headers(auth: true),
      body: jsonEncode({'video_id': videoId, 'amount': amount, 'days': days}),
    );
    return jsonDecode(res.body);
  }
}
