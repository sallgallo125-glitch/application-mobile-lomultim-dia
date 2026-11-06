import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/product.dart';
import '../../features/cart/cart_providers.dart';
import '../../features/catalog/catalog_providers.dart';
import '../../features/customer/customer_providers.dart';
import '../../theme/tokens.dart';
import '../../utils/currency.dart';
import 'product_image.dart';
import '../header_actions.dart';

/// Product name as shown on cards: long dashes ("HP ProBook 450 G10 —
/// Intel Core i5") are removed, the words stay.
String cardProductName(String name) =>
    name.replaceAll(RegExp(r'\s*[—–]\s*'), ' ').trim();

/// Product card (home rails, shop, search, favourites): white card with a
/// soft shadow, inset rounded photo with a red "-17%" tag and a large white
/// heart disc on its top-right corner, 2-line name, bold price + struck old
/// price, "★ 4.8 (320)" and a round cart button in the bottom-right corner.
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

  static const _radius = 22.0;
  static const _inset = 12.0;
  static const _ink = AppColors.text;
  static const _muted = AppColors.textSecondary;

  /// "-17%" when there is an old price, else the first badge.
  String? get _tag {
    final p = widget.product;
    final old = p.compareAtPriceXof;
    if (old != null && old > p.priceXof) {
      return '-${((1 - p.priceXof / old) * 100).round()}%';
    }
    if (p.badges.isEmpty) return null;
    return switch (p.badges.first) {
      ProductBadge.promo => 'PROMO',
      ProductBadge.newItem => 'NOUVEAU',
      ProductBadge.top => 'TOP',
      ProductBadge.stock => 'STOCK LIMITÉ',
    };
  }

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
    final tag = _tag;
    final old = product.compareAtPriceXof;
    final hasDiscount = old != null && old > product.priceXof;
    final isZoomed = _isHovered || _isPressed;
    final secondaryImageUrl = _getSecondaryImageUrl(product);

    return SizedBox(
      width: widget.width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          // Raised look: a wide soft grey halo plus a tighter darker
          // shadow just under the card.
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000),
                blurRadius: 22,
                spreadRadius: 1,
                offset: Offset(0, 8)),
            BoxShadow(
                color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(_radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed == null
                ? null
                : () => widget.onPressed!(product),
            onTapDown: widget.onPressed == null
                ? null
                : (_) => prefetchProduct(context, product.id),
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
            child: Stack(children: [
              Padding(
                // Bottom room keeps the price row above the round cart button.
                padding: const EdgeInsets.fromLTRB(_inset, _inset, _inset, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Flexible photo: larger text shrinks it instead of
                    // overflowing the card.
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(fit: StackFit.expand, children: [
                          AnimatedScale(
                            scale: isZoomed ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: Stack(fit: StackFit.expand, children: [
                              ProductImage(
                                  url: product.imageUrl,
                                  categoryId: product.categoryId,
                                  iconSize: 44),
                              if (secondaryImageUrl != null)
                                AnimatedOpacity(
                                  opacity: isZoomed ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: ProductImage(
                                      url: secondaryImageUrl,
                                      categoryId: product.categoryId,
                                      iconSize: 44),
                                ),
                            ]),
                          ),
                          if (tag != null)
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(tag,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(cardProductName(product.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 14,
                            height: 1.75,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    // Price + struck old price; one line on every card.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(formatXof(product.priceXof),
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            if (hasDiscount) ...[
                              const SizedBox(width: 7),
                              Text(formatXof(old),
                                  style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: _muted)),
                            ],
                          ]),
                    ),
                    const SizedBox(height: 6),
                    // Rating; right padding leaves room for the cart button.
                    Padding(
                      padding: const EdgeInsets.only(right: 52),
                      child: SizedBox(
                        height: 20,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: product.rating != null
                              ? Row(children: [
                                  const Icon(Icons.star_rounded,
                                      size: 17, color: AppColors.goldOnLight),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${product.rating} (${product.reviewCount ?? 0})',
                                      style: const TextStyle(
                                          color: _muted, fontSize: 12.5)),
                                ])
                              : const Text('Aucun avis',
                                  style:
                                      TextStyle(color: _muted, fontSize: 12.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Large white heart disc straddling the photo's top-right corner.
              Positioned(
                  top: 4,
                  right: 4,
                  child: _HeartDisc(productId: product.id)),
              // Round cart button tucked into the card's bottom-right corner.
              Positioned(
                  right: 5, bottom: 5, child: _CartDisc(product: product)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HeartDisc extends ConsumerWidget {
  const _HeartDisc({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(favoriteIdsProvider).contains(productId);
    final label = active ? 'Retirer des favoris' : 'Ajouter aux favoris';
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: AppColors.white,
          shape: const CircleBorder(),
          elevation: 1.5,
          shadowColor: const Color(0x331C1B22),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => toggleFavorite(ref, productId),
            child: SizedBox.square(
              dimension: 46,
              child: Icon(
                  active
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 22,
                  color: active ? AppColors.danger : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartDisc extends ConsumerStatefulWidget {
  const _CartDisc({required this.product});
  final ProductSummary product;

  @override
  ConsumerState<_CartDisc> createState() => _CartDiscState();
}

class _CartDiscState extends ConsumerState<_CartDisc> {
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await ref.read(cartActionsProvider).add(widget.product.id);
      if (mounted) showAddedToCart(context, widget.product.name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Impossible d'ajouter ce produit. Réessayez.")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inStock = widget.product.inStock;
    final enabled = inStock && !_busy;
    final label = inStock ? 'Ajouter au panier' : 'Rupture de stock';
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label : ${widget.product.name}',
      child: Tooltip(
        message: label,
        child: Material(
          color: inStock ? AppColors.primary : AppColors.border,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? _add : null,
            child: SizedBox.square(
              dimension: 52,
              child: Center(
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: AppColors.white))
                    : Icon(Icons.shopping_cart_rounded,
                        size: 21,
                        color: inStock
                            ? AppColors.white
                            : AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main-axis size of a [ProductCardWidget] [width] wide: inset photo at the
/// mock-up's 1.27:1 ratio, then the text block (grows with text scale).
double productCardHeight(double width, double textScale) =>
    32 + (width - 24) / 1.27 + 136 * textScale;
