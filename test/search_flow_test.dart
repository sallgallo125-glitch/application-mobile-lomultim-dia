import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';
import 'package:mobile_app/screens/search_screen.dart';

/// Home search bar → search page → suggestion → results → product → back.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  test('recherche sans accents ni majuscules', () {
    expect(normalizeSearch('Téléviseur ÉCRAN'), 'televiseur ecran');
  });

  testWidgets('parcours de recherche depuis l’accueil', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    appRouter.go('/');
    await settle(tester);

    await tester.tap(find.text('Rechercher un produit, une marque…'));
    await settle(tester);
    expect(find.text('Recherche'), findsOneWidget);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Recherches récentes'), findsNothing);

    await tester.tap(find.text('HP'));
    await settle(tester);
    expect(find.textContaining('pour « HP »'), findsOneWidget);
    expect(find.textContaining('ProBook'), findsWidgets);

    await tester.tap(find.textContaining('ProBook').first);
    await settle(tester);
    appRouter.pop();
    await settle(tester);
    expect(find.textContaining('pour « HP »'), findsOneWidget);

    // Clear: suggestions come back, with the recent search.
    await tester.tap(find.byTooltip('Effacer'));
    await settle(tester);
    expect(find.text('Recherches récentes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await settle(tester);
    expect(find.textContaining('Aucun résultat'), findsOneWidget);

    appRouter.go('/');
    await settle(tester);
  });
}
