import 'category.dart';
import 'product.dart';

/// Mirrors ../mobile-app/src/contracts/home.ts
class PromoBannerData {
  final String id;
  final String icon;
  final String badgeLabel;
  final String title;
  final String subtitle;
  final String ctaLabel;

  /// Background visual (asset path or URL); the text sits on its left side.
  final String? imageUrl;

  const PromoBannerData({
    required this.id,
    required this.icon,
    required this.badgeLabel,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.imageUrl,
  });

  factory PromoBannerData.fromJson(Map<String, dynamic> json) {
    return PromoBannerData(
      id: json['id'] as String,
      icon: json['icon'] as String,
      badgeLabel: json['badgeLabel'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      ctaLabel: json['ctaLabel'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class HomeContent {
  final List<PromoBannerData> banners;
  final List<Category> categories;
  final List<ProductSummary> flashProducts;
  final List<ProductSummary> bestSellers;
  final List<ProductSummary> newArrivals;
  final List<ProductSummary> recommendedProducts;

  const HomeContent({
    required this.banners,
    required this.categories,
    required this.flashProducts,
    required this.bestSellers,
    required this.newArrivals,
    required this.recommendedProducts,
  });

  factory HomeContent.fromJson(Map<String, dynamic> json) {
    return HomeContent(
      banners: (json['banners'] as List<dynamic>)
          .map((item) => PromoBannerData.fromJson(item as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>)
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList(),
      flashProducts: (json['flashProducts'] as List<dynamic>)
          .map((item) => ProductSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      bestSellers: (json['bestSellers'] as List<dynamic>)
          .map((item) => ProductSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      newArrivals: (json['newArrivals'] as List<dynamic>?)
          ?.map((item) => ProductSummary.fromJson(item as Map<String, dynamic>))
          .toList() ?? const [],
      recommendedProducts: (json['recommendedProducts'] as List<dynamic>?)
          ?.map((item) => ProductSummary.fromJson(item as Map<String, dynamic>))
          .toList() ?? const [],
    );
  }
}
