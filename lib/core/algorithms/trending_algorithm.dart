/// Algorithme Trending (Tendances) BeninPlay
///
/// Calcule ce qui est "en tendance" au Bénin en ce moment
/// Score trending = vitesse de croissance de l'engagement, pas le total

class TrendingAlgorithm {
  // ─── Score trending d'une vidéo ─────────────────────────────────────────
  /// Formule : (engagements des 2 dernières heures) / (âge en heures + 2)
  /// Source : inspiré de l'algorithme Hacker News (decay formula)
  static double trendingScore({
    required int recentLikes,      // likes des 2 dernières heures
    required int recentComments,   // commentaires des 2 dernières heures
    required int recentShares,     // partages des 2 dernières heures
    required int recentViews,      // vues des 2 dernières heures
    required Duration videoAge,    // âge de la vidéo
    required bool isBeninContent,  // bonus local
  }) {
    // Engagement récent pondéré
    final recentEngagement =
        (recentLikes * 1.0) +
        (recentComments * 4.0) +
        (recentShares * 7.0) +
        (recentViews * 0.1);

    // Decay temporel : diviser par (âge + 2)^1.5 pour favoriser le récent
    final ageHours = videoAge.inHours.toDouble() + 2;
    final decay = ageHours == 0 ? 1.0 : (ageHours * ageHours * ageHours);

    double score = recentEngagement / decay;

    // Bonus contenu béninois (+20%)
    if (isBeninContent) score *= 1.2;

    return score;
  }

  // ─── Hashtags tendance ──────────────────────────────────────────────────
  static List<TrendingHashtag> rankHashtags(List<HashtagData> hashtags) {
    // Calculer le score de chaque hashtag
    final scored = hashtags.map((h) {
      final growthRate = h.postsLast2h / (h.postsLast24h + 1);
      final score = growthRate * h.postsLast2h;
      return TrendingHashtag(
        tag: h.tag,
        totalPosts: h.totalPosts,
        postsLast24h: h.postsLast24h,
        growthPercent: (growthRate * 100).round(),
        score: score,
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(20).toList();
  }

  // ─── Créateurs en montée ────────────────────────────────────────────────
  static List<RisingCreator> findRisingCreators(List<CreatorGrowthData> creators) {
    return creators
        .where((c) {
          // Critères pour être "en montée" :
          final weekGrowthRate = c.followersGainedThisWeek / (c.totalFollowers + 1);
          return weekGrowthRate > 0.10 && // +10% de followers cette semaine
              c.totalFollowers < 100000;   // pas encore mega-star
        })
        .map((c) => RisingCreator(
              creatorId: c.creatorId,
              name: c.name,
              followersGainedThisWeek: c.followersGainedThisWeek,
              totalFollowers: c.totalFollowers,
              growthPercent: ((c.followersGainedThisWeek / (c.totalFollowers + 1)) * 100).round(),
            ))
        .toList()
      ..sort((a, b) => b.growthPercent.compareTo(a.growthPercent));
  }

  // ─── Données trending préchargées pour l'app ────────────────────────────
  static List<Map<String, dynamic>> get beninTrends => [
    {'tag': '#DanceBénin',       'posts': '2.4K', 'trend': '+340%', 'hot': true},
    {'tag': '#CuisineBéninoise', 'posts': '1.8K', 'trend': '+210%', 'hot': true},
    {'tag': '#HumourBénin',      'posts': '3.1K', 'trend': '+180%', 'hot': false},
    {'tag': '#BeninPlay',        'posts': '5.2K', 'trend': '+520%', 'hot': true},
    {'tag': '#CotoviVibes',      'posts': '890',  'trend': '+95%',  'hot': false},
    {'tag': '#VodounVibes',      'posts': '420',  'trend': '+67%',  'hot': false},
    {'tag': '#MusiqueAfro',      'posts': '1.2K', 'trend': '+140%', 'hot': false},
    {'tag': '#BeninFashion',     'posts': '670',  'trend': '+88%',  'hot': false},
  ];
}

// ─── Modèles ─────────────────────────────────────────────────────────────────

class HashtagData {
  final String tag;
  final int totalPosts;
  final int postsLast24h;
  final int postsLast2h;

  const HashtagData({
    required this.tag,
    required this.totalPosts,
    required this.postsLast24h,
    required this.postsLast2h,
  });
}

class TrendingHashtag {
  final String tag;
  final int totalPosts;
  final int postsLast24h;
  final int growthPercent;
  final double score;

  const TrendingHashtag({
    required this.tag,
    required this.totalPosts,
    required this.postsLast24h,
    required this.growthPercent,
    required this.score,
  });
}

class CreatorGrowthData {
  final String creatorId;
  final String name;
  final int totalFollowers;
  final int followersGainedThisWeek;

  const CreatorGrowthData({
    required this.creatorId,
    required this.name,
    required this.totalFollowers,
    required this.followersGainedThisWeek,
  });
}

class RisingCreator {
  final String creatorId;
  final String name;
  final int totalFollowers;
  final int followersGainedThisWeek;
  final int growthPercent;

  const RisingCreator({
    required this.creatorId,
    required this.name,
    required this.totalFollowers,
    required this.followersGainedThisWeek,
    required this.growthPercent,
  });
}
