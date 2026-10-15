import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Mirrors ../mobile-app/src/components/ui/SectionHeader.tsx
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onActionPressed});

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
            title,
            style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2),
          )),
          const SizedBox(width: AppSpacing.sm),
          if (actionLabel != null && onActionPressed != null)
            GestureDetector(
              onTap: onActionPressed,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}
