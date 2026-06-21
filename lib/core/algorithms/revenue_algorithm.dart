/// Algorithme de répartition des revenus BeninPlay
///
/// Règle principale :
///   Créateur reçoit 80% — BeninPlay garde 20%
///
/// Sources de revenus :
///   1. Abonnements Zone Dark (mensuel/trimestriel/annuel)
///   2. Tips (pourboires) directs
///   3. Ventes vidéos à l'unité
///   4. Publicités (Zone Normale)

class RevenueAlgorithm {
  // ─── Commission plateforme ───────────────────────────────────────────────
  static const double platformFee = 0.20;     // 20% BeninPlay
  static const double creatorShare = 0.80;    // 80% créateur

  // ─── Prix des abonnements (FCFA) ────────────────────────────────────────
  static const int subMonthly = 2000;
  static const int subQuarterly = 5000;
  static const int subAnnual = 18000;

  // ─── Calcul revenu abonnement ───────────────────────────────────────────
  static RevenueBreakdown fromSubscription({
    required int amount,          // montant payé par l'abonné
    required int subscriberCount, // nombre d'abonnés actifs
    required double taxRate,      // TVA locale (ex: 0.18 = 18%)
  }) {
    // Déduire les frais de traitement Mobile Money (~1.5%)
    final momoFee = (amount * 0.015).round();
    final afterMomo = amount - momoFee;

    // Déduire la TVA si applicable
    final taxAmount = (afterMomo * taxRate).round();
    final afterTax = afterMomo - taxAmount;

    // Répartition plateforme / créateur
    final toCreator = (afterTax * creatorShare).round();
    final toPlatform = afterTax - toCreator;

    return RevenueBreakdown(
      grossAmount: amount,
      momoFee: momoFee,
      taxAmount: taxAmount,
      toCreator: toCreator,
      toPlatform: toPlatform,
      perSubscriberCreatorRevenue: toCreator,
      totalCreatorRevenue: toCreator * subscriberCount,
    );
  }

  // ─── Calcul revenu tip ──────────────────────────────────────────────────
  static RevenueBreakdown fromTip({
    required int tipAmount,
    required double taxRate,
  }) {
    final momoFee = (tipAmount * 0.015).round();
    final afterMomo = tipAmount - momoFee;
    final taxAmount = (afterMomo * taxRate).round();
    final afterTax = afterMomo - taxAmount;

    final toCreator = (afterTax * creatorShare).round();
    final toPlatform = afterTax - toCreator;

    return RevenueBreakdown(
      grossAmount: tipAmount,
      momoFee: momoFee,
      taxAmount: taxAmount,
      toCreator: toCreator,
      toPlatform: toPlatform,
      perSubscriberCreatorRevenue: toCreator,
      totalCreatorRevenue: toCreator,
    );
  }

  // ─── Revenu mensuel estimé d'un créateur ───────────────────────────────
  static CreatorEarningsEstimate estimateMonthlyEarnings({
    required int followers,
    required int monthlyViews,
    required int darkSubscribers,
    required int tipsReceived,
    required int avgTipAmount,
  }) {
    // Taux de conversion abonnés → abonnés Dark (typiquement 2-5%)
    final darkConversionRate = 0.03;
    final estimatedDarkSubs = darkSubscribers > 0
        ? darkSubscribers
        : (followers * darkConversionRate).round();

    // Revenu abonnements Dark
    final subRevenue = fromSubscription(
      amount: subMonthly,
      subscriberCount: estimatedDarkSubs,
      taxRate: 0.18,
    ).totalCreatorRevenue;

    // Revenu tips
    final tipRevenue = (fromTip(
          tipAmount: avgTipAmount,
          taxRate: 0.18,
        ).toCreator *
        tipsReceived);

    // Revenu publicités Zone Normale (CPM ≈ 500 FCFA / 1000 vues)
    final adRevenue = ((monthlyViews / 1000) * 500 * creatorShare).round();

    final totalRevenue = subRevenue + tipRevenue + adRevenue;

    return CreatorEarningsEstimate(
      fromSubscriptions: subRevenue,
      fromTips: tipRevenue,
      fromAds: adRevenue,
      total: totalRevenue,
      estimatedDarkSubscribers: estimatedDarkSubs,
    );
  }

