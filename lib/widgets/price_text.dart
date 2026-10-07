import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../utils/currency.dart';

/// Mirrors ../mobile-app/src/components/ui/Price.tsx
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.amountXof, this.compareAtXof});

  final int amountXof;
  final int? compareAtXof;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = compareAtXof != null && compareAtXof! > amountXof;

    return Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          formatXof(amountXof),
          style: const TextStyle(
              color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (hasDiscount) ...[
          Text(
            formatXof(compareAtXof!),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}
