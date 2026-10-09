import '../../contracts/content.dart';
import '../../contracts/gift_card.dart';
import '../../contracts/loyalty.dart';
import '../api_client.dart';
import '../errors.dart';

/// Unwraps `{"data": ...}` and maps it, turning shape errors into
/// [ApiParseError] like the other repositories.
Future<T> _data<T>(
    Future<dynamic> response, String path, T Function(dynamic data) map) async {
  final raw = await response;
  if (raw is! Map<String, dynamic> || !raw.containsKey('data')) {
    throw ApiParseError(path, 'expected {"data": ...}, got $raw');
  }
  try {
    return map(raw['data']);
  } catch (error) {
    throw ApiParseError(path, error);
  }
}

List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) =>
    (data as List<dynamic>)
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();

/// Mirrors the site's /v1/loyalty/me/* routes.
class LoyaltyRepository {
  LoyaltyRepository(this._api);
  final ApiClient _api;

  Future<LoyaltyMember> getMember() {
    const path = '/api/v1/loyalty/me';
    return _data(_api.get(path), path,
        (d) => LoyaltyMember.fromJson(d as Map<String, dynamic>));
  }

  Future<LoyaltyQrToken> createQrToken() {
    const path = '/api/v1/loyalty/me/qr';
    return _data(_api.post(path), path,
        (d) => LoyaltyQrToken.fromJson(d as Map<String, dynamic>));
  }

  Future<List<LoyaltyMovement>> listMovements() {
    const path = '/api/v1/loyalty/me/movements';
    return _data(
        _api.get(path), path, (d) => _list(d, LoyaltyMovement.fromJson));
  }

  Future<List<LoyaltyReward>> listRewards() {
    const path = '/api/v1/loyalty/me/exchange';
    return _data(_api.get(path), path, (d) => _list(d, LoyaltyReward.fromJson));
  }

  /// [points] is only used for free-value vouchers.
  Future<LoyaltyVoucher> convert(String rewardId, {int? points}) {
    const path = '/api/v1/loyalty/me/conversions';
    return _data(
        _api.post(
            path, {'rewardId': rewardId, if (points != null) 'points': points}),
        path,
        (d) => LoyaltyVoucher.fromJson(d as Map<String, dynamic>));
  }

  Future<LoyaltyReferrals> getReferrals() {
    const path = '/api/v1/loyalty/me/referrals';
    return _data(_api.get(path), path,
        (d) => LoyaltyReferrals.fromJson(d as Map<String, dynamic>));
  }

  Future<LoyaltyChallenges> getChallenges() {
    const path = '/api/v1/loyalty/me/challenges';
    return _data(_api.get(path), path,
        (d) => LoyaltyChallenges.fromJson(d as Map<String, dynamic>));
  }
}

/// Mirrors the site's /v1/gift-cards routes.
class GiftCardRepository {
  GiftCardRepository(this._api);
  final ApiClient _api;

  Future<List<GiftCard>> listMine() {
    const path = '/api/v1/gift-cards/mine';
    return _data(_api.get(path), path, (d) => _list(d, GiftCard.fromJson));
  }

  Future<GiftCardBalance> checkBalance(String code) {
    final path =
        '/api/v1/gift-cards/${Uri.encodeComponent(code.trim())}/balance';
    return _data(_api.get(path), path,
        (d) => GiftCardBalance.fromJson(d as Map<String, dynamic>));
  }

  Future<GiftCard> buy({
    required int amountXof,
    required GiftCardDelivery delivery,
    required String recipientName,
    String? message,
    String? buyerName,
    String? buyerPhone,
  }) {
    const path = '/api/v1/gift-cards';
    return _data(
        _api.post(path, {
          // Guest purchase: the buyer must be identified (spec §5.10.1).
          if (buyerName != null) 'buyerName': buyerName,
          if (buyerPhone != null) 'buyerPhone': buyerPhone,
          'amountXof': amountXof,
          'format': delivery.code,
          'recipientName': recipientName,
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        }),
        path,
        (d) => GiftCard.fromJson(d as Map<String, dynamic>));
  }

  Future<GiftCard> setSuspended(String id, bool suspended) {
    final path =
        '/api/v1/gift-cards/mine/$id/${suspended ? 'suspension' : 'reactivation'}';
    return _data(_api.post(path), path,
        (d) => GiftCard.fromJson(d as Map<String, dynamic>));
  }
}

/// FAQ, legal pages and order tracking.
class ContentRepository {
  ContentRepository(this._api);
  final ApiClient _api;

  Future<List<Faq>> listFaqs() {
    const path = '/api/v1/content/faq';
    return _data(_api.get(path), path, (d) => _list(d, Faq.fromJson));
  }

  Future<List<LegalDocument>> listLegal() {
    const path = '/api/v1/content/legal';
    return _data(_api.get(path), path, (d) => _list(d, LegalDocument.fromJson));
  }

  Future<LegalDocument> getLegal(String slug) {
    final path = '/api/v1/content/legal/$slug';
    return _data(_api.get(path), path,
        (d) => LegalDocument.fromJson(d as Map<String, dynamic>));
  }

  Future<OrderTracking> track(String orderNumber, String phone) {
    const path = '/api/v1/delivery/tracking';
    return _data(_api.post(path, {'orderNumber': orderNumber, 'phone': phone}),
        path, (d) => OrderTracking.fromJson(d as Map<String, dynamic>));
  }
}
