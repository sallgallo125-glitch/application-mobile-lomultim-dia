import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/product.dart';
import '../../features/cart/cart_providers.dart';
import '../../features/customer/customer_providers.dart';
import '../../theme/tokens.dart';
import '../../utils/currency.dart';
import '../header_actions.dart';
import 'product_card.dart' show cardProductName;
import 'product_image.dart';
import 'stepper_button.dart';

/// Product card from the "Mobile E-commerce App Design" mock-up
/// (`ProductCard` in src/App.tsx, `.product-card` in src/index.css):
/// grey photo area with a red discount tag and a round heart, brand + rating,
/// 2-line name, price over old price, and a footer "● En stock" + red "+".
/// Sizes are the mock-up's, scaled up slightly for phone readability.
class CompactProductCard extends StatefulWidget {
  const CompactProductCard(
      {super.key, required this.product, this.onPressed, this.width = 162});

  final ProductSummary product;
  final ValueChanged<ProductSummary>? onPressed;
  final double width;

  @override
  State<CompactProductCard> createState() => _CompactProductCardState();
}

class _CompactProductCardState extends State<CompactProductCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  static const _navy = Color(0xFF17233E);
  static const _muted = Color(0xFF858FA0);
  static const _mediaBg = Color(0xFFF6F7F9);
  static const _cardBorder = Color(0xFFEDF0F3);
  static const _footerRule = Color(0xFFF0F1F4);
  static const _star = Color(0xFFEDA830);

  /// "−25 %" when there is an old price, else the first badge.
  String? get _tag {
    final old = widget.product.compareAtPriceXof;
    if (old != null && old > widget.product.priceXof) {
      return '−${((1 - widget.product.priceXof / old) * 100).round()} %';
    }
    if (widget.product.badges.isEmpty) return null;
    return switch (widget.product.badges.first) {
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
    final isZoomed = _isHovered || _isPressed;
    final secondaryImageUrl = _getSecondaryImageUrl(product);

    return SizedBox(
      width: widget.width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(
                color: Color(0x09132344), blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: Material(
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: const BorderSide(color: _cardBorder),
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
                // Photo area; flexible so larger text never overflows.
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: _mediaBg,
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
                                  iconSize: 40,
                                  heroTag: 'compact_img_${product.id}',
                                ),
                                if (secondaryImageUrl != null)
                                  AnimatedOpacity(
                                    opacity: isZoomed ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    child: ProductImage(
                                      url: secondaryImageUrl,
                                      categoryId: product.categoryId,
                                      iconSize: 40,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (tag != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(tag,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    Positioned(
                        top: 7, right: 7, child: _RoundHeart(product.id)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand ............ ★ 4.8
                      Row(children: [
                        Expanded(
                          child: Text(product.brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .5)),
                        ),
                        if (product.rating != null) ...[
                          const Icon(Icons.star, size: 13, color: _star),
                          const SizedBox(width: 2),
                          Text('${product.rating}',
                              style: const TextStyle(
                                  color: Color(0xFF26344E), fontSize: 11)),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      Text(cardProductName(product.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _navy,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(formatXof(product.priceXof),
                            style: const TextStyle(
                                color: _navy,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.3)),
                      ),
                      // Always one line so every card's footer lines up.
                      Text(
                          old != null && old > product.priceXof
                              ? formatXof(old)
                              : '',
                          style: const TextStyle(
                              color: Color(0xFFA1A9B4),
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough)),
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: _footerRule),
                      const SizedBox(height: 7),
                      Row(children: [
                        Expanded(child: _StockLabel(inStock: product.inStock)),
                        _AddMini(product: product),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundHeart extends ConsumerWidget {
  const _RoundHeart(this.productId);
  final String productId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(favoriteIdsProvider).contains(productId);
    return Semantics(
      button: true,
      label: active ? 'Retirer des favoris' : 'Ajouter aux favoris',
      child: Tooltip(
        message: active ? 'Retirer des favoris' : 'Ajouter aux favoris',
        child: InkResponse(
          onTap: () => toggleFavorite(ref, productId),
          radius: 20,
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x1C17233E),
                    blurRadius: 6,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Icon(active ? Icons.favorite : Icons.favorite_border,
                size: 17,
                color: active ? AppColors.danger : const Color(0xFF79859A)),
          ),
        ),
      ),
    );
  }
}

class _StockLabel extends StatelessWidget {
  const _StockLabel({required this.inStock});
  final bool inStock;
  @override
  Widget build(BuildContext context) {
    final color = inStock ? const Color(0xFF168A62) : AppColors.danger;
    return Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Flexible(
        child: Text(inStock ? 'En stock' : 'Rupture',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// Small red "+" (`.add-mini`): one tap adds the product to the cart.
class _AddMini extends ConsumerStatefulWidget {
  const _AddMini({required this.product});
  final ProductSummary product;
  @override
  ConsumerState<_AddMini> createState() => _AddMiniState();
}

class _AddMiniState extends ConsumerState<_AddMini> {
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await ref.read(cartActionsProvider).add(widget.product.id);
      if (mounted) showAddedToCart(context);
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
    final enabled = widget.product.inStock && !_busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Ajouter ${widget.product.name} au panier',
      child: Tooltip(
        message: 'Ajouter au panier',
        child: _busy
            ? const SizedBox.square(
                dimension: 30,
                child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: StepperButton.plusForeground)))
            : StepperButton.plus(
                tooltip: 'Ajouter au panier',
                size: 30,
                onPressed: enabled ? _add : null),
      ),
    );
  }
}
