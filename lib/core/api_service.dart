import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'app_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _native = MethodChannel('beninplay/secure');

  static Future<String?> getToken() => _storage.read(key: 'auth_token');
  static Future<void> saveToken(String token) => _storage.write(key: 'auth_token', value: token);
  static Future<void> clearToken() => _storage.delete(key: 'auth_token');

  /// Identifiant d'appareil stable (anti-multi-comptes).
  /// Priorité à l'ANDROID_ID natif (survit à la réinstallation) ; sinon UUID stocké.
  static Future<String> _deviceId() async {
    var id = await _storage.read(key: 'device_id');
    if (id != null && id.isNotEmpty) return id;
    try {
      final native = await _native.invokeMethod<String>('deviceId');
      if (native != null && native.isNotEmpty) id = 'android:$native';
    } catch (_) {}
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      id = 'rnd:${List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join()}';
    }
    await _storage.write(key: 'device_id', value: id);
    return id;
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = {'Content-Type': 'application/json', 'x-device-id': await _deviceId()};
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

  // ── Auth par email (Brevo) ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendEmailCode(String email) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/auth/email/request'),
      headers: await _headers(),
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/auth/email/verify'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'code': code}),
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

  /// Signale que la vidéo a été regardée jusqu'au bout (impact créateur)
  static Future<void> markVideoCompleted(String videoId) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.api}/api/videos/$videoId/complete'),
        headers: await _headers(auth: true),
      );
    } catch (_) {}
  }

  /// Classement des créateurs par score d'impact
  static Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/users/leaderboard?limit=$limit'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['creators'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
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
    int price = 0,
    List<String> tags = const [],
    void Function(String)? onStatus,
    void Function(int percent)? onProgress,
  }) async {
    try {
      // ── Compression (réduit fortement la taille → upload plus rapide) ──
      String uploadPath = filePath;
      try {
        onStatus?.call('Compression de la vidéo...');
        final info = await VideoCompress.compressVideo(
          filePath,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info != null && info.path != null && info.path!.isNotEmpty) {
          uploadPath = info.path!;
        }
      } catch (_) {
        uploadPath = filePath;
      }

      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non connecté — reconnecte-toi'};
      }

      onStatus?.call('Upload en cours...');
      onProgress?.call(0);

      // ── Envoi AU SERVEUR (clé admin côté serveur → contourne les règles du bucket) ──
      final form = FormData.fromMap({
        'title': title,
        'description': description ?? '',
        'zone': zone,
        'price': '$price',
        'tags': tags.join(','),
        'video': await MultipartFile.fromFile(uploadPath, filename: 'video.mp4'),
      });

      final dio = Dio();
      Response<dynamic> res;
      try {
        res = await dio.post(
          '${AppConfig.api}/api/videos/upload',
          data: form,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            sendTimeout: const Duration(minutes: 10),
            receiveTimeout: const Duration(minutes: 3),
            // On gère nous-mêmes les codes d'erreur (pas d'exception sur 4xx/5xx)
            validateStatus: (_) => true,
          ),
          onSendProgress: (sent, total) {
            if (total > 0) onProgress?.call((sent / total * 100).round());
          },
        );
      } on DioException catch (e) {
        final data = e.response?.data;
        final msg = (data is Map ? data['message'] : null) ?? e.message ?? 'Erreur réseau';
        return {'success': false, 'message': msg.toString()};
      }

      onProgress?.call(100);

      final body = res.data;
      final data = body is Map
          ? Map<String, dynamic>.from(body)
          : <String, dynamic>{'success': false, 'message': 'Réponse serveur invalide'};

      if (res.statusCode != 200 && res.statusCode != 201) {
        return {'success': false, 'message': data['message']?.toString() ?? 'Erreur ${res.statusCode}'};
      }
      return data;
    } catch (e) {
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

  /// État d'accès à la Zone Dark : {kyc_status, subscribed, until, can_access}
  static Future<Map<String, dynamic>> getDarkAccess() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/dark/access'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  /// Soumet la vérification d'identité (+18) pour la Zone Dark.
  static Future<Map<String, dynamic>> submitKyc({String? frontUrl, String? backUrl}) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/dark/kyc/submit'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        if (frontUrl != null) 'front_url': frontUrl,
        if (backUrl != null) 'back_url': backUrl,
      }),
    );
    return jsonDecode(res.body);
  }

  /// Feed INDÉPENDANT de la Zone Dark (+18). Ne renvoie que les vidéos dark.
  static Future<List<Map<String, dynamic>>> getDarkVideos({int page = 1}) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos/dark?page=$page&limit=20'),
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

  // ── Créateur (demande de monétisation) ───────────────────────────────────

  /// Envoie une demande pour devenir créateur de contenu (validée par l'admin).
  static Future<Map<String, dynamic>> applyToBeCreator({String? note}) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/auth/creator/apply'),
      headers: await _headers(auth: true),
      body: jsonEncode({'message': note ?? ''}),
    );
    return jsonDecode(res.body);
  }

  /// Statut de la demande créateur : {is_creator, status: none|pending|approved|rejected}
  static Future<Map<String, dynamic>> getCreatorStatus() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/auth/creator/status'),
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

  // ── Live en direct (Agora) ────────────────────────────────────────────────

  /// Démarre un live → renvoie {liveId, channel, appId, token} (rôle diffuseur)
  static Future<Map<String, dynamic>> startLive(String title) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/live/start'),
      headers: await _headers(auth: true),
      body: jsonEncode({'title': title}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> stopLive(String liveId) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/live/$liveId/stop'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getActiveLives() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/live/active'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    final List<dynamic> list = data['lives'] ?? [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Jeton spectateur pour rejoindre un live → {channel, appId, token}
  static Future<Map<String, dynamic>> getLiveToken(String liveId) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/live/$liveId/token'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  // ── Monétisation (anti-multi-comptes) ────────────────────────────────────

  static Future<Map<String, dynamic>> getMonetizationStatus() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/monetization/status'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> requestMonetizationReview() async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/monetization/review-request'),
      headers: await _headers(auth: true),
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