  // ─── Calcul seuil de retrait ─────────────────────────────────────────────
  static WithdrawalResult canWithdraw({
    required double balance,
    required double requestedAmount,
    required int trustScore,
    required bool kycApproved,
  }) {
    const minWithdraw = 500.0;   // minimum 500 FCFA
    const maxWithdraw = 500000.0; // maximum 500,000 FCFA par transaction

    if (!kycApproved && requestedAmount > 10000) {
      return WithdrawalResult(
        approved: false,
        reason: 'KYC requis pour retrait > 10 000 FCFA',
        requiresKyc: true,
      );
    }

    if (requestedAmount < minWithdraw) {
      return WithdrawalResult(
        approved: false,
        reason: 'Montant minimum : 500 FCFA',
      );
    }

    if (requestedAmount > balance) {
      return WithdrawalResult(
        approved: false,
        reason: 'Solde insuffisant',
      );
    }

    if (requestedAmount > maxWithdraw) {
      return WithdrawalResult(
        approved: false,
        reason: 'Maximum par transaction : 500 000 FCFA',
      );
    }

    if (trustScore < 30) {
      return WithdrawalResult(
        approved: false,
        reason: 'Compte suspendu pour vérification de sécurité',
      );
    }

    // Frais de retrait Mobile Money
    final momoFee = (requestedAmount * 0.01).clamp(50, 500).round();

    return WithdrawalResult(
      approved: true,
      netAmount: requestedAmount - momoFee,
      momoFee: momoFee.toDouble(),
      reason: 'Retrait approuvé',
    );
  }

  // ─── Tableau revenus simples ─────────────────────────────────────────────
  static String revenueTable() {
    final rows = StringBuffer();
    rows.writeln('=== TABLEAU REVENUS BENINPLAY ===\n');
    rows.writeln('Abonné Dark paie  : 2 000 FCFA');
    rows.writeln('Frais MoMo (~1.5%): -  30 FCFA');
    rows.writeln('TVA (18%)         : - 354 FCFA');
    rows.writeln('Net               : 1 616 FCFA');
    rows.writeln('  → Créateur (80%): 1 293 FCFA ✓');
    rows.writeln('  → Plateforme(20%):  323 FCFA');
    rows.writeln('\nAvec 100 abonnés Dark :');
    rows.writeln('  Créateur gagne  : 129 300 FCFA/mois');
    rows.writeln('  BeninPlay gagne :  32 300 FCFA/mois');
    return rows.toString();
  }
}

// ─── Modèles ─────────────────────────────────────────────────────────────────

class RevenueBreakdown {
  final int grossAmount;
  final int momoFee;
  final int taxAmount;
  final int toCreator;
  final int toPlatform;
  final int perSubscriberCreatorRevenue;
  final int totalCreatorRevenue;

  const RevenueBreakdown({
    required this.grossAmount,
    required this.momoFee,
    required this.taxAmount,
    required this.toCreator,
    required this.toPlatform,
    required this.perSubscriberCreatorRevenue,
    required this.totalCreatorRevenue,
  });

  @override
  String toString() => '''
Montant brut      : $grossAmount FCFA
Frais MoMo        : -$momoFee FCFA
TVA               : -$taxAmount FCFA
→ Créateur (80%)  : $toCreator FCFA
→ Plateforme (20%): $toPlatform FCFA
''';
}

class CreatorEarningsEstimate {
  final int fromSubscriptions;
  final int fromTips;
  final int fromAds;
  final int total;
  final int estimatedDarkSubscribers;

  const CreatorEarningsEstimate({
    required this.fromSubscriptions,
    required this.fromTips,
    required this.fromAds,
    required this.total,
    required this.estimatedDarkSubscribers,
  });
}

class WithdrawalResult {
  final bool approved;
  final String reason;
  final double? netAmount;
  final double? momoFee;
  final bool requiresKyc;

  const WithdrawalResult({
    required this.approved,
    required this.reason,
    this.netAmount,
    this.momoFee,
    this.requiresKyc = false,
  });
}
