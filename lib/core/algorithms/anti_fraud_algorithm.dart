/// Algorithme anti-fraude BeninPlay
///
/// Protège contre :
/// 1. Faux comptes (bots)
/// 2. Fausses vues / faux likes
/// 3. Fraude aux paiements (chargeback Mobile Money)
/// 4. Multi-comptes (même téléphone = plusieurs comptes)
/// 5. VPN / simulateur pour contourner les règles

class AntiFraudAlgorithm {
  // ─── Score de confiance utilisateur (0 = suspect, 100 = fiable) ─────────
  static int trustScore(UserBehavior behavior) {
    int score = 50; // score de base

    // ── Signaux positifs (augmentent la confiance) ──────────────────────
    // Compte ancien
    final accountAge = DateTime.now().difference(behavior.createdAt).inDays;
    if (accountAge > 90) score += 15;
    else if (accountAge > 30) score += 8;
    else if (accountAge > 7) score += 3;

    // Numéro vérifié
    if (behavior.phoneVerified) score += 10;

    // KYC approuvé
    if (behavior.kycApproved) score += 20;

    // Comportement normal de visionnage
    if (behavior.avgSessionDuration > const Duration(minutes: 3)) score += 5;
    if (behavior.videosWatchedToday < 200) score += 5;

    // Transactions légitimes passées
    score += (behavior.successfulTransactions * 2).clamp(0, 10);

    // ── Signaux négatifs (diminuent la confiance) ──────────────────────
    // Trop de vues en peu de temps (bot)
    if (behavior.videosWatchedToday > 500) score -= 30;
    else if (behavior.videosWatchedToday > 300) score -= 15;

    // Likes trop rapides (bot de likes)
    if (behavior.likesPerMinute > 10) score -= 25;

    // Même IP que beaucoup d'autres comptes
    if (behavior.accountsOnSameIp > 5) score -= 20;
    else if (behavior.accountsOnSameIp > 2) score -= 8;

    // VPN détecté
    if (behavior.vpnDetected) score -= 15;

    // Simulateur Android détecté
    if (behavior.isEmulator) score -= 30;

    // Chargeback Mobile Money
    score -= behavior.chargebacks * 20;

    // Signalements reçus
    score -= (behavior.reportsReceived * 5).clamp(0, 25);

    return score.clamp(0, 100);
  }

  // ─── Détecter une vue frauduleuse ──────────────────────────────────────
  static ViewFraudResult analyzeView(ViewEvent event) {
    final issues = <String>[];

    // Règle 1 : Même device, même vidéo, < 30 secondes d'intervalle
    if (event.timeSinceLastViewOnSameVideo < const Duration(seconds: 30)) {
      issues.add('vue_trop_rapide');
    }

    // Règle 2 : Trop de vues par device aujourd'hui
    if (event.viewsFromDeviceToday > 300) {
      issues.add('trop_de_vues_device');
    }

    // Règle 3 : Durée de vue anormalement courte (< 2 secondes = scroll bot)
    if (event.viewDuration < const Duration(seconds: 2)) {
      issues.add('vue_trop_courte');
    }

    // Règle 4 : Même IP = trop de vues différents comptes
    if (event.viewsFromIpToday > 100) {
      issues.add('ip_suspect');
    }

    // Règle 5 : Pattern bot (vues exactement toutes les X secondes)
    if (event.isRegularPattern) {
      issues.add('pattern_bot');
    }

    return ViewFraudResult(
      isFraudulent: issues.isNotEmpty,
      issues: issues,
      shouldBlock: issues.length >= 2,
      severity: issues.length >= 3 ? FraudSeverity.high
          : issues.length >= 1 ? FraudSeverity.medium
          : FraudSeverity.none,
    );
  }

  // ─── Détecter une fraude de paiement ───────────────────────────────────
  static PaymentFraudResult analyzePayment(PaymentEvent payment) {
    final issues = <String>[];

    // Règle 1 : Premier paiement dans les 24h de la création du compte
    final accountAge = DateTime.now().difference(payment.accountCreatedAt);
    if (accountAge.inHours < 24) {
      issues.add('compte_trop_recent');
    }

    // Règle 2 : Montant inhabituel (> 5x le montant moyen de l'utilisateur)
    if (payment.userAvgAmount > 0 &&
        payment.amount > payment.userAvgAmount * 5) {
      issues.add('montant_anormal');
    }

    // Règle 3 : Trop de paiements en peu de temps
    if (payment.paymentsLast24h > 10) {
      issues.add('trop_de_paiements');
    }

    // Règle 4 : Numéro MoMo utilisé sur plusieurs comptes
    if (payment.momoNumberLinkedAccounts > 1) {
      issues.add('momo_multi_comptes');
    }

    // Règle 5 : Trust score trop bas
    if (payment.userTrustScore < 30) {
      issues.add('trust_score_bas');
    }

    final shouldBlock = issues.contains('momo_multi_comptes') ||
        issues.length >= 3 ||
        payment.userTrustScore < 20;

    return PaymentFraudResult(
      isSuspicious: issues.isNotEmpty,
      shouldBlock: shouldBlock,
      issues: issues,
      requiresManualReview: issues.length == 1 || issues.length == 2,
    );
  }

