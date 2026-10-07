import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/features/cart/cart_providers.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Real taps through the 3-step checkout, down to the confirmation page.
void main() {
  testWidgets('paiement en 3 étapes jusqu’à la confirmation', (tester) async {
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
    c.read(sessionUserProvider.notifier).state =
        const SessionUser(name: 'Aissatou Diop', phone: '77 123 45 67');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const LoMultimediaApp(useGoogleFonts: false)));
    await tester.runAsync(() => c.read(cartActionsProvider).add('p-005'));
    appRouter.go('/commande/paiement');
    await settle();

    // Step 1: the address is required for home delivery.
    final next = find.widgetWithText(ElevatedButton, 'Continuer');
    await tester.tap(next);
    await settle();
    expect(find.text('Indiquez votre adresse de livraison.'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Adresse de livraison'), 'Plateau, rue 10');
    await tester.tap(next);
    await settle();

    // Step 2: payment — Wave is selectable.
    expect(find.text('Moyen de paiement'), findsOneWidget);
    await tester.ensureVisible(find.text('Wave'));
    await tester.tap(find.text('Wave'));
    await settle();
    await tester.tap(next);
    await settle();

    // Step 3: recap with "Modifier" links, then confirm.
    expect(find.text('Modifier'), findsNWidgets(2));
    expect(find.textContaining('Plateau, rue 10'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer'));
    await settle();
    // Wave payment request (simulated), then the order is paid.
    expect(find.text('Paiement Wave'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Payer'));
    await settle();
    expect(find.text('Commande confirmée'), findsOneWidget);
    expect(find.text('Payé par Wave'), findsOneWidget);
    appRouter.go('/');
    await settle();
  });
}
