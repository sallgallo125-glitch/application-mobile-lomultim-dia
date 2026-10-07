import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import 'app_header.dart';
import 'error_state.dart';
import 'loading_state.dart';

/// Page pushed over the tabs: header with a back button + scrollable body.
class SubPage extends StatelessWidget {
  const SubPage(
      {super.key,
      required this.title,
      this.subtitle,
      this.fallbackRoute = '/compte',
      required this.child});

  final String title;
  final String? subtitle;

  /// Where "back" goes when the page was opened directly (deep link).
  final String fallbackRoute;

  /// Usually a [ListView]; a [LoadingState]/[ErrorState] (already Expanded)
  /// is also accepted.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final body = child;
    // LoadingState / ErrorState already return an Expanded.
    final isExpanded =
        body is Expanded || body is LoadingState || body is ErrorState;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(
              title: title,
              subtitle: subtitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(fallbackRoute)),
          if (isExpanded) body else Expanded(child: body),
        ]),
      ),
    );
  }
}

/// Section title used inside sub pages.
class PageSectionTitle extends StatelessWidget {
  const PageSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Text(text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      );
}
