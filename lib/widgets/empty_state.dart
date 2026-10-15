import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Illustrated empty state: a plain outline icon (or image), a title,
/// a short explanation and an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.iconSize = 56,
    this.image,
    this.actionLabel,
    this.onAction,
    this.accent = AppColors.primary,
    this.footer,
  });

  final String title;
  final String? message;
  final IconData icon;
  final double iconSize;

  /// Asset shown instead of [icon] when provided.
  final String? image;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accent;

  /// Extra content under the action (suggestions, popular products…).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                Image.asset(image!, height: 150, fit: BoxFit.contain)
              else
                // Plain outline icon, no backdrop.
                Icon(icon,
                    size: iconSize,
                    color: AppColors.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(height: AppSpacing.lg),
              Text(title, textAlign: TextAlign.center, style: AppText.title),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(message!,
                    textAlign: TextAlign.center, style: AppText.bodyMuted),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.xl),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
