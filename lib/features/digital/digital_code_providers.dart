import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/account.dart';
import '../../contracts/digital_code.dart';
import '../account/account_providers.dart';
import 'digital_catalog.dart';

/// The member's digital purchases: one code per digital item of their
/// orders (newest first), then the demo codes. Mock until the server
/// exposes GET /api/v1/me/digital-codes (clear codes decrypted server side).
final digitalCodesProvider = FutureProvider<List<DigitalCode>>((ref) async {
  // Signed out or offline: the demo codes still show.
  List<OrderSummary> orders;
  try {
    orders = await ref.watch(ordersProvider.future);
  } catch (_) {
    orders = const [];
  }
  return [
    for (final order in orders) ...digitalCodesForOrder(order),
    ..._mockCodes,
  ];
});

/// Codes delivered for the digital items of [order] (also for guests, on
/// the confirmation page).
List<DigitalCode> digitalCodesForOrder(OrderSummary order) => [
      for (final item in order.items)
        if (digitalCatalog[item.productId] case final spec?)
          for (var n = 0; n < item.quantity; n++)
            _deliveredCode(spec, order.number, order.createdAt, order.status,
                item.productId!, n),
    ];

DigitalCode _deliveredCode(DigitalProductSpec spec, String orderNumber,
    String createdAt, String orderStatus, String productId, int index) {
  final cancelled = orderStatus.toLowerCase().contains('annul');
  return DigitalCode(
    id: '$orderNumber-$productId-$index',
    orderNumber: orderNumber,
    productName: spec.name,
    platform: spec.platform,
    status: cancelled ? DigitalCodeStatus.revoked : DigitalCodeStatus.delivered,
    edition: spec.edition,
    regionCode: spec.region,
    activationMethod: spec.activation,
    sku: spec.sku,
    licenseType: spec.licenseType,
    devices: spec.devices,
    code: cancelled
        ? null
        : _generateCode(spec.platform, '$orderNumber-$productId-$index'),
    purchasedAt: createdAt,
    deliveredAt: createdAt,
    failureReason:
        cancelled ? 'Commande annulée : ce code a été désactivé.' : null,
  );
}

/// Stable fake code in each platform's real format (same order → same code).
String _generateCode(DigitalPlatform platform, String seed) {
  final (groups, size) = switch (platform) {
    DigitalPlatform.windows || DigitalPlatform.xbox => (5, 5),
    DigitalPlatform.playstation => (3, 4),
    DigitalPlatform.nintendo => (4, 4),
    DigitalPlatform.steam => (3, 5),
  };
  // No 0/O, 1/I: they are misread when typed on a console.
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random =
      Random(seed.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff));
  return [
    for (var g = 0; g < groups; g++)
      [for (var i = 0; i < size; i++) chars[random.nextInt(chars.length)]]
          .join(),
  ].join('-');
}

final digitalCodeProvider =
    FutureProvider.family<DigitalCode?, String>((ref, id) async {
  final codes = await ref.watch(digitalCodesProvider.future);
  for (final c in codes) {
    if (c.id == id) return c;
  }
  return null;
});

/// Codes attached to one order, for the order detail page.
List<DigitalCode> orderDigitalCodes(OrderSummary order) => [
      ...digitalCodesForOrder(order),
      for (final c in _mockCodes)
        if (c.orderNumber == order.number) c,
    ];

const _mockCodes = [
  DigitalCode(
    id: 'dc-1',
    orderNumber: 'LO-2026-00142',
    productName: 'Windows 11 Professionnel',
    platform: DigitalPlatform.windows,
    status: DigitalCodeStatus.delivered,
    edition: 'Pro',
    regionCode: 'Mondial',
    activationMethod: 'Clé produit',
    sku: 'FQC-10572',
    code: 'VK7JG-NPHTM-C97JM-9MPGT-3V66T',
    purchasedAt: '18/10/2026',
    deliveredAt: '18/10/2026 à 14:32',
    licenseType: 'Retail',
    devices: 1,
  ),
  DigitalCode(
    id: 'dc-2',
    orderNumber: 'LO-2026-00142',
    productName: 'Windows 10 Famille',
    platform: DigitalPlatform.windows,
    status: DigitalCodeStatus.delivered,
    edition: 'Famille',
    regionCode: 'Mondial',
    activationMethod: 'Clé produit',
    sku: 'KW9-00265',
    code: 'TX9XD-98N7V-6WMQ6-BX7FG-H8Q99',
    purchasedAt: '18/10/2026',
    deliveredAt: '18/10/2026 à 14:32',
    licenseType: 'Retail',
    devices: 1,
  ),
  DigitalCode(
    id: 'dc-3',
    orderNumber: 'LO-2026-00118',
    productName: 'EA SPORTS FC 26',
    platform: DigitalPlatform.playstation,
    status: DigitalCodeStatus.delivered,
    edition: 'Standard · PS5',
    regionCode: 'EU',
    activationMethod: 'Code PlayStation Store',
    sku: 'PS5-FC26-STD-EU',
    code: 'MR4N-7BKD-QE9H',
    purchasedAt: '12/10/2026',
    deliveredAt: '12/10/2026 à 09:05',
  ),
  DigitalCode(
    id: 'dc-4',
    orderNumber: 'LO-2026-00118',
    productName: 'Forza Horizon 5',
    platform: DigitalPlatform.xbox,
    status: DigitalCodeStatus.delivered,
    edition: 'Premium · Xbox Series X|S',
    regionCode: 'Mondial',
    activationMethod: 'Code Microsoft Store',
    sku: 'XB-FH5-PRM',
    code: 'H7GQ3-KCX9P-2VWRT-M8DJF-4YB6Z',
    purchasedAt: '12/10/2026',
    deliveredAt: '12/10/2026 à 09:05',
  ),
  DigitalCode(
    id: 'dc-5',
    orderNumber: 'LO-2026-00421',
    productName: 'Mario Kart World',
    platform: DigitalPlatform.nintendo,
    status: DigitalCodeStatus.pending,
    edition: 'Standard · Switch 2',
    regionCode: 'EU',
    activationMethod: 'Code Nintendo eShop',
    sku: 'NSW2-MKW-EU',
    purchasedAt: '21/10/2026',
  ),
  DigitalCode(
    id: 'dc-6',
    orderNumber: 'LO-2026-00377',
    productName: 'Cyberpunk 2077',
    platform: DigitalPlatform.steam,
    status: DigitalCodeStatus.delivered,
    edition: 'Ultimate · PC',
    regionCode: 'Mondial',
    activationMethod: 'Clé Steam',
    sku: 'STM-CP77-ULT',
    code: 'AB3CD-EF4GH-IJ5KL',
    purchasedAt: '02/10/2026',
    deliveredAt: '02/10/2026 à 18:47',
  ),
];
