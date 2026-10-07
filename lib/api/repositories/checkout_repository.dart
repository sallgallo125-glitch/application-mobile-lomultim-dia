import '../../contracts/account.dart';
import '../api_client.dart';
import '../errors.dart';

class CheckoutRepository {
  CheckoutRepository(this._api);
  final ApiClient _api;
  Future<OrderSummary> createOrder(
      {required String deliveryMethod,
      required String zoneId,
      required String payment,
      String? promoCode,
      int pointsToUse = 0,
      String? giftCardCode,
      String? giftCardOtp,
      required String name,
      required String phone,
      String? address,
      bool guest = false}) async {
    const path = '/api/v1/checkout';
    final raw = await _api.post(path, {
      // Guest checkout: no account needed. With the real API the customer is
      // identified by their session token instead.
      'customerType': guest ? 'GUEST' : 'MEMBER',
      'deliveryMethodCode': deliveryMethod,
      'zoneId': zoneId,
      'paymentMethod': payment,
      if (promoCode != null && promoCode.trim().isNotEmpty)
        'promoCode': promoCode.trim(),
      if (pointsToUse > 0) 'pointsToUse': pointsToUse,
      if (giftCardCode != null && giftCardCode.trim().isNotEmpty) ...{
        'giftCardCode': giftCardCode.trim(),
        'giftCardOtp': giftCardOtp,
      },
      'name': name,
      'phone': phone,
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
    });
    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>)
      throw ApiParseError(path, 'invalid checkout response');
    return OrderSummary.fromJson(raw['data'] as Map<String, dynamic>);
  }
}
