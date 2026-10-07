import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/contracts/product.dart';
import 'package:mobile_app/features/catalog/shop_filters.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/mocks/data/products_mock_data.dart';
import 'package:mobile_app/navigation/app_router.dart';
import 'package:mobile_app/widgets/commerce/shop_filters_sheet.dart';

/// Shop "Filtres" page: live count, apply, removable chips, clear.
void main() {
  final products = mockProducts.map((p) => ProductSummary.fromJson(p)).toList();

  test('filtres combinés et tri', () {
    final hp =
        applyShopFilters(products, const ShopFilterState(brands: {'HP'}));
    expect(hp, isNotEmpty);
    expect(hp.every((p) => p.brand == 'HP'), isTrue);

    final cheapPromo = applyShopFilters(
        products,
        const ShopFilterState(
            maxPriceXof: 200000,
            promoOnly: true,
            sort: CatalogSort.priceAscending));
    expect(cheapPromo.every((p) => p.priceXof <= 200000), isTrue);
    expect(
        cheapPromo.every((p) =>
            p.compareAtPriceXof != null && p.compareAtPriceXof! > p.priceXof),
        isTrue);
    for (var i = 1; i < cheapPromo.length; i++) {
      expect(cheapPromo[i].priceXof >= cheapPromo[i - 1].priceXof, isTrue);
    }
    expect(
        const ShopFilterState(brands: {'HP', 'Samsung'}, inStockOnly: true)
            .activeCount,
        3);
  });

  testWidgets('page Filtres : compteur, application, puces', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: LoMultimediaApp(useGoogleFonts: false)));
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    appRouter.go('/boutique');
    await settle();
    await tester.tap(find.text('Filtres'));
    await settle();
    expect(find.text('Voir ${products.length} produits'), findsOneWidget);

    final hpCount = products.where((p) => p.brand == 'HP').length;
    final hpBox = find.widgetWithText(CheckboxListTile, 'HP');
    await tester.scrollUntilVisible(hpBox, 200,
        scrollable: find
            .descendant(
                of: find.byType(ShopFiltersSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(hpBox);
    await tester.pump();
    await tester.drag(hpBox, const Offset(0, -200));
    await tester.pump();
    await tester.tap(
        find.descendant(of: hpBox, matching: find.byType(Checkbox)));
    await settle();
    await settle();
    expect(find.text('Voir $hpCount produits'), findsOneWidget);

    await tester.tap(find.text('Voir $hpCount produits'));
    await settle();
    expect(find.text('Filtres · 1'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'HP'), findsOneWidget);

    // Remove the chip: back to every product.
    await tester.tap(find.byTooltip('Retirer'));
    await settle();
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);

    appRouter.go('/');
    await settle();
  });
}
