import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Mirrors ../mobile-app/src/components/ui/ErrorState.tsx
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message = 'Une erreur est survenue. Réessayez.', this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Oups', style: TextStyle(color: AppColors.danger, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  ),
                  child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
