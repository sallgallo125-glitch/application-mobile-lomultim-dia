import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/repositories/catalog_repository.dart';
import '../../contracts/category.dart';
import '../../contracts/product.dart';
import '../home/home_providers.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
    (ref) => CatalogRepository(ref.watch(apiClientProvider)));
final productsProvider = FutureProvider<List<ProductSummary>>(
    (ref) => ref.watch(catalogRepositoryProvider).listProducts());
final categoriesProvider = FutureProvider<List<Category>>(
    (ref) => ref.watch(catalogRepositoryProvider).listCategories());
final productProvider = FutureProvider.family<ProductDetail, String>(
    (ref, id) => ref.watch(catalogRepositoryProvider).getProduct(id));
