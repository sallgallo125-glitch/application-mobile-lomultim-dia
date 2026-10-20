import '../../contracts/account.dart';
import '../api_client.dart';
import '../errors.dart';

class AccountRepository {
  AccountRepository(this._api);
  final ApiClient _api;
  Future<AccountSummary> getSummary() async {
    final raw = await _api.get('/api/v1/account/summary');
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>) {
      throw const ApiParseError('/api/v1/account/summary', 'invalid account');
    }
    return AccountSummary.fromJson(raw['data'] as Map<String, dynamic>);
  }

  Future<List<OrderSummary>> listOrders() async {
    final raw = await _api.get('/api/v1/orders');
    if (raw is! Map<String, dynamic> || raw['data'] is! List<dynamic>) {
      throw const ApiParseError('/api/v1/orders', 'invalid orders');
    }
    return (raw['data'] as List)
        .map((item) => OrderSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<OrderDetail> getOrder(String number) async {
    final path = '/api/v1/orders/${Uri.encodeComponent(number)}';
    final raw = await _api.get(path);
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>) {
      throw ApiParseError(path, 'invalid order');
    }
    return OrderDetail.fromJson(raw['data'] as Map<String, dynamic>);
  }

  /// Cancels an order the customer can still cancel; returns it updated.
  Future<OrderDetail> cancelOrder(String number) async {
    final path = '/api/v1/orders/${Uri.encodeComponent(number)}/cancel';
    final raw = await _api.post(path);
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>) {
      throw ApiParseError(path, 'invalid order');
    }
    return OrderDetail.fromJson(raw['data'] as Map<String, dynamic>);
  }
}
