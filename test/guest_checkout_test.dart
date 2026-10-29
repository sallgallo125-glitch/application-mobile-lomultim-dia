import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/product_screen.dart' show buyBarAddKey;
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/errors.dart';
import 'package:mobile_app/api/repositories/cart_repository.dart';
import 'package:mobile_app/api/repositories/checkout_repository.dart';
import 'package:mobile_app/api/repositories/member_repositories.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Ordering WITHOUT an account: cart → checkout → confirmation → tracking.
void main() {
  group('API invité', () {
    late ApiClient api;
    setUp(() => api = ApiClient(client: MockHttpClient()));

    test('commande invitée : pas de points, pas dans « Mes commandes »',
        () async {
      final loyalty = LoyaltyRepository(api);
      final before = (await loyalty.getMember()).points;
      await CartRepository(api).addItem('p-005'); // 142 000
      final order = await CheckoutRepository(api).createOrder(
          guest: true,
          deliveryMethod: 'PICKUP',
          zoneId: 'dakar-centre',
          payment: 'CASH_ON_DELIVERY',
          name: 'Fatou Sow',
          phone: '77 555 44 33');
      expect(order.guest, isTrue);
      expect(order.pointsToEarn, 0);
      expect(order.pointsIfMemberXof, 14); // 142 000 / 10 000
      expect((await loyalty.getMember()).points, before,
          reason: 'aucun point crédité sur un compte');
    });

    test('un invité ne peut pas payer en points', () async {
      await CartRepository(api).addItem('p-005');
      expect(
          () => CheckoutRepository(api).createOrder(
              guest: true,
              deliveryMethod: 'PICKUP',
              zoneId: 'dakar-centre',
              payment: 'CASH_ON_DELIVERY',
              pointsToUse: 20,
              name: 'Fatou Sow',
              phone: '775554433'),
          throwsA(isA<ApiHttpError>()));
    });
  });

  testWidgets('parcours invité complet jusqu’au suivi', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(signedInProvider), isFalse, reason: 'aucun compte');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const LoMultimediaApp(useGoogleFonts: false)));

    // Add from the product page, then the cart.
    appRouter.go('/produit/p-005');
    await settle();
    await tester.tap(find.byKey(buyBarAddKey));
    await settle();
    await tester.tap(find.text('ajouté au panier'));
    await settle();
    // Guests are invited to sign in to use their LO+ points.
    expect(find.text('Se connecter'), findsOneWidget);
    await tester.tap(find.text('Commander'));
    await settle();

    // Step 1: contact details typed by the guest, pick-up in showroom.
    await tester.enterText(
        find.widgetWithText(TextField, 'Nom complet'), 'Fatou Sow');
    await tester.enterText(
        find.widgetWithText(TextField, 'Téléphone WhatsApp'), '77 555 44 33');
    await tester.ensureVisible(find.textContaining('Retrait').first);
    await tester.tap(find.textContaining('Retrait').first);
    await settle();
    final next = find.widgetWithText(ElevatedButton, 'Continuer');
    await tester.tap(next);
    await settle();
    // Step 2: no "pay with points" for guests; cash on delivery.
    expect(find.text('Payer avec mes points LO+'), findsNothing);
    await tester.tap(next);
    await settle();
    // Step 3: confirm.
    // Recap: no points promised to a guest.
    expect(find.text('Points LO+ gagnés'), findsNothing);
    expect(find.text('Avec un compte LO+'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer'));
    await settle();

    expect(find.text('Commande confirmée'), findsOneWidget);
    expect(find.text('Points LO+ crédités'), findsNothing);
    await tester.scrollUntilVisible(
        find.textContaining('Notez votre numéro'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Notez votre numéro'), findsOneWidget);
    expect(find.text('Créer mon compte gratuitement'), findsOneWidget);
    // Details remembered for the next guest checkout.
    expect(c.read(guestContactProvider)?.name, 'Fatou Sow');
    // Order kept on the device for "Mes commandes" without an account.
    final guestOrders = c.read(guestOrdersProvider);
    expect(guestOrders, hasLength(1));

    // Track the order with its number + phone (pre-filled).
    final trackButton =
        find.widgetWithText(OutlinedButton, 'Suivre ma commande');
    await tester.scrollUntilVisible(trackButton, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(trackButton);
    await settle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Suivre ma commande'));
    await settle();
    expect(find.text('Commande confirmée'), findsWidgets);
    expect(find.textContaining('Aucune commande'), findsNothing);

    // "Mes commandes" without an account lists it, with "Suivre".
    appRouter.go('/commandes');
    await settle();
    expect(find.text(guestOrders.first.number), findsOneWidget);
    expect(find.text('Suivre la commande'), findsOneWidget);

    appRouter.go('/');
    await settle();
  });
}
