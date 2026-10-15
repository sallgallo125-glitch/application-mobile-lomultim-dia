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
    expect(find.text('ajouté au panier'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(cartBadge('1'), findsOneWidget, reason: 'badge du panier');
    await tester.tap(find.text('ajouté au panier'));
    await settle(tester);
    expect(find.textContaining('HP ProBook 450 G10'), findsOneWidget);
    expect(find.text('Continuer la commande'), findsOneWidget);
    expect(find.text('ajouté au panier'), findsNothing);

    // Increase the item from the cart after opening it via the toast.
    await tester.tap(find.byTooltip('Augmenter'));
    await settle(tester);
    expect(cartBadge('2'), findsOneWidget);

    await open(tester, '/panier');
    expect(find.textContaining('HP ProBook 450 G10'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Continuer la commande'), findsOneWidget);
    expect(find.text('Total estimé'), findsOneWidget);
    expect(find.text('Utiliser mes points LO+'), findsOneWidget);
    expect(
      find.text(
          'Connectez-vous à votre compte LO+ pour utiliser vos points sur cette commande.'),
      findsOneWidget,
    );
    expect(find.text('Afficher le détail'), findsOneWidget);
    expect(find.text('Sous-total (2 articles)'), findsNothing);
    await tester.tap(find.text('Afficher le détail'));
    await tester.pumpAndSettle();
    expect(find.text('Masquer le détail'), findsOneWidget);
    expect(find.text('Sous-total (2 articles)'), findsOneWidget);
    expect(find.text('Avec un compte LO+'), findsOneWidget);
    expect(find.text('Connectez-vous pour les cumuler'), findsOneWidget);
    expect(find.textContaining('/ unité'), findsOneWidget);

    // − goes back to 1, delete empties the cart.
    await tester.tap(find.byIcon(Icons.remove));
    await settle(tester);
    expect(cartBadge('2'), findsNothing);
    await tester.tap(find.byTooltip('Retirer l’article'));
    await settle(tester);
    expect(find.textContaining('Votre panier est vide'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(find.textContaining('HP ProBook 450 G10'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer l’article'));
    await settle(tester);
    expect(find.textContaining('Votre panier est vide'), findsOneWidget);
    expect(find.text('Article retiré du panier.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Article retiré du panier.'), findsNothing);
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
    await tester.tap(find.text('Ajouter').first);
    await settle(tester);
    // The shop has no header cart any more: the bottom bar's tab counts it.
    expect(find.bySemanticsLabel('Onglet panier, 1 article'), findsOneWidget);
    appRouter.go('/');
    await settle(tester);
  });

  testWidgets('quantité visible seulement après l’ajout', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    await open(tester, '/produit/p-028'); // ramette A4, 19 500 FCFA
    // Before adding: no −/+, just the price and "Ajouter au panier".
    expect(find.byTooltip('Augmenter la quantité'), findsNothing);
    expect(find.text('19 500 FCFA'), findsWidgets);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Ajouter au panier'));
    await settle(tester);
    // After: "Dans le panier − 1 +", then up to 3 cartons.
    expect(find.text('Dans le panier'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Augmenter la quantité'));
      await settle(tester);
    }
    expect(cartBadge('3'), findsOneWidget);
    expect(find.text('58 500 FCFA'), findsOneWidget);
    // "−" down to 0 removes it: back to "Ajouter au panier".
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Diminuer la quantité'));
      await settle(tester);
    }
    await tester.tap(find.byTooltip('Retirer du panier'));
    await settle(tester);
    expect(find.widgetWithText(ElevatedButton, 'Ajouter au panier'),
        findsOneWidget);
    appRouter.go('/');
    await settle(tester);
  });
}
