import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/repositories/catalog_repository.dart';
import '../../contracts/category.dart';
import '../../contracts/product.dart';
import '../home/home_providers.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
    (ref) => CatalogRepository(ref.watch(apiClientProvider)));

// Catalogue data is shown from the device cache first, then refreshed in the
// background; `invalidateSelf` re-reads the fresh copy once it has arrived.
final productsProvider = FutureProvider<List<ProductSummary>>((ref) => ref
    .watch(catalogRepositoryProvider)
    .listProducts(onRefreshed: ref.invalidateSelf));
final categoriesProvider = FutureProvider<List<Category>>((ref) => ref
    .watch(catalogRepositoryProvider)
    .listCategories(onRefreshed: ref.invalidateSelf));
final productProvider = FutureProvider.family<ProductDetail, String>(
    (ref, id) => ref
        .watch(catalogRepositoryProvider)
        .getProduct(id, onRefreshed: ref.invalidateSelf));

/// Starts loading a product's page before it opens (finger down on a card),
/// so it is usually ready by the time the page appears.
void prefetchProduct(BuildContext context, String id) =>
    ProviderScope.containerOf(context, listen: false).read(productProvider(id));
