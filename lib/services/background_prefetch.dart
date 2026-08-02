import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/app_config.dart';
import 'video_cache.dart';

/// Pré-téléchargement de vidéos EN ARRIÈRE-PLAN (appli fermée).
///
/// Réalité mobile : Android ne laisse tourner qu'une tâche COURTE et
/// OCCASIONNELLE (le système décide quand, ~toutes les 2 h au mieux). iOS est
/// quasi inutilisable pour ça. On télécharge donc « quelques vidéos quand c'est
/// possible » — best-effort. La tâche utilise n'importe quelle connexion
/// (Wi-Fi OU données mobiles), et privilégie la version légère (480p) pour
/// limiter la consommation.
const String _kTaskName = 'bp_prefetch';
const String _kUniqueName = 'bp_prefetch_periodic';

/// Point d'entrée de l'isolat d'arrière-plan (doit être top-level + annoté).
@pragma('vm:entry-point')
void prefetchCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _runPrefetch();
    } catch (_) { /* jamais bloquant */ }
    return true;
  });
}

/// Récupère quelques vidéos du fil et les met en cache disque.
Future<void> _runPrefetch() async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'auth_token');
  if (token == null || token.isEmpty) return; // pas connecté → rien à faire

  final res = await http.get(
    Uri.parse('${AppConfig.api}/api/videos?page=1&limit=10'),
    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
  ).timeout(const Duration(seconds: 30));

  final data = jsonDecode(res.body);
  final List list = (data['videos'] ?? data['data'] ?? []) as List;

  int done = 0;
  for (final v in list) {
    if (done >= 5) break; // au plus ~5 vidéos (batterie + données)
    if (v is! Map) continue;
    // Version légère (480p) si dispo, sinon l'originale.
    final light = (v['hls_url'] ?? '').toString();
    final full = (v['video_url'] ?? '').toString();
    final raw = light.isNotEmpty ? light : full;
    if (raw.isEmpty) continue;
    await VideoCache.ensureCached(AppConfig.cdn(raw));
    done++;
  }
}

class BackgroundPrefetch {
  /// Active la tâche périodique. À appeler au démarrage si le réglage est ON.
  static Future<void> enable() async {
    try {
      await Workmanager().initialize(prefetchCallbackDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        _kUniqueName,
        _kTaskName,
        frequency: const Duration(hours: 2),
        // networkConnected = Wi-Fi OU données mobiles (comme demandé).
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
      );
    } catch (_) { /* plateforme non supportée : ignoré */ }
  }

  /// Désactive la tâche (si l'utilisateur coupe le réglage).
  static Future<void> disable() async {
    try { await Workmanager().cancelByUniqueName(_kUniqueName); } catch (_) {}
  }
}
