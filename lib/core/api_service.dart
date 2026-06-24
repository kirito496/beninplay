import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() => _storage.read(key: 'auth_token');
  static Future<void> saveToken(String t) => _storage.write(key: 'auth_token', value: t);
  static Future<void> clearToken() => _storage.delete(key: 'auth_token');

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) { final t = await getToken(); if (t != null) h['Authorization'] = 'Bearer $t'; }
    return h;
  }

  static String? _decodeUserId(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var p = parts[1];
      p += '=' * ((4 - p.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(p));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['userId']?.toString();
    } catch (_) { return null; }
  }

  static Future<String?> getCurrentUserId() async {
    final t = await getToken();
    return t == null ? null : _decodeUserId(t);
  }

  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await http.post(Uri.parse('${AppConfig.api}/api/auth/send-otp'), headers: await _headers(), body: jsonEncode({'phone': phone}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final res = await http.post(Uri.parse('${AppConfig.api}/api/auth/verify-otp'), headers: await _headers(), body: jsonEncode({'phone': phone, 'code': code}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] == true && data['token'] != null) await saveToken(data['token'] as String);
    return data;
  }

  static Future<Map<String, dynamic>> getVideos({int page = 1}) async {
    final res = await http.get(Uri.parse('${AppConfig.api}/api/videos?page=$page&limit=20'), headers: await _headers(auth: true));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> uploadVideo({required String filePath, required String title, String? description, String zone = 'normal', List<String> tags = const []}) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final ext = filePath.split('.').last.toLowerCase();
      final mime = ext == 'mp4' ? 'video/mp4' : ext == 'mov' ? 'video/quicktime' : 'video/mp4';
      final userId = await getCurrentUserId() ?? 'unknown';
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final sb = Supabase.instance.client;
      await sb.storage.from(AppConfig.storageBucket).uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
      final url = sb.storage.from(AppConfig.storageBucket).getPublicUrl(fileName);
      final res = await http.post(Uri.parse('${AppConfig.api}/api/videos/register'), headers: await _headers(auth: true), body: jsonEncode({'title': title, 'video_url': url, 'description': description ?? '', 'zone': zone, 'tags': tags}));
      return jsonDecode(res.body);
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  static Future<Map<String, dynamic>> likeVideo(String id) async {
    final res = await http.post(Uri.parse('${AppConfig.api}/api/videos/$id/like'), headers: await _headers(auth: true));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addComment(String id, String content) async {
    final res = await http.post(Uri.parse('${AppConfig.api}/api/videos/$id/comment'), headers: await _headers(auth: true), body: jsonEncode({'content': content}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createBoost({required String videoId, required int budget, required String objective, required bool nationwide, required List<String> regions, required List<String> hashtags, required List<int> targetHours, required int ageMin, required int ageMax, required String gender}) async {
    try {
      final res = await http.post(Uri.parse('${AppConfig.api}/api/boost'), headers: await _headers(auth: true), body: jsonEncode({'video_id': videoId, 'budget': budget, 'objective': objective, 'nationwide': nationwide, 'regions': regions, 'hashtags': hashtags, 'target_hours': targetHours, 'age_min': ageMin, 'age_max': ageMax, 'gender': gender}));
      return jsonDecode(res.body);
    } catch (e) { return {'success': false, 'error': e.toString()}; }
  }
}