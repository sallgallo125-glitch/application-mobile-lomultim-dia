/// Gift cards, mirroring DevA -final/src/domains/giftcard.
library;

/// Same bounds and presets as the site (GIFT_CARD_AMOUNTS, /gift-cards/config).
const giftCardMinXof = 5000;
const giftCardMaxXof = 1000000;
const giftCardStepXof = 1000;
const giftCardPresetsXof = [5000, 25000, 50000, 100000, 500000, 1000000];
const giftCardHomeDeliveryFeeXof = 2500;

/// Demo SMS code accepted by the mock backend for gift card payments.
const giftCardDemoOtp = '123456';

enum GiftCardDelivery {
  digitalEmail('DIGITAL_EMAIL', 'Carte numérique envoyée par e-mail'),
  digitalWhatsapp('DIGITAL_WHATSAPP', 'Carte numérique envoyée par WhatsApp'),
  physicalShowroom('PHYSICAL_SHOWROOM', 'Carte physique à retirer en showroom'),
  physicalHome(
      'PHYSICAL_HOME', 'Carte physique livrée à domicile (+2 500 FCFA)');

  const GiftCardDelivery(this.code, this.label);
  final String code;
  final String label;
}

class GiftCard {
  const GiftCard({
    required this.id,
    required this.code,
    required this.initialXof,
    required this.balanceXof,
    required this.status,
    required this.expiresAt,
    this.recipientName,
    this.serial,
  });
  final String id;
  final String code;

  /// Short number printed under the barcode: "0028" (physical card) or
  /// "E00004" (digital card).
  final String? serial;
  final int initialXof;
  final int balanceXof;

  /// ACTIVE, SUSPENDED or EXPIRED.
  final String status;
  final String expiresAt;
  final String? recipientName;

  bool get active => status == 'ACTIVE';

  factory GiftCard.fromJson(Map<String, dynamic> json) => GiftCard(
        id: json['id'] as String,
        code: json['code'] as String,
        initialXof: (json['initialXof'] as num).toInt(),
        balanceXof: (json['balanceXof'] as num).toInt(),
        status: json['status'] as String,
        expiresAt: json['expiresAt'] as String,
        recipientName: json['recipientName'] as String?,
        serial: json['serial'] as String?,
      );
}

class GiftCardBalance {
  const GiftCardBalance(
      {required this.code,
      required this.balanceXof,
      required this.status,
      required this.expiresAt});
  final String code;
  final int balanceXof;
  final String status;
  final String expiresAt;
  factory GiftCardBalance.fromJson(Map<String, dynamic> json) =>
      GiftCardBalance(
          code: json['code'] as String,
          balanceXof: (json['balanceXof'] as num).toInt(),
          status: json['status'] as String,
          expiresAt: json['expiresAt'] as String);
}