  // ─── Limites de taux par trust score ───────────────────────────────────
  static RateLimits getRateLimits(int trustScore) {
    if (trustScore >= 80) {
      return const RateLimits(
        maxViewsPerDay: 500,
        maxLikesPerDay: 300,
        maxCommentsPerDay: 100,
        maxWithdrawPerDay: 50000,
        requireOtpForWithdraw: false,
      );
    } else if (trustScore >= 50) {
      return const RateLimits(
        maxViewsPerDay: 300,
        maxLikesPerDay: 150,
        maxCommentsPerDay: 50,
        maxWithdrawPerDay: 20000,
        requireOtpForWithdraw: true,
      );
    } else if (trustScore >= 30) {
      return const RateLimits(
        maxViewsPerDay: 100,
        maxLikesPerDay: 50,
        maxCommentsPerDay: 20,
        maxWithdrawPerDay: 5000,
        requireOtpForWithdraw: true,
      );
    } else {
      // Compte suspect — lecture seule
      return const RateLimits(
        maxViewsPerDay: 50,
        maxLikesPerDay: 10,
        maxCommentsPerDay: 5,
        maxWithdrawPerDay: 0, // Bloqué
        requireOtpForWithdraw: true,
      );
    }
  }

  // ─── Détecter les multi-comptes ────────────────────────────────────────
  static bool isMultiAccount({
    required String deviceId,
    required String phoneNumber,
    required List<String> knownDeviceIds,
    required List<String> knownPhoneNumbers,
  }) {
    // Même device = même personne
    if (knownDeviceIds.contains(deviceId)) return true;
    // Même numéro = même personne (numéro unique par compte)
    if (knownPhoneNumbers.contains(phoneNumber)) return true;
    return false;
  }
}

// ─── Modèles de données ─────────────────────────────────────────────────────

class UserBehavior {
  final DateTime createdAt;
  final bool phoneVerified;
  final bool kycApproved;
  final Duration avgSessionDuration;
  final int videosWatchedToday;
  final int successfulTransactions;
  final double likesPerMinute;
  final int accountsOnSameIp;
  final bool vpnDetected;
  final bool isEmulator;
  final int chargebacks;
  final int reportsReceived;

  const UserBehavior({
    required this.createdAt,
    this.phoneVerified = false,
    this.kycApproved = false,
    this.avgSessionDuration = Duration.zero,
    this.videosWatchedToday = 0,
    this.successfulTransactions = 0,
    this.likesPerMinute = 0,
    this.accountsOnSameIp = 0,
    this.vpnDetected = false,
    this.isEmulator = false,
    this.chargebacks = 0,
    this.reportsReceived = 0,
  });
}

class ViewEvent {
  final Duration timeSinceLastViewOnSameVideo;
  final int viewsFromDeviceToday;
  final Duration viewDuration;
  final int viewsFromIpToday;
  final bool isRegularPattern;

  const ViewEvent({
    required this.timeSinceLastViewOnSameVideo,
    required this.viewsFromDeviceToday,
    required this.viewDuration,
    required this.viewsFromIpToday,
    this.isRegularPattern = false,
  });
}

class PaymentEvent {
  final double amount;
  final double userAvgAmount;
  final DateTime accountCreatedAt;
  final int paymentsLast24h;
  final int momoNumberLinkedAccounts;
  final int userTrustScore;

  const PaymentEvent({
    required this.amount,
    required this.userAvgAmount,
    required this.accountCreatedAt,
    required this.paymentsLast24h,
    required this.momoNumberLinkedAccounts,
    required this.userTrustScore,
  });
}

enum FraudSeverity { none, medium, high }

class ViewFraudResult {
  final bool isFraudulent;
  final bool shouldBlock;
  final List<String> issues;
  final FraudSeverity severity;

  const ViewFraudResult({
    required this.isFraudulent,
    required this.shouldBlock,
    required this.issues,
    required this.severity,
  });
}

class PaymentFraudResult {
  final bool isSuspicious;
  final bool shouldBlock;
  final bool requiresManualReview;
  final List<String> issues;

  const PaymentFraudResult({
    required this.isSuspicious,
    required this.shouldBlock,
    required this.requiresManualReview,
    required this.issues,
  });
}

class RateLimits {
  final int maxViewsPerDay;
  final int maxLikesPerDay;
  final int maxCommentsPerDay;
  final double maxWithdrawPerDay;
  final bool requireOtpForWithdraw;

  const RateLimits({
    required this.maxViewsPerDay,
    required this.maxLikesPerDay,
    required this.maxCommentsPerDay,
    required this.maxWithdrawPerDay,
    required this.requireOtpForWithdraw,
  });
}
