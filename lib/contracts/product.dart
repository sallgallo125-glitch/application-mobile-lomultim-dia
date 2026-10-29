/// Mirrors ../mobile-app/src/contracts/product.ts (ProductSummary slice only
/// — ProductDetail is out of scope until the Produit/Boutique screens land).
enum ProductBadge { promo, newItem, top, stock }

ProductBadge _productBadgeFromJson(String value) {
  switch (value) {
    case 'promo':
      return ProductBadge.promo;
    case 'new':
      return ProductBadge.newItem;
    case 'top':
      return ProductBadge.top;
    case 'stock':
      return ProductBadge.stock;
    default:
      throw FormatException('Unknown product badge: $value');
  }
}

class ProductSummary {
  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final int priceXof;
  final int? compareAtPriceXof;
  final String? imageUrl;
  final String? secondaryImageUrl;
  final double? rating;
  final int? reviewCount;
  final bool inStock;
  final List<ProductBadge> badges;

  const ProductSummary({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.priceXof,
    this.compareAtPriceXof,
    this.imageUrl,
    this.secondaryImageUrl,
    this.rating,
    this.reviewCount,
    required this.inStock,
    required this.badges,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    final imagesList = (json['images'] as List<dynamic>?)?.cast<String>();
    final mainImage = json['imageUrl'] as String? ??
        (imagesList != null && imagesList.isNotEmpty ? imagesList.first : null);
    String? secImage = json['secondaryImageUrl'] as String?;
    if (secImage == null && imagesList != null && imagesList.length > 1) {
      secImage = imagesList[1];
    }
    return ProductSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String,
      categoryId: json['categoryId'] as String,
      priceXof: (json['priceXof'] as num).toInt(),
      compareAtPriceXof: (json['compareAtPriceXof'] as num?)?.toInt(),
      imageUrl: mainImage,
      secondaryImageUrl: secImage,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      inStock: json['inStock'] as bool,
      badges: ((json['badges'] as List<dynamic>?) ?? const [])
          .map((badge) => _productBadgeFromJson(badge as String))
          .toList(),
    );
  }
}

class ProductVariant {
  const ProductVariant(
      {required this.id,
      required this.label,
      this.priceDeltaXof,
      required this.inStock});
  final String id;
  final String label;
  final int? priceDeltaXof;
  final bool inStock;
  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
      id: json['id'] as String,
      label: json['label'] as String,
      priceDeltaXof: (json['priceDeltaXof'] as num?)?.toInt(),
      inStock: json['inStock'] as bool);
}

class ProductAddon {
  const ProductAddon(
      {required this.id,
      required this.name,
      required this.priceXof,
      this.required = false});
  final String id;
  final String name;
  final int priceXof;
  final bool required;
  factory ProductAddon.fromJson(Map<String, dynamic> json) => ProductAddon(
      id: json['id'] as String,
      name: json['name'] as String,
      priceXof: (json['priceXof'] as num).toInt(),
      required: json['required'] as bool? ?? false);
}

class ProductReview {
  const ProductReview(
      {required this.id,
      required this.author,
      required this.rating,
      required this.comment,
      required this.verified});
  final String id;
  final String author;
  final double rating;
  final String comment;
  final bool verified;
  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
      id: json['id'] as String,
      author: json['author'] as String,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      verified: json['verified'] as bool);
}

/// One choice of an option group, e.g. "16 Go" in "Mémoire RAM".
class ProductOptionChoice {
  const ProductOptionChoice(
      {required this.id,
      required this.label,
      this.priceDeltaXof = 0,
      this.inStock = true});
  final String id;
  final String label;

  /// Price difference from the product's default configuration.
  final int priceDeltaXof;
  final bool inStock;
  factory ProductOptionChoice.fromJson(Map<String, dynamic> json) =>
      ProductOptionChoice(
          id: json['id'] as String,
          label: json['label'] as String,
          priceDeltaXof: (json['priceDeltaXof'] as num?)?.toInt() ?? 0,
          inStock: json['inStock'] as bool? ?? true);
}

/// A configurable criterion (Mémoire RAM, Stockage, Système d'exploitation…).
class ProductOptionGroup {
  const ProductOptionGroup(
      {required this.id,
      required this.label,
      required this.choices,
      required this.defaultChoiceId});
  final String id;
  final String label;
  final List<ProductOptionChoice> choices;

  /// The configuration the catalogue price corresponds to.
  final String defaultChoiceId;
  factory ProductOptionGroup.fromJson(Map<String, dynamic> json) =>
      ProductOptionGroup(
          id: json['id'] as String,
          label: json['label'] as String,
          choices: (json['choices'] as List<dynamic>)
              .map((c) =>
                  ProductOptionChoice.fromJson(c as Map<String, dynamic>))
              .toList(),
          defaultChoiceId: json['defaultChoiceId'] as String);
}

class ProductDetail extends ProductSummary {
  const ProductDetail(
      {required super.id,
      required super.name,
      required super.brand,
      required super.categoryId,
      required super.priceXof,
      super.compareAtPriceXof,
      super.imageUrl,
      super.secondaryImageUrl,
      super.rating,
      super.reviewCount,
      required super.inStock,
      required super.badges,
      this.description,
      required this.images,
      required this.specifications,
      required this.variants,
      required this.addons,
      required this.reviews,
      required this.paymentMethods,
      required this.similarProductIds,
      this.optionGroups = const []});
  final String? description;
  final List<String> images;
  final Map<String, String> specifications;
  final List<ProductVariant> variants;
  final List<ProductAddon> addons;
  final List<ProductReview> reviews;
  final List<String> paymentMethods;
  final List<String> similarProductIds;
  final List<ProductOptionGroup> optionGroups;
  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final summary = ProductSummary.fromJson(json);
    final images =
        (json['images'] as List<dynamic>? ?? const []).cast<String>().toList();
    for (final image in [summary.imageUrl, summary.secondaryImageUrl]) {
      if (image != null && !images.contains(image)) images.add(image);
    }
    final rawSpecifications =
        Map<String, dynamic>.from(json['specifications'] as Map? ?? const {});
    return ProductDetail(
        id: summary.id,
        name: summary.name,
        brand: summary.brand,
        categoryId: summary.categoryId,
        priceXof: summary.priceXof,
        compareAtPriceXof: summary.compareAtPriceXof,
        imageUrl: summary.imageUrl,
        secondaryImageUrl: summary.secondaryImageUrl,
        rating: summary.rating,
        reviewCount: summary.reviewCount,
        inStock: summary.inStock,
        badges: summary.badges,
        description: json['description'] as String?,
        images: images,
        specifications: rawSpecifications
            .map((key, value) => MapEntry(key, value as String)),
        variants: (json['variants'] as List<dynamic>? ?? const [])
            .map(
                (item) => ProductVariant.fromJson(item as Map<String, dynamic>))
            .toList(),
        addons: (json['addons'] as List<dynamic>? ?? const [])
            .map((item) => ProductAddon.fromJson(item as Map<String, dynamic>))
            .toList(),
        reviews: (json['reviews'] as List<dynamic>? ?? const [])
            .map((item) => ProductReview.fromJson(item as Map<String, dynamic>))
            .toList(),
        paymentMethods: (json['paymentMethods'] as List<dynamic>? ??
                const ['Paiement à la livraison'])
            .cast<String>(),
        similarProductIds:
            (json['similarProductIds'] as List<dynamic>? ?? const [])
                .cast<String>(),
        optionGroups: (json['optionGroups'] as List<dynamic>? ?? const [])
            .map((g) => ProductOptionGroup.fromJson(g as Map<String, dynamic>))
            .toList());
  }
}
