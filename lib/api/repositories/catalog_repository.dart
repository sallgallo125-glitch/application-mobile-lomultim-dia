import '../../contracts/category.dart';
import '../../contracts/product.dart';
import '../api_client.dart';
import '../errors.dart';

class CatalogRepository {
  CatalogRepository(this._apiClient);

  final ApiClient _apiClient;

  /// How long each kind of catalogue data is served from the device before
  /// being refreshed. Price and stock live on the product detail, kept the
  /// shortest; the cart and checkout are never cached (the server prices
  /// them).
  static const categoriesMaxAge = Duration(hours: 6);
  static const productsMaxAge = Duration(minutes: 10);
  static const productMaxAge = Duration(minutes: 1);

  Future<List<ProductSummary>> listProducts({void Function()? onRefreshed}) =>
      _getList('/api/v1/products', ProductSummary.fromJson,
          maxAge: productsMaxAge, onRefreshed: onRefreshed);
  Future<List<Category>> listCategories({void Function()? onRefreshed}) =>
      _getList('/api/v1/categories', Category.fromJson,
          maxAge: categoriesMaxAge, onRefreshed: onRefreshed);

  /// Products resembling a photo (JPEG bytes, base64). Returns the detected
  /// department name and the matching products.
  Future<({String detected, List<ProductSummary> products})> searchByImage(
      String imageBase64) async {
    const path = '/api/v1/search/image';
    final raw = await _apiClient.post(path, {'imageBase64': imageBase64});
    if (raw is! Map<String, dynamic> || raw['data'] is! List<dynamic>) {
      throw ApiParseError(path, 'expected {"data": [...]}, got $raw');
    }
    try {
      final meta = raw['meta'] as Map<String, dynamic>? ?? const {};
      return (
        detected: meta['detected'] as String? ?? '',
        products: (raw['data'] as List<dynamic>)
            .map((p) => ProductSummary.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
    } catch (error) {
      throw ApiParseError(path, error);
    }
  }

  Future<ProductDetail> getProduct(String id,
      {void Function()? onRefreshed}) async {
    final path = '/api/v1/products/$id';
    final raw = await _apiClient.getCached(path,
        maxAge: productMaxAge, onRefreshed: onRefreshed);
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>) {
      throw ApiParseError(path, 'expected product envelope, got $raw');
    }
    try {
      return ProductDetail.fromJson(raw['data'] as Map<String, dynamic>);
    } catch (error) {
      throw ApiParseError(path, error);
    }
  }

  /// Publishes the signed-in customer's review of a product.
  Future<ProductReview> submitReview(String productId,
      {required String author,
      required int rating,
      required String comment}) async {
    final path = '/api/v1/products/$productId/reviews';
    final raw = await _apiClient.post(
        path, {'author': author, 'rating': rating, 'comment': comment});
    _apiClient.forget('/api/v1/products/$productId');
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>) {
      throw ApiParseError(path, 'expected review envelope, got $raw');
    }
    try {
      return ProductReview.fromJson(raw['data'] as Map<String, dynamic>);
    } catch (error) {
      throw ApiParseError(path, error);
    }
  }

  Future<List<T>> _getList<T>(
      String path, T Function(Map<String, dynamic>) fromJson,
      {required Duration maxAge, void Function()? onRefreshed}) async {
    final raw = await _apiClient.getCached(path,
        maxAge: maxAge, onRefreshed: onRefreshed);
    if (raw is! Map<String, dynamic> || raw['data'] is! List<dynamic>) {
      throw ApiParseError(path, 'expected {"data": [...]}, got $raw');
    }
    try {
      return (raw['data'] as List<dynamic>)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw ApiParseError(path, error);
    }
  }
}
