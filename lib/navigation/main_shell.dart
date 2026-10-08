import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/boutique_screen.dart' show shopOpenedFromHomeProvider;
import '../theme/tokens.dart';

/// Tabs of the bottom bar.
const _tabs = [
  (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
  (Icons.storefront_outlined, Icons.storefront_rounded, 'Boutique'),
  (Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Panier'),
  (Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, 'Lo+'),
  (Icons.person_outline_rounded, Icons.person_rounded, 'Compte'),
];

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) {
          // Opened from the bottom bar: the shop shows no back button.
          ProviderScope.containerOf(context)
              .read(shopOpenedFromHomeProvider.notifier)
              .state = false;
          navigationShell.goBranch(index,
              initialLocation: index == navigationShell.currentIndex);
        },
      ),
    );
  }
}

/// Floating white pill bar: the active tab grows into a dark-blue pill with
/// its icon and name; the others show a grey icon only.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onSelect});
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.sm),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1A1E2A5A),
                    blurRadius: 24,
                    offset: Offset(0, 8)),
              ],
            ),
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  // The active tab takes more room for its name.
                  flex: i == currentIndex ? 5 : 2,
                  child: _NavItem(
                    icon: _tabs[i].$1,
                    selectedIcon: _tabs[i].$2,
                    label: _tabs[i].$3,
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.selectedIcon,
      required this.label,
      required this.selected,
      required this.onTap});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              // Only the colour is animated: sizes switch at once, so a tab
              // never overflows while it shrinks.
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(selected ? selectedIcon : icon,
                          size: 24,
                          color: selected
                              ? AppColors.white
                              : AppColors.textSecondary),
                      if (selected) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
