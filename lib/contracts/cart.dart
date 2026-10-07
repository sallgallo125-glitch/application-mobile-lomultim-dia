class CartItem {
  const CartItem(
      {required this.id,
      required this.productId,
      required this.name,
      required this.quantity,
      required this.unitPriceXof,
      this.imageUrl,
      this.categoryId});
  final String id;
  final String productId;
  final String name;
  final int quantity;
  final int unitPriceXof;
  final String? imageUrl;
  final String? categoryId;
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPriceXof: (json['unitPriceXof'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      categoryId: json['categoryId'] as String?);
}

class Cart {
  const Cart(
      {required this.items,
      required this.subtotalXof,
      required this.deliveryFeeXof,
      required this.totalXof});
  final List<CartItem> items;
  final int subtotalXof;
  final int deliveryFeeXof;
  final int totalXof;
  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
      items: (json['items'] as List<dynamic>)
          .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotalXof: (json['subtotalXof'] as num).toInt(),
      deliveryFeeXof: (json['deliveryFeeXof'] as num).toInt(),
      totalXof: (json['totalXof'] as num).toInt());
}
