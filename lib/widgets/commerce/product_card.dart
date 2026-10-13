import 'package:flutter/material.dart';

import '../../contracts/product.dart';
import '../../theme/tokens.dart';
import '../../utils/currency.dart';
import 'product_image.dart';
import '../header_actions.dart';

/// Product name as shown on cards: long dashes ("HP ProBook 450 G10 —
/// Intel Core i5") are removed, the words stay.
String cardProductName(String name) =>
    name.replaceAll(RegExp(r'\s*[—–]\s*'), ' ').trim();

/// Product card of the home rails, same layout as the site's ProductCard
/// (DevA -final/src/components/catalog/ProductCard.tsx): badge and heart on
/// the image, brand, name, price, old price, rating and a full-width
/// "+ Ajouter" button.
class ProductCardWidget extends StatefulWidget {
  const ProductCardWidget(
      {super.key, required this.product, this.onPressed, this.width = 162});

  final ProductSummary product;
  final ValueChanged<ProductSummary>? onPressed;
  final double width;

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget> {
  bool _isHovered = false;
  bool _isPressed = false;

  static const _badgeLabels = {
    ProductBadge.promo: 'PROMO',
    ProductBadge.newItem: 'NOUVEAU',
    ProductBadge.top: 'TOP VENTE',
    ProductBadge.stock: 'STOCK LIMITÉ',
  };

  String? _getSecondaryImageUrl(ProductSummary product) {
    if (product.secondaryImageUrl != null &&
        product.secondaryImageUrl != product.imageUrl) {
      return product.secondaryImageUrl;
    }
    const fallbackMap = {
      'c-informatique':
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&q=80',
      'c-smartphones':
          'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800&q=80',
      'c-multimedia':
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&q=80',
      'c-reseau':
          'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800&q=80',
      'c-securite':
          'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=800&q=80',
    };
    final fb = fallbackMap[product.categoryId] ??
        'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?w=800&q=80';
    return fb != product.imageUrl
        ? fb
        : 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=800&q=80';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final badge = product.badges.isEmpty ? null : product.badges.first;
    final hasDiscount = product.compareAtPriceXof != null &&
        product.compareAtPriceXof! > product.priceXof;
    final isZoomed = _isHovered || _isPressed;
    final secondaryImageUrl = _getSecondaryImageUrl(product);

    return SizedBox(
      width: widget.width,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed == null ? null : () => widget.onPressed!(product),
          onHover: (hovered) {
            if (mounted && _isHovered != hovered) {
              setState(() => _isHovered = hovered);
            }
          },
          onHighlightChanged: (highlighted) {
            if (mounted && _isPressed != highlighted) {
              setState(() => _isPressed = highlighted);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Flexible image: when larger text needs more room, the image
              // shrinks instead of the card overflowing.
              Expanded(
                child: Stack(children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: AnimatedScale(
                        scale: isZoomed ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ProductImage(
                              url: product.imageUrl,
                              categoryId: product.categoryId,
                              iconSize: 44,
                            ),
                            if (secondaryImageUrl != null)
                              AnimatedOpacity(
                                opacity: isZoomed ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: ProductImage(
                                  url: secondaryImageUrl,
                                  categoryId: product.categoryId,
                                  iconSize: 44,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: badge == ProductBadge.top
                              ? AppColors.gold
                              : badge == ProductBadge.newItem
                                  ? AppColors.primarySoft
                                  : AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(_badgeLabels[badge]!,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4,
                                color: badge == ProductBadge.top
                                    ? AppColors.text
                                    : badge == ProductBadge.newItem
                                        ? AppColors.primary
                                        : AppColors.danger)),
                      ),
                    ),
                  Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: FavoriteButton(productId: product.id)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.brand.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .4)),
                    const SizedBox(height: 2),
                    Text(cardProductName(product.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(formatXof(product.priceXof),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                    // Always one line, so every card's button is aligned.
                    Text(
                        hasDiscount
                            ? formatXof(product.compareAtPriceXof!)
                            : '',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough)),
                    if (product.rating != null)
                      // Shrinks on narrow grid tiles instead of overflowing.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                                i <= product.rating!.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 13,
                                color: AppColors.gold),
                          const SizedBox(width: 3),
                          Text('(${product.reviewCount ?? 0})',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ]),
                      )
                    else
                      const Text('Aucun avis',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: AppSpacing.sm),
                    QuickAddButton(
                        productId: product.id,
                        productName: product.name,
                        inStock: product.inStock,
                        fullWidth: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
