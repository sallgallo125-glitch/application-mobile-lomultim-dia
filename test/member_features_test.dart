import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/errors.dart';
import 'package:mobile_app/api/repositories/cart_repository.dart';
import 'package:mobile_app/api/repositories/checkout_repository.dart';
import 'package:mobile_app/api/repositories/member_repositories.dart';
import 'package:mobile_app/contracts/gift_card.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';

void main() {
  late MockHttpClient client;
  late LoyaltyRepository loyalty;
  late GiftCardRepository giftCards;
  late ContentRepository content;
  late CartRepository cart;
  late CheckoutRepository checkout;

  setUp(() {
    client = MockHttpClient();
    final api = ApiClient(client: client);
    loyalty = LoyaltyRepository(api);
    giftCards = GiftCardRepository(api);
    content = ContentRepository(api);
    cart = CartRepository(api);
    checkout = CheckoutRepository(api);
  });

  group('LO+', () {
    test('échange de points : débite, crédite le défi 1re conversion', () async {
      expect((await loyalty.getMember()).points, 68);
      final voucher = await loyalty.convert('CAT-003'); // 30 points
      expect(voucher.pointsSpent, 30);
      // 68 − 30 + 10 (défi CONV1)
      expect((await loyalty.getMember()).points, 48);
      final challenges = await loyalty.getChallenges();
      expect(challenges.challenges.firstWhere((c) => c.code == 'CONV1').done, isTrue);
    });

    test("bon d'achat à valeur libre : 1 point = 100 FCFA", () async {
      final voucher = await loyalty.convert('CAT-001', points: 60);
      expect(voucher.valueXof, 6000);
    });

    test('refuse un échange au-delà du solde ou épuisé', () async {
      expect(() => loyalty.convert('CAT-009'), throwsA(isA<ApiHttpError>()));
      expect(() => loyalty.convert('CAT-013'), throwsA(isA<ApiHttpError>()));
    });

    test('QR code valable 5 minutes', () async {
      final qr = await loyalty.createQrToken();
      final minutes = qr.expiresAt.difference(DateTime.now()).inMinutes;
      expect(minutes, inInclusiveRange(4, 5));
    });
  });

  group('Cartes cadeaux', () {
    test('achat : bornes du site (5 000 à 1 000 000, multiples de 1 000)', () async {
      expect(
          () => giftCards.buy(
              amountXof: 4000,
              delivery: GiftCardDelivery.digitalEmail,
              recipientName: 'Fatou'),
          throwsA(isA<ApiHttpError>()));
      final card = await giftCards.buy(
          amountXof: 25000,
          delivery: GiftCardDelivery.digitalWhatsapp,
          recipientName: 'Fatou');
      expect((await giftCards.checkBalance(card.code)).balanceXof, 25000);
    });

    test('suspension puis réactivation', () async {
      final suspended = await giftCards.setSuspended('gc-1', true);
      expect(suspended.status, 'SUSPENDED');
      expect((await giftCards.setSuspended('gc-1', false)).status, 'ACTIVE');
    });
  });

  group('Paiement en points et carte cadeau', () {
    test('points puis carte cadeau, le reste en espèces', () async {
      await cart.addItem('p-005'); // 142 000
      final order = await checkout.createOrder(
          deliveryMethod: 'PICKUP',
          zoneId: 'dakar-centre',
          payment: 'CASH_ON_DELIVERY',
          pointsToUse: 50, // 5 000 FCFA
          giftCardCode: 'LOGC-4821-7730', // solde 32 000
          giftCardOtp: giftCardDemoOtp,
          name: 'Aissatou',
          phone: '776211111');
      expect(order.totalXof, 142000);
      expect(order.pointsDiscountXof, 5000);
      expect(order.giftCardAppliedXof, 32000);
      expect(order.amountDueXof, 105000);
      // Points gagnés sur 142 000 − 5 000 payés en points.
      expect(order.pointsToEarn, 13);
      expect((await loyalty.getMember()).points, 18);
      expect((await giftCards.checkBalance('LOGC-4821-7730')).balanceXof, 0);
    });

    test('code SMS de la carte cadeau obligatoire', () async {
      await cart.addItem('p-005');
      expect(
          () => checkout.createOrder(
              deliveryMethod: 'PICKUP',
              zoneId: 'dakar-centre',
              payment: 'CASH_ON_DELIVERY',
              giftCardCode: 'LOGC-4821-7730',
              giftCardOtp: '000000',
              name: 'Aissatou',
              phone: '776211111'),
          throwsA(isA<ApiHttpError>()
              .having((e) => e.message, 'message', 'Code de confirmation incorrect.')));
    });
  });

  group('Suivi et contenus', () {
    test('suivi avec numéro + téléphone (formats libres)', () async {
      final t = await content.track('lm-2614', '+221 77 123 45 67');
      expect(t.status, 'SHIPPED');
      expect(t.steps.where((s) => s.reached).length, 3);
      expect(() => content.track('LM-2614', '700000000'),
          throwsA(isA<ApiHttpError>()));
    });

    test('FAQ et pages légales du site', () async {
      expect((await content.listFaqs()).length, 9);
      final legal = await content.listLegal();
      expect(legal.map((d) => d.slug), contains('cgv'));
      expect((await content.getLegal('cgv')).bodyHtml, contains('<h2>'));
    });
  });
}
