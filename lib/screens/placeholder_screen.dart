import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';

/// Stand-in for tabs not yet ported from ../mobile-app (Boutique, Panier,
/// Lo+, Compte). Mirrors the RN app's own bootstrap-stage stub screens.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(
      {super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: title,
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.construction_outlined,
                accent: AppColors.gold,
                title: 'Bientôt disponible',
                message: message,
                actionLabel: 'Retour à la boutique',
                onAction: () => context.go('/boutique'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
