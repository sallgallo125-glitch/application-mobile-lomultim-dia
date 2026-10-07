import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../contracts/product.dart';
import '../../theme/tokens.dart';
import 'compact_product_card.dart';
import 'product_card.dart';

/// Horizontal row of product cards (home rails, "Vous aimerez aussi",
/// "Consultés récemment").
class ProductRail extends StatelessWidget {
  const ProductRail(
      {super.key,
      required this.products,
      this.padding = AppSpacing.lg,
      this.compact = false});

  final List<ProductSummary> products;

  /// Side padding: the rail scrolls edge to edge but starts aligned.
  final double padding;

  /// Mock-up style cards (product page rails) instead of the site's cards
  /// with a full-width "+ Ajouter" (home).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Card = flexible image (~150) + text block and button that grow with text scale.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      // Compact: photo (~120) + text and footer that grow with text scale.
      height: compact ? 125 + 172 * textScale : 150 + 215 * textScale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: products.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: compact ? 11 : AppSpacing.md),
        itemBuilder: (context, index) => compact
            ? CompactProductCard(
                product: products[index],
                onPressed: (selected) =>
                    context.push('/produit/${selected.id}'))
            : ProductCardWidget(
                product: products[index],
                onPressed: (selected) =>
                    context.push('/produit/${selected.id}')),
      ),
    );
  }
}
