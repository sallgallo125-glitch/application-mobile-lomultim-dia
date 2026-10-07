/// Mirrors the website's checkout pricing, the source of truth for what the
/// customer pays: DevA -final/src/domains/checkout/utils/checkoutTotals.ts.
/// Shared by the mock backend and the cart/checkout screens so the displayed
/// total always matches the order.
library;

enum DeliveryMethod {
  standard('STANDARD', 'Livraison standard', '24 à 72 h'),
  express('EXPRESS', 'Livraison express', 'Sous 4 h · Dakar · 4 500 FCFA'),
  pickup('PICKUP', 'Retrait showroom', 'Gratuit en showroom');

  const DeliveryMethod(this.code, this.label, this.hint);
  final String code;
  final String label;
  final String hint;

  static DeliveryMethod fromCode(String? code) => DeliveryMethod.values
      .firstWhere((m) => m.code == code, orElse: () => DeliveryMethod.standard);
}

class DeliveryZone {
  const DeliveryZone(this.id, this.label, this.standardFeeXof);
  final String id;
  final String label;
  final int standardFeeXof;
}

/// Same ids, labels and fees as the site's checkout zone selector.
const deliveryZones = [
  DeliveryZone('dakar-centre', 'Dakar Centre', 2500),
  DeliveryZone('dakar-banlieue', 'Dakar Banlieue', 3000),
  DeliveryZone('rufisque', 'Rufisque', 4000),
  DeliveryZone('thies', 'Thiès', 5000),
  DeliveryZone('regions', 'Régions', 7000),
];

const defaultZoneId = 'dakar-centre';
const expressFeeXof = 4500;
const defaultStandardFeeXof = 2500;

/// Standard delivery is free from this subtotal (express is never free).
const freeDeliveryThresholdXof = 500000;

const _promoCodes = {'WELCOME10', 'LO10'};
const promoRate = 0.10;

enum PromoStatus { notProvided, applied, invalidOrExpired }

class CheckoutTotals {
  const CheckoutTotals({
    required this.subtotalXof,
    required this.promoDiscountXof,
    required this.deliveryFeeXof,
    required this.totalXof,
    required this.promoStatus,
  });
  final int subtotalXof;
  final int promoDiscountXof;
  final int deliveryFeeXof;
  final int totalXof;
  final PromoStatus promoStatus;
}

int deliveryFeeXof(DeliveryMethod method, String zoneId, int subtotalXof) {
  if (method == DeliveryMethod.pickup) return 0;
  if (method == DeliveryMethod.express) return expressFeeXof;
  if (subtotalXof >= freeDeliveryThresholdXof) return 0;
  final id = zoneId.replaceFirst(RegExp(r'^zone-'), '');
  for (final zone in deliveryZones) {
    if (zone.id == id) return zone.standardFeeXof;
  }
  return defaultStandardFeeXof;
}

CheckoutTotals calculateCheckoutTotals(
    int subtotalXof, DeliveryMethod method, String zoneId,
    [String promoCode = '']) {
  final fee = deliveryFeeXof(method, zoneId, subtotalXof);
  final code = promoCode.trim().toUpperCase();
  final applied = code.isNotEmpty && _promoCodes.contains(code);
  final discount = applied ? (subtotalXof * promoRate).round() : 0;
  final total = subtotalXof - discount + fee;
  return CheckoutTotals(
    subtotalXof: subtotalXof,
    promoDiscountXof: discount,
    deliveryFeeXof: fee,
    totalXof: total < 0 ? 0 : total,
    promoStatus: promoCode.trim().isEmpty
        ? PromoStatus.notProvided
        : applied
            ? PromoStatus.applied
            : PromoStatus.invalidOrExpired,
  );
}

/// Payment methods, in the site's order. Only cash is live on the site; the
/// others are shown disabled ("Disponible au lancement").
enum PaymentMethod {
  cashOnDelivery('CASH_ON_DELIVERY', 'Paiement à la livraison',
      'Espèces au retrait ou à la livraison', true),
  wave('WAVE', 'Wave', 'Demande de paiement sur votre téléphone · 0 frais',
      true),
  orangeMoney('ORANGE_MONEY', 'Orange Money',
      'Validez avec votre code secret Orange Money', true),
  freeMoney('FREE_MONEY', 'Free Money',
      'Validez avec votre code secret Free Money', true),
  card('CARD', 'Carte bancaire', 'Visa, Mastercard · paiement sécurisé', true);

  /// Paid online before delivery (the others: on delivery).
  bool get isOnline => this != cashOnDelivery;

  const PaymentMethod(this.code, this.label, this.description, this.available);
  final String code;
  final String label;
  final String description;
  final bool available;

  static PaymentMethod? fromCode(String? code) {
    for (final m in PaymentMethod.values) {
      if (m.code == code) return m;
    }
    return null;
  }
}
