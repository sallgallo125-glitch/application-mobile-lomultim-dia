import '../../contracts/category.dart';
import '../../contracts/product.dart';
import '../api_client.dart';
import '../errors.dart';

class CatalogRepository {
  CatalogRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ProductSummary>> listProducts() =>
      _getList('/api/v1/products', ProductSummary.fromJson);
  Future<List<Category>> listCategories() =>
      _getList('/api/v1/categories', Category.fromJson);

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

  Future<ProductDetail> getProduct(String id) async {
    final path = '/api/v1/products/$id';
    final raw = await _apiClient.get(path);
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>)
      throw ApiParseError(path, 'expected product envelope, got $raw');
    try {
      return ProductDetail.fromJson(raw['data'] as Map<String, dynamic>);
    } catch (error) {
      throw ApiParseError(path, error);
    }
  }

  Future<List<T>> _getList<T>(
      String path, T Function(Map<String, dynamic>) fromJson) async {
    final raw = await _apiClient.get(path);
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
