import '../../contracts/cart.dart';
import '../api_client.dart';
import '../errors.dart';

class CartRepository {
  CartRepository(this._api);
  final ApiClient _api;
  Future<Cart> getCart() => _cart(_api.get('/api/v1/cart'), '/api/v1/cart');
  Future<Cart> addItem(String productId,
          {String? variantId,
          Iterable<String> addonIds = const [],
          Map<String, String> options = const {},
          int quantity = 1}) =>
      _cart(
          _api.post('/api/v1/cart/items', {
            'productId': productId,
            if (quantity != 1) 'quantity': quantity,
            if (options.isNotEmpty) 'options': options,
            if (variantId != null) 'variantId': variantId,
            if (addonIds.isNotEmpty) 'addonIds': addonIds.toList(),
          }),
          '/api/v1/cart/items');
  Future<Cart> updateItem(String id, int quantity) => _cart(
      _api.patch('/api/v1/cart/items/$id', {'quantity': quantity}),
      '/api/v1/cart/items/$id');
  Future<Cart> removeItem(String id) =>
      _cart(_api.delete('/api/v1/cart/items/$id'), '/api/v1/cart/items/$id');
  Future<Cart> _cart(Future<dynamic> response, String path) async {
    final raw = await response;
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>)
      throw ApiParseError(path, 'invalid cart');
    return Cart.fromJson(raw['data'] as Map<String, dynamic>);
  }
}
