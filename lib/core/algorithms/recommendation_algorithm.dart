/// Algorithme de recommandation "Pour Toi" — BeninPlay
/// Inspiré de TikTok FYP mais adapté au contexte béninois
///
/// Score final = (engagement * 0.40) + (completion * 0.25) +
///               (freshness * 0.15) + (affinity * 0.12) + (local * 0.08)

class RecommendationAlgorithm {
  // ─── Poids des signaux ───────────────────────────────────────────────────
  static const double _wEngagement = 0.40; // likes, comments, shares
  static const double _wCompletion = 0.25; // % de la vidéo regardée
  static const double _wFreshness = 0.15;  // récence de la vidéo
  static const double _wAffinity = 0.12;  // affinité créateur/utilisateur
  static const double _wLocal = 0.08;     // contenu local béninois

  // ─── Score d'engagement ─────────────────────────────────────────────────
  static double engagementScore({
    required int likes,
    required int comments,
    required int shares,
    required int views,
  }) {
    if (views == 0) return 0;
    // Taux d'engagement = (likes*1 + comments*3 + shares*5) / views
    // Les commentaires et partages valent plus que les likes
    final weighted = (likes * 1.0) + (comments * 3.0) + (shares * 5.0);
    final rate = weighted / views;
    // Normaliser entre 0 et 1 (cap à 20% d'engagement = score max)
    return (rate / 0.20).clamp(0.0, 1.0);
  }

  // ─── Score de complétion ─────────────────────────────────────────────────
  static double completionScore(double watchedPercent) {
    // Regarder >80% = score max
    // Regarder <10% = pénalité forte (contenu pas intéressant)
    if (watchedPercent >= 0.8) return 1.0;
    if (watchedPercent <= 0.1) return 0.0;
    return watchedPercent / 0.8;
  }

  // ─── Score de fraîcheur ──────────────────────────────────────────────────
  static double freshnessScore(DateTime publishedAt) {
    final age = DateTime.now().difference(publishedAt);
    // Décroissance exponentielle :
    // < 1h   = 1.0
    // 1-24h  = 0.8
    // 1-3j   = 0.5
    // 3-7j   = 0.3
    // > 7j   = 0.1
    if (age.inHours < 1) return 1.0;
    if (age.inHours < 24) return 0.8;
    if (age.inDays < 3) return 0.5;
    if (age.inDays < 7) return 0.3;
    return 0.1;
  }

  // ─── Score d'affinité créateur ──────────────────────────────────────────
  static double affinityScore({
    required bool isFollowing,
    required int previousWatchCount, // combien de vidéos du créateur l'user a regardé
    required double avgWatchPercent, // % moyen regardé chez ce créateur
  }) {
    double score = 0.0;
    if (isFollowing) score += 0.5;
    // Bonus si l'utilisateur regarde souvent ce créateur
    score += (previousWatchCount.clamp(0, 10) / 10) * 0.3;
    // Bonus si l'utilisateur finit les vidéos du créateur
    score += avgWatchPercent * 0.2;
    return score.clamp(0.0, 1.0);
  }

  // ─── Score local (Bénin) ─────────────────────────────────────────────────
  static double localScore({
    required bool isBeninCreator,
    required bool hasLocalHashtag, // #Bénin, #Cotonou, #BeninPlay etc.
    required String userCountry,
    required String creatorCountry,
  }) {
    double score = 0.0;
    if (userCountry == creatorCountry) score += 0.5;    // même pays
    if (isBeninCreator) score += 0.3;                   // créateur béninois
    if (hasLocalHashtag) score += 0.2;                  // hashtag local
    return score.clamp(0.0, 1.0);
  }

  // ─── Score final ────────────────────────────────────────────────────────
  static double finalScore(VideoSignals signals) {
    final engagement = engagementScore(
      likes: signals.likes,
      comments: signals.comments,
      shares: signals.shares,
      views: signals.views,
    );
    final completion = completionScore(signals.avgWatchPercent);
    final freshness = freshnessScore(signals.publishedAt);
    final affinity = affinityScore(
      isFollowing: signals.isFollowing,
      previousWatchCount: signals.previousWatchCount,
      avgWatchPercent: signals.creatorAvgWatchPercent,
    );
    final local = localScore(
      isBeninCreator: signals.isBeninCreator,
      hasLocalHashtag: signals.hasLocalHashtag,
      userCountry: signals.userCountry,
      creatorCountry: signals.creatorCountry,
    );

    return (engagement * _wEngagement) +
        (completion * _wCompletion) +
        (freshness * _wFreshness) +
        (affinity * _wAffinity) +
        (local * _wLocal);
  }

  // ─── Trier un feed ──────────────────────────────────────────────────────
  static List<VideoSignals> rankFeed(List<VideoSignals> videos) {
    // Calculer le score de chaque vidéo
    final scored = videos.map((v) => (video: v, score: finalScore(v))).toList();
    // Trier par score décroissant
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Injection de diversité : toutes les 5 vidéos, insérer une vidéo
    // d'un créateur que l'utilisateur n'a jamais vu (découverte)
    final ranked = <VideoSignals>[];
    for (int i = 0; i < scored.length; i++) {
      ranked.add(scored[i].video);
      if ((i + 1) % 5 == 0 && i + 1 < scored.length) {
        // Trouver une vidéo "découverte" (créateur non suivi)
        final discovery = scored.firstWhere(
          (s) => !s.video.isFollowing && !ranked.contains(s.video),
          orElse: () => scored[i],
        );
        if (!ranked.contains(discovery.video)) {
          ranked.add(discovery.video);
        }
      }
    }
    return ranked;
  }
}

/// Données d'entrée pour l'algorithme
class VideoSignals {
  final String videoId;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final double avgWatchPercent;    // 0.0 à 1.0
  final DateTime publishedAt;
  final bool isFollowing;
  final int previousWatchCount;
  final double creatorAvgWatchPercent;
  final bool isBeninCreator;
  final bool hasLocalHashtag;
  final String userCountry;
  final String creatorCountry;

  const VideoSignals({
    required this.videoId,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.views,
    required this.avgWatchPercent,
    required this.publishedAt,
    this.isFollowing = false,
    this.previousWatchCount = 0,
    this.creatorAvgWatchPercent = 0.5,
    this.isBeninCreator = false,
    this.hasLocalHashtag = false,
    this.userCountry = 'BJ',
    this.creatorCountry = 'BJ',
  });
}
