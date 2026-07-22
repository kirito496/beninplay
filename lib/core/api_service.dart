import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'app_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _native = MethodChannel('beninplay/secure');

  static Future<String?> getToken() => _storage.read(key: 'auth_token');
  static Future<void> saveToken(String token) => _storage.write(key: 'auth_token', value: token);
  static Future<void> clearToken() => _storage.delete(key: 'auth_token');

  /// Enregistre le jeton FCM de l'appareil côté serveur (pour les push).
  /// Best-effort : n'échoue jamais bruyamment.
  static Future<void> registerPushToken(String fcmToken) async {
    try {
      if (fcmToken.isEmpty) return;
      if (await getToken() == null) return; // pas connecté → inutile
      await http.post(
        Uri.parse('${AppConfig.api}/api/notifications/token'),
        headers: await _headers(auth: true),
        body: jsonEncode({'token': fcmToken}),
      );
    } catch (_) { /* ignoré */ }
  }

  /// S'envoie une notification de test et renvoie le diagnostic du serveur.
  static Future<Map<String, dynamic>> testPush() async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.api}/api/notifications/test'),
        headers: await _headers(auth: true),
      );
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur : $e'};
    }
  }

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

  static Future<Map<String, dynamic>> getVideos({int page = 1, String? exclude}) async {
    final ex = (exclude != null && exclude.isNotEmpty)
        ? '&exclude=${Uri.encodeQueryComponent(exclude)}'
        : '';
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/videos?page=$page&limit=20$ex'),
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
    String? filter, // filtre couleur (métadonnée, ré-appliqué à la lecture)
    String? overlays, // JSON des textes/emojis posés sur la vidéo
    String? soundId, // "Utiliser ce son" : son réutilisé
    String? duetSourceId, // Duo : vidéo source à composer côte à côte
    String? stitchSourceId, // Stitch : vidéo source à enchaîner
    double? trimStart, // Découpe : début (secondes) — le serveur coupe la vidéo
    double? trimEnd, // Découpe : fin (secondes)
    String? musicSoundId, // Musique ajoutée : son mixé sur la vidéo côté serveur
    void Function(String)? onStatus,
    void Function(int percent)? onProgress,
  }) async {
    try {
      // ── Compression (réduit fortement la taille → upload plus rapide) ──
      String uploadPath = filePath;
      try {
        onStatus?.call('Compression de la vidéo...');
        // 480p : fichiers ~2-3x plus légers → chargement rapide et petite
        // consommation de données pour tous les spectateurs.
        final info = await VideoCompress.compressVideo(
          filePath,
          quality: VideoQuality.Res640x480Quality,
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info != null && info.path != null && info.path!.isNotEmpty) {
          uploadPath = info.path!;
        }
      } catch (_) {
        uploadPath = filePath;
      }

      // ── Miniature : image affichée INSTANTANÉMENT dans le fil pendant que
      // la vidéo charge (comme TikTok) → sensation de rapidité immédiate.
      String? thumbPath;
      try {
        onStatus?.call('Création de la miniature...');
        thumbPath = await VideoThumbnail.thumbnailFile(
          video: uploadPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 70,
        );
      } catch (_) { /* sans miniature : pas bloquant */ }

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
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        if (overlays != null && overlays.isNotEmpty) 'overlays': overlays,
        if (soundId != null && soundId.isNotEmpty) 'sound_id': soundId,
        if (duetSourceId != null && duetSourceId.isNotEmpty) 'duet_source_id': duetSourceId,
        if (stitchSourceId != null && stitchSourceId.isNotEmpty) 'stitch_source_id': stitchSourceId,
        if (trimStart != null && trimStart > 0) 'trim_start': trimStart.toStringAsFixed(2),
        if (trimEnd != null && trimEnd > 0) 'trim_end': trimEnd.toStringAsFixed(2),
        if (musicSoundId != null && musicSoundId.isNotEmpty) 'music_sound_id': musicSoundId,
        'video': await MultipartFile.fromFile(uploadPath, filename: 'video.mp4'),
        if (thumbPath != null)
          'thumbnail': await MultipartFile.fromFile(thumbPath, filename: 'thumb.jpg'),
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

  /// Signale une vidéo à la modération (exigence Google Play).
  /// [reason] : nudite | violence | haine | arnaque | spam | mineur | autre
  static Future<Map<String, dynamic>> reportVideo(String videoId, String reason) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/videos/$videoId/report'),
      headers: await _headers(auth: true),
      body: jsonEncode({'reason': reason}),
    );
    return jsonDecode(res.body);
  }

  /// Bloque un utilisateur : ses vidéos disparaissent du fil.
  static Future<Map<String, dynamic>> blockUser(String userId) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/users/$userId/block'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  /// Suppression DÉFINITIVE du compte (exigence Google Play).
  static Future<Map<String, dynamic>> deleteAccount() async {
    final res = await http.delete(
      Uri.parse('${AppConfig.api}/api/users/me'),
      headers: await _headers(auth: true),
    );
    final data = jsonDecode(res.body);
    if (data['success'] == true) await clearToken();
    return data;
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

  /// Assistant IA : envoie un message + l'historique récent, renvoie la réponse.
  static Future<String> aiChat(String message,
      {List<Map<String, String>> history = const []}) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.api}/api/ai/chat'),
        headers: await _headers(auth: true),
        body: jsonEncode({'message': message, 'history': history}),
      );
      final data = jsonDecode(res.body);
      return (data['reply'] ?? "Je n'ai pas pu répondre.").toString();
    } catch (_) {
      return "Connexion impossible. Réessaie.";
    }
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
    String? liveId,
    int? coins,
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
        if (liveId != null) 'liveId': liveId,
        if (coins != null) 'coins': coins,
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
  /// Envoie les photos de la pièce d'identité (recto + verso) au serveur.
  /// [frontPath] est obligatoire, [backPath] recommandé.
  static Future<Map<String, dynamic>> submitKyc({
    required String frontPath,
    String? backPath,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Non connecté — reconnecte-toi'};
      }
      final form = FormData.fromMap({
        'front': await MultipartFile.fromFile(frontPath, filename: 'front.jpg'),
        if (backPath != null)
          'back': await MultipartFile.fromFile(backPath, filename: 'back.jpg'),
      });
      final dio = Dio();
      final res = await dio.post(
        '${AppConfig.api}/api/dark/kyc/submit',
        data: form,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (_) => true,
        ),
      );
      final body = res.data;
      if (body is Map) return Map<String, dynamic>.from(body);
      return {'success': false, 'message': 'Réponse serveur invalide'};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] : null) ?? e.message ?? 'Erreur réseau';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
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
    String? fullName,
    String? birthDate, // AAAA-MM-JJ
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
        if (fullName != null) 'fullName': fullName,
        if (birthDate != null) 'birthDate': birthDate,
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
  static Future<Map<String, dynamic>> startLive(String title, {int price = 0}) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/live/start'),
      headers: await _headers(auth: true),
      body: jsonEncode({'title': title, 'price': price}),
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

  // ── Cadeaux / pièces ──────────────────────────────────────────────────────

  /// Catalogue des stickers + paquets de pièces + mon solde
  static Future<Map<String, dynamic>> getGiftCatalog() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/gifts/catalog'),
        headers: await _headers(auth: true),
      );
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      return {'gifts': [], 'packs': [], 'coin_balance': 0};
    }
  }

  /// Envoie un tip (soutien) payé en pièces → { success, coin_balance, code? }
  static Future<Map<String, dynamic>> sendTip({
    required String creatorId,
    required int coins,
    String? videoId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.api}/api/gifts/tip'),
        headers: await _headers(auth: true),
        body: jsonEncode({
          'creatorId': creatorId,
          'coins': coins,
          if (videoId != null) 'videoId': videoId,
        }),
      );
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<int> getCoinBalance() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/gifts/balance'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['coin_balance'] is num) ? (data['coin_balance'] as num).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Messagerie (REST ; le temps réel passe par ChatService/WebSocket) ──────

  /// Liste de mes conversations → [{id, otherUser:{id,username,avatar_url}, updatedAt}]
  static Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/chat/conversations'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['conversations'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Nombre total de messages non lus (badge sur l'icône Messages du fil)
  static Future<int> getUnreadMessages() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/chat/unread'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Ouvre (ou crée) une conversation avec un utilisateur → {conversationId, otherUser}
  static Future<Map<String, dynamic>> openConversation(String userId) async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/chat/conversations/$userId'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  /// Messages d'une conversation (ordre chronologique)
  static Future<List<Map<String, dynamic>>> getChatMessages(String cid, {int page = 1}) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/chat/messages/$cid?page=$page&limit=50'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['messages'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Envoi d'un message par REST (repli si le WebSocket n'est pas connecté)
  static Future<Map<String, dynamic>> sendChatMessage(String cid, String content) async {
    final res = await http.post(
      Uri.parse('${AppConfig.api}/api/chat/messages/$cid'),
      headers: await _headers(auth: true),
      body: jsonEncode({'content': content, 'message_type': 'text'}),
    );
    return jsonDecode(res.body);
  }

  // ── Statistiques créateur ─────────────────────────────────────────────────

  /// Tableau de bord chiffré du créateur connecté → { ...stats }
  static Future<Map<String, dynamic>> getCreatorStats() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/users/me/stats'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      if (data['stats'] is Map) return Map<String, dynamic>.from(data['stats']);
      return {};
    } catch (_) {
      return {};
    }
  }

  // ── Recherche & découverte ────────────────────────────────────────────────

  /// Recherche de vidéos par titre ou hashtag
  static Future<List<Map<String, dynamic>>> searchVideos(String q) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/videos/search?q=${Uri.encodeQueryComponent(q)}'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['videos'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Recherche de créateurs par pseudo
  static Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/users/search?q=${Uri.encodeQueryComponent(q)}'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['users'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Vidéos en tendance (les plus vues)
  static Future<List<Map<String, dynamic>>> getTrending() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/videos/trending'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['videos'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Hashtags populaires avec compteur → [{tag, count}] (page Découverte)
  static Future<List<Map<String, dynamic>>> getTrendingTags() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/videos/popular-tags'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['tags'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  /// Mes notifications → {unread, notifications: [...]}
  static Future<Map<String, dynamic>> getNotifications() async {
    final res = await http.get(
      Uri.parse('${AppConfig.api}/api/notifications'),
      headers: await _headers(auth: true),
    );
    return jsonDecode(res.body);
  }

  /// Juste le compteur de non-lues (pour le badge)
  static Future<int> getUnreadCount() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/notifications/unread'),
        headers: await _headers(auth: true),
      );
      final data = jsonDecode(res.body);
      return (data['unread'] is num) ? (data['unread'] as num).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Marque des notifications comme lues (toutes si ids == null)
  static Future<void> markNotificationsRead({List<String>? ids}) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.api}/api/notifications/read'),
        headers: await _headers(auth: true),
        body: jsonEncode({if (ids != null) 'ids': ids}),
      );
    } catch (_) {}
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

}
