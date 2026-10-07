import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/delivery.dart';
import 'package:mobile_app/utils/loyalty.dart';

/// Same cases as the site's checkoutTotals.test.ts, plus the edge rules, so
/// the app and the site charge exactly the same amount.
void main() {
  group('calculateCheckoutTotals (identique au site)', () {
    test('applique une remise et les frais de zone standard', () {
      final t = calculateCheckoutTotals(
          100000, DeliveryMethod.standard, 'dakar-banlieue', 'LO10');
      expect(t.subtotalXof, 100000);
      expect(t.promoDiscountXof, 10000);
      expect(t.deliveryFeeXof, 3000);
      expect(t.totalXof, 93000);
      expect(t.promoStatus, PromoStatus.applied);
    });

    test('rend le retrait gratuit', () {
      final t =
          calculateCheckoutTotals(100000, DeliveryMethod.pickup, 'dakar-centre');
      expect(t.deliveryFeeXof, 0);
      expect(t.totalXof, 100000);
      expect(t.promoStatus, PromoStatus.notProvided);
    });

    test('signale un code inconnu sans remise', () {
      final t = calculateCheckoutTotals(
          100000, DeliveryMethod.standard, 'dakar-centre', 'UNKNOWN');
      expect(t.promoDiscountXof, 0);
      expect(t.promoStatus, PromoStatus.invalidOrExpired);
    });

    test('code promo insensible a la casse et aux espaces', () {
      final t = calculateCheckoutTotals(
          100000, DeliveryMethod.standard, 'dakar-centre', ' welcome10 ');
      expect(t.promoStatus, PromoStatus.applied);
    });

    test('frais par zone, prefixe zone- accepte, zone inconnue = 2 500', () {
      expect(deliveryFeeXof(DeliveryMethod.standard, 'dakar-centre', 1), 2500);
      expect(deliveryFeeXof(DeliveryMethod.standard, 'zone-rufisque', 1), 4000);
      expect(deliveryFeeXof(DeliveryMethod.standard, 'thies', 1), 5000);
      expect(deliveryFeeXof(DeliveryMethod.standard, 'regions', 1), 7000);
      expect(deliveryFeeXof(DeliveryMethod.standard, 'inconnue', 1), 2500);
    });

    test('standard offerte des 500 000, express jamais offerte', () {
      expect(deliveryFeeXof(DeliveryMethod.standard, 'regions', 499999), 7000);
      expect(deliveryFeeXof(DeliveryMethod.standard, 'regions', 500000), 0);
      expect(deliveryFeeXof(DeliveryMethod.express, 'regions', 900000), 4500);
    });
  });

  group('LO+ (cahier des charges §5.1-5.2)', () {
    test('1 point par tranche de 10 000, multiplié par palier', () {
      expect(loyaltyPointsFor(9999), 0);
      expect(loyaltyPointsFor(795000), 79);
      expect(loyaltyPointsFor(795000, 'SILVER'), 94);
      expect(loyaltyPointsFor(795000, 'PLATINUM'), 158);
    });

    test('1 point = 100 FCFA, 10 points minimum, 100 % de la commande', () {
      expect(loyaltyPointValueXof, 100);
      expect(redeemablePoints(68, 1000000), 68);
      expect(redeemablePoints(500, 12000), 120); // plafonné au total
      expect(redeemablePoints(9, 1000000), 0);
    });

    test('paliers Bleu, Silver, Gold, Platinium', () {
      expect(loyaltyTiers.map((t) => t.name),
          ['Bleu', 'Silver', 'Gold', 'Platinium']);
      expect(nextLoyaltyTier('BLEU')!.code, 'SILVER');
      expect(nextLoyaltyTier('PLATINUM'), isNull);
    });
  });
}
