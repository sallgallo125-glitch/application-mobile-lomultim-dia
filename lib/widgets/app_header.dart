import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

class HeaderAction {
  const HeaderAction(
      {required this.icon, required this.label, this.count, this.onPressed});

  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback? onPressed;
}

/// Light header used on every page: white background with a thin grey
/// line underneath, dark-blue title, pale-blue icon buttons, grey search
/// field. Status-bar icons are switched to dark to stay readable.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showLogo = false,
    this.onBack,
    this.actions = const [],
    this.searchField,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final bool showLogo;
  final VoidCallback? onBack;
  final List<HeaderAction> actions;
  final Widget? searchField;

  /// Full-width content under the search field, inside the same white
  /// block (e.g. the shop's filter rows).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              MediaQuery.of(context).padding.top + AppSpacing.md,
              AppSpacing.lg,
              bottom != null ? AppSpacing.xs : AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title row skipped when it would be empty (search field only).
                if (title.isNotEmpty ||
                    onBack != null ||
                    showLogo ||
                    actions.isNotEmpty)
                  Row(
                    children: [
                      if (onBack != null) ...[
                        AppBackButton(onPressed: onBack!),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      if (showLogo) ...[
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Image.asset('assets/images/logo.png',
                              fit: BoxFit.contain),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.pageTitle,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  // Darker gold: the brand gold is too faint on white.
                                  color: showLogo
                                      ? const Color(0xFFB45309)
                                      : AppColors.textSecondary,
                                  fontSize: showLogo ? 9.5 : 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: showLogo ? 0.6 : 0,
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final action in actions) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _IconBubble(
                            icon: action.icon,
                            label: action.label,
                            onPressed: action.onPressed,
                            count: action.count),
                      ],
                    ],
                  ),
                if (searchField != null) ...[
                  if (title.isNotEmpty ||
                      onBack != null ||
                      showLogo ||
                      actions.isNotEmpty)
                    const SizedBox(height: AppSpacing.md),
                  searchField!,
                ],
              ],
            ),
          ),
          if (bottom != null) bottom!,
        ]),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(
      {required this.icon, required this.label, this.onPressed, this.count});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      // No background: plain icon, like the back arrow.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                    child: Icon(icon, size: 24, color: AppColors.primaryDark)),
                if (count != null && count! > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain back arrow, no background: the app's single back-button style.
/// Navy like the page titles (white on the blue bands, [onDark]), with a
/// 44 px touch target.
class AppBackButton extends StatelessWidget {
  const AppBackButton(
      {super.key, required this.onPressed, this.onDark = false});

  final VoidCallback onPressed;

  /// On a dark/blue background.
  final bool onDark;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Retour',
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back),
        iconSize: 24,
        color: onDark ? AppColors.white : AppColors.primaryDark,
        padding: EdgeInsets.zero,
        // Pulls the arrow to the page edge, like the reference.
        style: IconButton.styleFrom(
            minimumSize: const Size(44, 44), alignment: Alignment.centerLeft),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );
}
