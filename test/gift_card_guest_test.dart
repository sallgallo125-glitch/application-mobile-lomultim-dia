import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Buying a gift card without an account: buyer name + phone required.
void main() {
  testWidgets('carte cadeau achetée sans compte', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    appRouter.go('/carte-cadeau');
    await settle();

    Finder field(String label) => find.widgetWithText(TextField, label);
    Future<void> type(String label, String text) async {
      await tester.scrollUntilVisible(field(label), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(field(label), text);
    }
    await type('Nom du bénéficiaire', 'Awa Ndiaye');
    final buy = find.widgetWithText(ElevatedButton, 'Offrir cette carte');
    await tester.scrollUntilVisible(buy, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(buy);
    await settle();
    // No silent redirect to the login page: the buyer is asked instead.
    expect(find.textContaining('acheteur de la carte'), findsOneWidget);

    await type('Votre nom', 'Fatou Sow');
    await type('Votre téléphone', '77 555 44 33');
    // Typing then clearing a custom amount keeps a valid amount.
    await type('Autre montant (FCFA)', '5');
    await type('Autre montant (FCFA)', '');
    await tester.scrollUntilVisible(buy, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(buy);
    await settle();
    expect(find.text('Carte cadeau créée'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await settle();
    appRouter.go('/');
    await settle();
  });
}
