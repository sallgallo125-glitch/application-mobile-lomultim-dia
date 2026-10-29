import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/product.dart';
import '../persistence.dart';

enum CatalogSort {
  relevance('Pertinence'),
  priceAscending('Prix croissant'),
  priceDescending('Prix décroissant'),
  rating('Mieux notés'),
  promotion('Meilleures promos');

  const CatalogSort(this.label);
  final String label;
}

/// Everything the shop "Filtres" page can set.
class ShopFilterState {
  const ShopFilterState({
    this.sort = CatalogSort.relevance,
    this.categoryIds = const {},
    this.brands = const {},
    this.minPriceXof,
    this.maxPriceXof,
    this.minRating,
    this.inStockOnly = false,
    this.promoOnly = false,
  });

  final CatalogSort sort;
  final Set<String> categoryIds;
  final Set<String> brands;
  final int? minPriceXof;
  final int? maxPriceXof;
  final int? minRating;
  final bool inStockOnly;
  final bool promoOnly;

  /// Number of active filters (sort excluded), shown on the "Filtres" button.
  int get activeCount =>
      categoryIds.length +
      brands.length +
      (minPriceXof != null || maxPriceXof != null ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (inStockOnly ? 1 : 0) +
      (promoOnly ? 1 : 0);

  ShopFilterState copyWith({
    CatalogSort? sort,
    Set<String>? categoryIds,
    Set<String>? brands,
    int? Function()? minPriceXof,
    int? Function()? maxPriceXof,
    int? Function()? minRating,
    bool? inStockOnly,
    bool? promoOnly,
  }) =>
      ShopFilterState(
        sort: sort ?? this.sort,
        categoryIds: categoryIds ?? this.categoryIds,
        brands: brands ?? this.brands,
        minPriceXof: minPriceXof == null ? this.minPriceXof : minPriceXof(),
        maxPriceXof: maxPriceXof == null ? this.maxPriceXof : maxPriceXof(),
        minRating: minRating == null ? this.minRating : minRating(),
        inStockOnly: inStockOnly ?? this.inStockOnly,
        promoOnly: promoOnly ?? this.promoOnly,
      );

  /// Same sort, every filter removed.
  ShopFilterState cleared() => ShopFilterState(sort: sort);

  Map<String, dynamic> toJson() => {
        'sort': sort.name,
        'categoryIds': categoryIds.toList(),
        'brands': brands.toList(),
        'minPriceXof': minPriceXof,
        'maxPriceXof': maxPriceXof,
        'minRating': minRating,
        'inStockOnly': inStockOnly,
        'promoOnly': promoOnly,
      };

  factory ShopFilterState.fromJson(Map<String, dynamic> j) => ShopFilterState(
        sort: CatalogSort.values.firstWhere((s) => s.name == j['sort'],
            orElse: () => CatalogSort.relevance),
        categoryIds: {
          ...(j['categoryIds'] as List? ?? const []).cast<String>()
        },
        brands: {...(j['brands'] as List? ?? const []).cast<String>()},
        minPriceXof: (j['minPriceXof'] as num?)?.toInt(),
        maxPriceXof: (j['maxPriceXof'] as num?)?.toInt(),
        minRating: (j['minRating'] as num?)?.toInt(),
        inStockOnly: j['inStockOnly'] as bool? ?? false,
        promoOnly: j['promoOnly'] as bool? ?? false,
      );
}

bool _hasPromo(ProductSummary p) =>
    p.compareAtPriceXof != null && p.compareAtPriceXof! > p.priceXof;

/// Products matching [f] (and [query] on name/brand), sorted by [f.sort].
List<ProductSummary> applyShopFilters(
    List<ProductSummary> source, ShopFilterState f,
    {String query = '', bool sort = true}) {
  final q = query.trim().toLowerCase();
  final items = source
      .where((p) =>
          (f.categoryIds.isEmpty || f.categoryIds.contains(p.categoryId)) &&
          (f.brands.isEmpty || f.brands.contains(p.brand)) &&
          (f.minPriceXof == null || p.priceXof >= f.minPriceXof!) &&
          (f.maxPriceXof == null || p.priceXof <= f.maxPriceXof!) &&
          (f.minRating == null || (p.rating ?? 0) >= f.minRating!) &&
          (!f.inStockOnly || p.inStock) &&
          (!f.promoOnly || _hasPromo(p)) &&
          (q.isEmpty || '${p.name} ${p.brand}'.toLowerCase().contains(q)))
      .toList();
  if (!sort) return items;
  switch (f.sort) {
    case CatalogSort.priceAscending:
      items.sort((a, b) => a.priceXof.compareTo(b.priceXof));
    case CatalogSort.priceDescending:
      items.sort((a, b) => b.priceXof.compareTo(a.priceXof));
    case CatalogSort.rating:
      items.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    case CatalogSort.promotion:
      int saving(ProductSummary p) =>
          (p.compareAtPriceXof ?? p.priceXof) - p.priceXof;
      items.sort((a, b) => saving(b).compareTo(saving(a)));
    case CatalogSort.relevance:
      break;
  }
  return items;
}

/// Shop filters, kept on the device between visits and launches.
final shopFiltersProvider =
    StateNotifierProvider<StateController<ShopFilterState>, ShopFilterState>(
        (ref) {
  const key = 'shop_filters';
  final controller = StateController<ShopFilterState>(readStored(ref, key,
          (json) => ShopFilterState.fromJson(json as Map<String, dynamic>)) ??
      const ShopFilterState());
  controller.addListener((next) => writeStored(ref, key, next.toJson()),
      fireImmediately: false);
  return controller;
});
