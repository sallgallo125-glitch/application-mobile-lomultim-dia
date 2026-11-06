import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../contracts/product.dart';
import '../theme/tokens.dart';
import 'commerce/product_card.dart';

/// "Produits tendances" (home): a coloured panel with an uppercase title,
/// a subtitle and a round arrow, over a sideways row of the app's usual
/// product cards ([ProductCardWidget]).
class HomeTrending extends StatelessWidget {
  const HomeTrending({super.key, required this.products, this.onSeeAll});

  /// Shown as given; the caller picks and orders them.
  final List<ProductSummary> products;
  final VoidCallback? onSeeAll;

  static const _cardWidth = 180.0;

  /// Most reviewed first, without duplicates, at most [max].
  static List<ProductSummary> pick(Iterable<ProductSummary> all,
      {int max = 8}) {
    final seen = <String>{};
    final unique = [
      for (final p in all)
        if (seen.add(p.id)) p
    ]..sort((a, b) => (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0));
    return unique.take(max).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRODUITS TENDANCES',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2)),
                        SizedBox(height: 4),
                        Text('LES PLUS POPULAIRES DU MOMENT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    button: true,
                    label: 'Voir tous les produits tendances',
                    child: Material(
                      color: AppColors.white,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: onSeeAll,
                        child: const SizedBox(
                          width: 64,
                          height: 36,
                          child: Icon(Icons.arrow_forward_rounded,
                              color: AppColors.primary, size: 24),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36 + productCardHeight(_cardWidth, textScale),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  itemCount: products.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, i) => ProductCardWidget(
                    product: products[i],
                    width: _cardWidth,
                    onPressed: (selected) =>
                        context.push('/produit/${selected.id}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
