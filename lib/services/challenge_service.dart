import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/api_service.dart';

/// Une ligne du classement d'un défi.
class ChallengeEntry {
  final String creatorId;
  final String creatorName;
  final String? thumbnailUrl;
  final int likes;
  final int views;
  final int? rank;
  final int? prize;

  ChallengeEntry({
    required this.creatorId,
    required this.creatorName,
    this.thumbnailUrl,
    this.likes = 0,
    this.views = 0,
    this.rank,
    this.prize,
  });

  factory ChallengeEntry.fromJson(Map<String, dynamic> j) => ChallengeEntry(
        creatorId: (j['creator_id'] ?? '').toString(),
        creatorName: (j['creator_name'] ?? 'Créateur').toString(),
        thumbnailUrl: j['thumbnail_url']?.toString(),
        likes: (j['likes'] is num) ? (j['likes'] as num).toInt() : 0,
        views: (j['views'] is num) ? (j['views'] as num).toInt() : 0,
        rank: (j['rank'] is num) ? (j['rank'] as num).toInt() : null,
        prize: (j['prize'] is num) ? (j['prize'] as num).toInt() : null,
      );
}

/// Un Défi à Cagnotte (concours hashtag avec prix réels en FCFA).
class Challenge {
  final String id;
  final String hashtag;
  final String title;
  final String? description;
  final int prizePool;
  final DateTime endsAt;
  final String status;
  final List<ChallengeEntry> leaderboard;
  final List<ChallengeEntry> winners;

  Challenge({
    required this.id,
    required this.hashtag,
    required this.title,
    this.description,
    required this.prizePool,
    required this.endsAt,
    required this.status,
    this.leaderboard = const [],
    this.winners = const [],
  });

  Duration get remaining => endsAt.difference(DateTime.now());

  /// « 2 j 5 h » / « 3 h 12 min » / « Terminé »
  String get remainingLabel {
    final r = remaining;
    if (r.isNegative) return 'Terminé';
    if (r.inDays > 0) return '${r.inDays} j ${r.inHours % 24} h';
    if (r.inHours > 0) return '${r.inHours} h ${r.inMinutes % 60} min';
    return '${r.inMinutes} min';
  }

  static List<ChallengeEntry> _entries(dynamic raw) => ((raw as List?) ?? [])
      .whereType<Map>()
      .map((e) => ChallengeEntry.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: (j['id'] ?? '').toString(),
        hashtag: (j['hashtag'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: j['description']?.toString(),
        prizePool: (j['prize_pool'] is num) ? (j['prize_pool'] as num).toInt() : 0,
        endsAt: DateTime.tryParse(j['ends_at'] ?? '') ?? DateTime.now(),
        status: (j['status'] ?? 'active').toString(),
        leaderboard: _entries(j['leaderboard']),
        winners: _entries(j['winners']),
      );
}

class ChallengeService {
  /// Défis actifs (avec top 10) + derniers terminés (avec gagnants).
  static Future<({List<Challenge> active, List<Challenge> finished})> getAll() async {
    try {
      final token = await ApiService.getToken();
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/challenges'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      List<Challenge> parse(dynamic l) => ((l as List?) ?? [])
          .whereType<Map>()
          .map((e) => Challenge.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return (active: parse(data['active']), finished: parse(data['finished']));
    } catch (_) {
      return (active: <Challenge>[], finished: <Challenge>[]);
    }
  }

  /// Détail d'un défi + classement complet.
  static Future<Challenge?> get(String id) async {
    try {
      final token = await ApiService.getToken();
      final res = await http.get(
        Uri.parse('${AppConfig.api}/api/challenges/$id'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      if (data['challenge'] == null) return null;
      final ch = Map<String, dynamic>.from(data['challenge']);
      ch['leaderboard'] = data['leaderboard'];
      return Challenge.fromJson(ch);
    } catch (_) {
      return null;
    }
  }
}
