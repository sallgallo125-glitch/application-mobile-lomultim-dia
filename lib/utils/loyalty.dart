/// LO+ programme rules, from the specification (cahier des charges LO+,
/// §5.1 and §5.2) and DevA -final/src/mocks/fixtures/loyalty.ts.
library;

class LoyaltyTier {
  const LoyaltyTier({
    required this.code,
    required this.name,
    required this.minSpendXof,
    required this.thresholdLabel,
    required this.multiplier,
    required this.benefits,
  });
  final String code;
  final String name;
  final int minSpendXof;
  final String thresholdLabel;
  final double multiplier;
  final List<String> benefits;
}

/// Tiers depend on eligible purchases over the last 12 months (§5.2).
const loyaltyTiers = [
  LoyaltyTier(
    code: 'BLEU',
    name: 'Bleu',
    minSpendXof: 0,
    thresholdLabel: "Dès l'adhésion",
    multiplier: 1,
    benefits: [
      "1 point par tranche de 10 000 FCFA d'achats",
      'Points valables 12 mois',
      'Parrainage : 50 points par filleul actif',
    ],
  ),
  LoyaltyTier(
    code: 'SILVER',
    name: 'Silver',
    minSpendXof: 2000000,
    thresholdLabel: "Dès 2 000 000 FCFA d'achats sur 12 mois",
    multiplier: 1.2,
    benefits: [
      'Multiplicateur de points ×1,2',
      "Bon d'anniversaire de 5 000 FCFA",
      'Accès prioritaire au SAV',
    ],
  ),
  LoyaltyTier(
    code: 'GOLD',
    name: 'Gold',
    minSpendXof: 3000000,
    thresholdLabel: "Dès 3 000 000 FCFA d'achats sur 12 mois",
    multiplier: 1.5,
    benefits: [
      'Multiplicateur de points ×1,5',
      'Points valables 24 mois',
      "Bon d'anniversaire de 15 000 FCFA",
      'Livraison offerte à Dakar (zone 1)',
      'Diagnostic SAV gratuit, support prioritaire',
    ],
  ),
  LoyaltyTier(
    code: 'PLATINUM',
    name: 'Platinium',
    minSpendXof: 5000000,
    thresholdLabel: "Dès 5 000 000 FCFA d'achats sur 12 mois",
    multiplier: 2,
    benefits: [
      'Multiplicateur de points ×2',
      "Bon d'anniversaire de 30 000 FCFA",
      'Livraison offerte sans limite',
      'SAV gratuit, urgence en moins de 24 h, support VIP dédié',
    ],
  ),
];

/// 1 point per full 10 000 FCFA tranche (CFG.tranche).
const loyaltyTrancheXof = 10000;

/// 1 point is worth 100 FCFA when paying with points (CFG.valeurPoint).
const loyaltyPointValueXof = 100;

/// Fewest points usable on an order (CFG.ptsPaiementMin).
const loyaltyMinRedeemPoints = 10;

const loyaltyRulesNote =
    'Les points sont crédités 24 h après la livraison complète et le paiement '
    'de la commande. Les cartes cadeaux, les frais de livraison et les '
    'accessoires de moins de 10 000 FCFA ne rapportent pas de points.';

LoyaltyTier loyaltyTierFor(String code) => loyaltyTiers
    .firstWhere((t) => t.code == code, orElse: () => loyaltyTiers.first);

/// The tier after [code], or null at the top tier.
LoyaltyTier? nextLoyaltyTier(String code) {
  final i = loyaltyTiers.indexWhere((t) => t.code == code);
  return i < 0 || i + 1 >= loyaltyTiers.length ? null : loyaltyTiers[i + 1];
}

/// Points earned on [merchandiseXof] (delivery excluded) at [tierCode].
int loyaltyPointsFor(int merchandiseXof, [String tierCode = 'BLEU']) =>
    merchandiseXof <= 0
        ? 0
        : ((merchandiseXof ~/ loyaltyTrancheXof) *
                loyaltyTierFor(tierCode).multiplier)
            .floor();

/// Most points usable on an order of [totalXof] with [balance] points: up to
/// 100 % of the order (CFG.ptsPaiementMaxPct), 0 under the 10-point minimum.
int redeemablePoints(int balance, int totalXof) {
  final max = balance < totalXof ~/ loyaltyPointValueXof
      ? balance
      : totalXof ~/ loyaltyPointValueXof;
  return max < loyaltyMinRedeemPoints ? 0 : max;
}
