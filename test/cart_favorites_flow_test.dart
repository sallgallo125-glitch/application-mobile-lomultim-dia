import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Real taps through the app: product page → cart, and favourites from the
/// product page and from the shop list.
void main() {
  Future<void> settle(WidgetTester tester) async {
    // Mock API latency is 350 ms; shimmer animates forever, so no pumpAndSettle.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> open(WidgetTester tester, String route) async {
    appRouter.go(route);
    await settle(tester);
  }

  /// Count badge shown on the header's "Panier" button.
  Finder cartBadge(String count) => find.descendant(
      of: find.bySemanticsLabel(RegExp('Panier')), matching: find.text(count));

  testWidgets('ajouter au panier depuis la fiche produit', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    await open(tester, '/produit/p-001');
    expect(find.textContaining('HP ProBook 450 G10'), findsWidgets);

    // The buy bar is pinned at the bottom: no scrolling needed.
    final addButton = find.widgetWithText(ElevatedButton, 'Ajouter au panier');
    expect(addButton.hitTestable(), findsOneWidget);
    await tester.tap(addButton);
    await settle(tester);
    expect(find.text('Produit ajouté au panier'), findsOneWidget);
    expect(find.text('Voir le panier'), findsOneWidget);
    expect(cartBadge('1'), findsOneWidget, reason: 'badge du panier');
    // The confirmation closes by itself (it has an action, so it must not
    // persist).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Produit ajouté au panier'), findsNothing);

    // Twice → quantity 2, same line.
    await tester.tap(addButton);
    await settle(tester);
    expect(cartBadge('2'), findsOneWidget);

    await open(tester, '/panier');
    expect(find.textContaining('HP ProBook 450 G10'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    // − goes back to 1, delete empties the cart.
    await tester.tap(find.byIcon(Icons.remove));
    await settle(tester);
    expect(cartBadge('2'), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    expect(find.textContaining('Votre panier est vide'), findsOneWidget);
    appRouter.go('/');
    await settle(tester);
  });

  testWidgets('ajouter / retirer un favori', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));

    // From the product page header.
    await open(tester, '/produit/p-001');
    // Heart on the product photo.
    await tester.tap(find.byTooltip('Ajouter aux favoris').first);
    await settle(tester);
    await open(tester, '/favoris');
    expect(find.textContaining('HP ProBook 450 G10'), findsOneWidget);

    // From the heart on the list item: removes it again.
    await tester.tap(find.byTooltip('Retirer des favoris').first);
    await settle(tester);
    expect(find.textContaining('Aucun favori'), findsOneWidget);

    // From the shop list.
    await open(tester, '/boutique');
    await tester.tap(find.byTooltip('Ajouter aux favoris').first);
    await settle(tester);
    await open(tester, '/favoris');
    expect(find.byTooltip('Retirer des favoris'), findsOneWidget);
    appRouter.go('/');
    await settle(tester);
  });

  testWidgets('ajout rapide depuis la boutique', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    await open(tester, '/boutique');
    expect(find.text('Filtres'), findsOneWidget);
    await tester.tap(find.text('+ Ajouter').first);
    await settle(tester);
    expect(cartBadge('1'), findsOneWidget);
    appRouter.go('/');
    await settle(tester);
  });

  testWidgets('quantité choisie sur la fiche produit', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    await open(tester, '/produit/p-028'); // ramette A4: 3 cartons d'un coup
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Augmenter la quantité'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    // 3 × 19 500 FCFA (ramette, carton de 5)
    expect(find.text('58 500 FCFA'), findsOneWidget);
    expect(find.text('Prix total'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Ajouter au panier'));
    await settle(tester);
    expect(cartBadge('3'), findsOneWidget);
    appRouter.go('/');
    await settle(tester);
  });
}
