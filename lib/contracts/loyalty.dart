/// LO+ member data, mirroring the site's loyalty domain
/// (DevA -final/src/domains/loyalty/types.ts), trimmed to what the app shows.
library;

class LoyaltyMember {
  const LoyaltyMember({
    required this.cardNumber,
    required this.holderName,
    required this.tierCode,
    required this.points,
    required this.pendingPoints,
    required this.spend12MonthsXof,
  });
  final String cardNumber;
  final String holderName;
  final String tierCode;
  final int points;
  final int pendingPoints;
  final int spend12MonthsXof;

  factory LoyaltyMember.fromJson(Map<String, dynamic> json) => LoyaltyMember(
        cardNumber: json['cardNumber'] as String,
        holderName: json['holderName'] as String,
        tierCode: json['tierCode'] as String,
        points: (json['points'] as num).toInt(),
        pendingPoints: (json['pendingPoints'] as num?)?.toInt() ?? 0,
        spend12MonthsXof: (json['spend12MonthsXof'] as num).toInt(),
      );
}

/// Short-lived QR token shown at the till.
class LoyaltyQrToken {
  const LoyaltyQrToken({required this.token, required this.expiresAt});
  final String token;
  final DateTime expiresAt;
  factory LoyaltyQrToken.fromJson(Map<String, dynamic> json) => LoyaltyQrToken(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String));
}

class LoyaltyMovement {
  const LoyaltyMovement(
      {required this.id,
      required this.date,
      required this.label,
      required this.points,
      required this.pending});
  final String id;
  final String date;
  final String label;

  /// Positive = earned, negative = spent / expired.
  final int points;
  final bool pending;
  factory LoyaltyMovement.fromJson(Map<String, dynamic> json) =>
      LoyaltyMovement(
          id: json['id'] as String,
          date: json['date'] as String,
          label: json['label'] as String,
          points: (json['points'] as num).toInt(),
          pending: json['pending'] as bool? ?? false);
}

class LoyaltyReward {
  const LoyaltyReward({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.points,
    this.stock,
    required this.freeValue,
  });
  final String id;
  final String category;
  final String title;
  final String description;

  /// Cost; for a [freeValue] voucher, the minimum cost.
  final int points;

  /// null = unlimited.
  final int? stock;

  /// Voucher whose value the member chooses (1 point = 100 FCFA).
  final bool freeValue;

  bool get outOfStock => stock == 0;

  factory LoyaltyReward.fromJson(Map<String, dynamic> json) => LoyaltyReward(
        id: json['id'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        points: (json['points'] as num).toInt(),
        stock: (json['stock'] as num?)?.toInt(),
        freeValue: json['freeValue'] as bool? ?? false,
      );
}

class LoyaltyVoucher {
  const LoyaltyVoucher(
      {required this.code,
      required this.title,
      required this.pointsSpent,
      this.valueXof,
      required this.validUntil});
  final String code;
  final String title;
  final int pointsSpent;
  final int? valueXof;
  final String validUntil;
  factory LoyaltyVoucher.fromJson(Map<String, dynamic> json) => LoyaltyVoucher(
      code: json['code'] as String,
      title: json['title'] as String,
      pointsSpent: (json['pointsSpent'] as num).toInt(),
      valueXof: (json['valueXof'] as num?)?.toInt(),
      validUntil: json['validUntil'] as String);
}

class LoyaltyReferral {
  const LoyaltyReferral(
      {required this.name, required this.status, required this.points});
  final String name;

  /// PENDING (signed up, no qualifying purchase yet) or ACTIVE.
  final String status;
  final int points;
  factory LoyaltyReferral.fromJson(Map<String, dynamic> json) =>
      LoyaltyReferral(
          name: json['name'] as String,
          status: json['status'] as String,
          points: (json['points'] as num).toInt());
}

class LoyaltyReferrals {
  const LoyaltyReferrals(
      {required this.code,
      required this.referrerPoints,
      required this.refereePoints,
      required this.minPurchaseXof,
      required this.referrals});
  final String code;
  final int referrerPoints;
  final int refereePoints;
  final int minPurchaseXof;
  final List<LoyaltyReferral> referrals;
  factory LoyaltyReferrals.fromJson(Map<String, dynamic> json) =>
      LoyaltyReferrals(
          code: json['code'] as String,
          referrerPoints: (json['referrerPoints'] as num).toInt(),
          refereePoints: (json['refereePoints'] as num).toInt(),
          minPurchaseXof: (json['minPurchaseXof'] as num).toInt(),
          referrals: (json['referrals'] as List<dynamic>)
              .map((r) => LoyaltyReferral.fromJson(r as Map<String, dynamic>))
              .toList());
}

class LoyaltyChallenge {
  const LoyaltyChallenge(
      {required this.code,
      required this.label,
      required this.reward,
      required this.frequency,
      required this.progress,
      required this.target,
      required this.unit});
  final String code;
  final String label;
  final String reward;

  /// MONTHLY or ONCE.
  final String frequency;
  final int progress;
  final int target;
  final String unit;
  bool get done => progress >= target;
  factory LoyaltyChallenge.fromJson(Map<String, dynamic> json) =>
      LoyaltyChallenge(
          code: json['code'] as String,
          label: json['label'] as String,
          reward: json['reward'] as String,
          frequency: json['frequency'] as String,
          progress: (json['progress'] as num).toInt(),
          target: (json['target'] as num).toInt(),
          unit: json['unit'] as String);
}

class LoyaltyBadge {
  const LoyaltyBadge(
      {required this.code,
      required this.label,
      required this.condition,
      required this.points,
      required this.earned});
  final String code;
  final String label;
  final String condition;
  final int points;
  final bool earned;
  factory LoyaltyBadge.fromJson(Map<String, dynamic> json) => LoyaltyBadge(
      code: json['code'] as String,
      label: json['label'] as String,
      condition: json['condition'] as String,
      points: (json['points'] as num).toInt(),
      earned: json['earned'] as bool);
}

class LoyaltyChallenges {
  const LoyaltyChallenges({required this.challenges, required this.badges});
  final List<LoyaltyChallenge> challenges;
  final List<LoyaltyBadge> badges;
  factory LoyaltyChallenges.fromJson(Map<String, dynamic> json) =>
      LoyaltyChallenges(
          challenges: (json['challenges'] as List<dynamic>)
              .map((c) => LoyaltyChallenge.fromJson(c as Map<String, dynamic>))
              .toList(),
          badges: (json['badges'] as List<dynamic>)
              .map((b) => LoyaltyBadge.fromJson(b as Map<String, dynamic>))
              .toList());
}
