/// LO+ status, as on the site: the tier comes from eligible purchases over
/// the last 12 months (see lib/utils/loyalty.dart).
class LoyaltySummary {
  const LoyaltySummary(
      {required this.tierCode,
      required this.points,
      required this.spend12MonthsXof});
  final String tierCode;
  final int points;
  final int spend12MonthsXof;
  factory LoyaltySummary.fromJson(Map<String, dynamic> json) => LoyaltySummary(
      tierCode: json['tierCode'] as String,
      points: (json['points'] as num).toInt(),
      spend12MonthsXof: (json['spend12MonthsXof'] as num).toInt());
}

class AccountSummary {
  const AccountSummary(
      {required this.name,
      required this.phone,
      required this.ordersCount,
      required this.loyalty});
  final String name;
  final String phone;
  final int ordersCount;
  final LoyaltySummary loyalty;
  factory AccountSummary.fromJson(Map<String, dynamic> json) => AccountSummary(
      name: json['name'] as String,
      phone: json['phone'] as String,
      ordersCount: (json['ordersCount'] as num).toInt(),
      loyalty:
          LoyaltySummary.fromJson(json['loyalty'] as Map<String, dynamic>));
}

class OrderLineSummary {
  const OrderLineSummary({
    required this.name,
    this.imageUrl,
    this.categoryId,
  });

  final String name;
  final String? imageUrl;
  final String? categoryId;

  factory OrderLineSummary.fromJson(Map<String, dynamic> json) =>
      OrderLineSummary(
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String?,
        categoryId: json['categoryId'] as String?,
      );
}

class OrderSummary {
  const OrderSummary(
      {required this.id,
      required this.number,
      required this.createdAt,
      required this.status,
      required this.totalXof,
      this.items = const [],
      this.deliveryInfo,
      this.pointsToEarn = 0,
      this.pointsDiscountXof = 0,
      this.giftCardAppliedXof = 0,
      this.deliveryMethodCode,
      this.paymentMethod,
      this.guest = false,
      this.pointsIfMemberXof = 0,
      this.phone,
      int? amountDueXof})
      : amountDueXof = amountDueXof ?? totalXof;
  final String id;
  final String number;
  final String createdAt;
  final String status;
  final int totalXof;
  final List<OrderLineSummary> items;
  final String? deliveryInfo;

  /// LO+ points credited for this order (computed by the server).
  final int pointsToEarn;

  /// Paid with LO+ points / gift card; [amountDueXof] is what remains.
  final int pointsDiscountXof;
  final int giftCardAppliedXof;
  final int amountDueXof;
  final String? deliveryMethodCode;
  final String? paymentMethod;

  /// Ordered without an account: no LO+ points, tracked by number + phone.
  final bool guest;

  /// Points this order would have earned with a LO+ account (guest only).
  final int pointsIfMemberXof;

  /// Phone given at checkout (used to track the order).
  final String? phone;
  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
      id: json['id'] as String,
      number: json['number'] as String,
      createdAt: json['createdAt'] as String,
      status: json['status'] as String,
      totalXof: (json['totalXof'] as num).toInt(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) =>
              OrderLineSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      deliveryInfo: json['deliveryInfo'] as String?,
      pointsToEarn: (json['pointsToEarn'] as num?)?.toInt() ?? 0,
      pointsDiscountXof: (json['pointsDiscountXof'] as num?)?.toInt() ?? 0,
      giftCardAppliedXof: (json['giftCardAppliedXof'] as num?)?.toInt() ?? 0,
      amountDueXof: (json['amountDueXof'] as num?)?.toInt(),
      deliveryMethodCode: json['deliveryMethodCode'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      guest: json['customerType'] == 'GUEST',
      pointsIfMemberXof: (json['pointsIfMember'] as num?)?.toInt() ?? 0,
      phone: json['phone'] as String?);
}
