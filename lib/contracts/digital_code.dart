/// A digital product the member bought (game, DLC, Windows licence…) and the
/// activation code delivered for it. Mirrors the server tables
/// order_items + product_variants + digital_deliveries (see the spec):
/// the clear code is only sent by the server to the authenticated owner.
library;

enum DigitalPlatform { windows, playstation, xbox, nintendo, steam }

enum DigitalCodeStatus { pending, delivered, failed, revoked }

class DigitalCode {
  const DigitalCode({
    required this.id,
    required this.orderNumber,
    required this.productName,
    required this.platform,
    required this.status,
    this.edition,
    this.regionCode,
    this.activationMethod = 'Code',
    this.sku,
    this.code,
    this.imageUrl,
    this.purchasedAt,
    this.deliveredAt,
    this.licenseType,
    this.devices,
    this.failureReason,
  });

  final String id;
  final String orderNumber;

  /// product_name_snapshot: name at purchase time.
  final String productName;
  final DigitalPlatform platform;
  final DigitalCodeStatus status;
  final String? edition;
  final String? regionCode;
  final String activationMethod;
  final String? sku;

  /// Clear code — null while not delivered.
  final String? code;
  final String? imageUrl;
  final String? purchasedAt;
  final String? deliveredAt;

  /// Windows only: Retail / OEM and number of PCs.
  final String? licenseType;
  final int? devices;
  final String? failureReason;

  bool get isWindows => platform == DigitalPlatform.windows;
  bool get hasCode => status == DigitalCodeStatus.delivered && code != null;
}
