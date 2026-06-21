/// Service Live BeninPlay — Agora.io
///
/// Clé API Agora à renseigner : https://console.agora.io
/// Package Flutter : agora_rtc_engine ^6.3.2

// ─── CONFIGURATION AGORA ─────────────────────────────────────────────────────
// 1. Créer un compte sur https://console.agora.io (gratuit)
// 2. Créer un projet → copier l'App ID ci-dessous
// 3. Désactiver "App Certificate" en développement (activer en prod)

class AgoraConfig {
  static const String appId = 'VOTRE_AGORA_APP_ID_ICI';
  // Token optionnel (laisser vide si App Certificate désactivé)
  static const String? token = null;
}

// ─── Modèle d'un Live ────────────────────────────────────────────────────────

class LiveStream {
  final String id;
  final String hostId;
  final String hostName;
  final String hostInitial;
  final String title;
  final int viewers;
  final bool isLive;
  final DateTime startedAt;

  const LiveStream({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.hostInitial,
    required this.title,
    required this.viewers,
    this.isLive = true,
    required this.startedAt,
  });
}

// ─── Mock data pour la demo ───────────────────────────────────────────────────

class LiveService {
  static List<LiveStream> get activeLives => [
    LiveStream(
      id: 'live_akossi',
      hostId: 'user_akossi',
      hostName: 'Akossi TV',
      hostInitial: 'A',
      title: '🎵 Session musicale en direct !',
      viewers: 342,
      startedAt: DateTime.now().subtract(const Duration(minutes: 23)),
    ),
    LiveStream(
      id: 'live_cotonou',
      hostId: 'user_cotonou',
      hostName: 'Cotonou Vibes',
      hostInitial: 'C',
      title: '🍳 Cuisine béninoise : recette d\'Amiwo',
      viewers: 128,
      startedAt: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    LiveStream(
      id: 'live_djkofi',
      hostId: 'user_djkofi',
      hostName: 'DjKofi',
      hostInitial: 'D',
      title: '🎧 Mix Afrobeats + Coupé-Décalé',
      viewers: 891,
      startedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 12)),
    ),
  ];

  // Générer un channel name unique pour un live
  static String generateChannel(String userId) =>
      'beninplay_live_${userId}_${DateTime.now().millisecondsSinceEpoch}';
}
