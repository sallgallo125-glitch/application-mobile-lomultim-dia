import 'package:flutter/material.dart';

import '../../contracts/product.dart';
import '../../theme/tokens.dart';
import '../badge_chip.dart';
import '../price_text.dart';
import '../rating_row.dart';
import 'product_image.dart';
import '../header_actions.dart';

class ProductListItem extends StatelessWidget {
  const ProductListItem({super.key, required this.product, this.onPressed});
  final ProductSummary product;
  final ValueChanged<ProductSummary>? onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onPressed == null ? null : () => onPressed!(product),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.lg)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Heart in the image corner: no extra width taken from the text.
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: ProductImage(
                          url: product.imageUrl,
                          categoryId: product.categoryId),
                    ),
                  ),
                  Positioned(
                      top: -6,
                      right: -6,
                      child: FavoriteButton(productId: product.id, size: 18)),
                ]),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (product.badges.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Wrap(spacing: AppSpacing.xs, children: [
                            for (final badge in product.badges)
                              BadgeChip(kind: badge)
                          ])),
                    Text(product.brand,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xs),
                    // Price and quick add on one line; wraps on narrow columns.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        PriceText(
                            amountXof: product.priceXof,
                            compareAtXof: product.compareAtPriceXof),
                        QuickAddButton(
                            productId: product.id,
                            productName: product.name,
                            inStock: product.inStock),
                      ],
                    ),
                    if (product.rating != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: RatingRow(
                              value: product.rating!,
                              reviewCount: product.reviewCount)),
                    if (!product.inStock)
                      const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('Rupture de stock',
                              style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                  ])),
            ]),
          ),
        ),
      );
}
