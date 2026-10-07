import '../../contracts/account.dart';
import '../api_client.dart';
import '../errors.dart';

class AccountRepository {
  AccountRepository(this._api);
  final ApiClient _api;
  Future<AccountSummary> getSummary() async {
    final raw = await _api.get('/api/v1/account/summary');
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>)
      throw ApiParseError('/api/v1/account/summary', 'invalid account');
    return AccountSummary.fromJson(raw['data'] as Map<String, dynamic>);
  }

  Future<List<OrderSummary>> listOrders() async {
    final raw = await _api.get('/api/v1/orders');
    if (raw is! Map<String, dynamic> || raw['data'] is! List<dynamic>)
      throw ApiParseError('/api/v1/orders', 'invalid orders');
    return (raw['data'] as List)
        .map((item) => OrderSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
