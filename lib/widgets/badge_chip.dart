import 'package:flutter/material.dart';

import '../contracts/product.dart';
import '../theme/tokens.dart';

const Map<ProductBadge, String> _labels = {
  ProductBadge.promo: 'Promo',
  ProductBadge.newItem: 'Nouveau',
  ProductBadge.top: 'Top vente',
  ProductBadge.stock: 'Stock limité',
};

const Map<ProductBadge, Color> _backgrounds = {
  ProductBadge.promo: AppColors.dangerSoft,
  ProductBadge.newItem: AppColors.primarySoft,
  ProductBadge.top: AppColors.gold,
  ProductBadge.stock: AppColors.dangerSoft,
};

const Map<ProductBadge, Color> _textColors = {
  ProductBadge.promo: AppColors.danger,
  ProductBadge.newItem: AppColors.primary,
  ProductBadge.top: AppColors.primaryDark,
  ProductBadge.stock: AppColors.danger,
};

/// Mirrors ../mobile-app/src/components/ui/Badge.tsx
class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.kind});

  final ProductBadge kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: _backgrounds[kind],
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        _labels[kind]!,
        style: TextStyle(color: _textColors[kind], fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
