import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/header_actions.dart' show cartCountProvider;
import '../screens/boutique_screen.dart' show shopOpenedFromHomeProvider;
import '../theme/tokens.dart';

/// Tabs of the bottom bar (filled icons, like the reference design).
const _tabs = [
  (Icons.home_rounded, 'Accueil'),
  (Icons.storefront_rounded, 'Boutique'),
  (Icons.shopping_cart_rounded, 'Panier'),
  (Icons.star_rounded, 'Lo+'),
  (Icons.person_rounded, 'Compte'),
];

/// Index of the "Panier" tab (carries the item-count badge).
const _cartTab = 2;

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
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

/// Classic full-width white bar: every tab shows its icon and name; the
/// active one is dark blue and bold, the others grey-blue. The cart tab has
/// a red badge with the number of items.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.currentIndex, required this.onSelect});
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0F1E2A5A), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _tabs[i].$1,
                  label: _tabs[i].$2,
                  selected: i == currentIndex,
                  badge: i == _cartTab ? cartCount : 0,
                  onTap: () => onSelect(i),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.badge,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  static const _inactive = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : _inactive;
    return Semantics(
      button: true,
      selected: selected,
      // "Onglet panier" (lower case) keeps it distinct from the header's
      // "Panier" button.
      label: 'Onglet ${label.toLowerCase()}'
          '${badge > 0 ? ', $badge article${badge > 1 ? 's' : ''}' : ''}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 25, color: color),
            if (badge > 0)
              Positioned(
                top: -5,
                right: -9,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 17, minHeight: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: AppColors.white, width: 1.5),
                  ),
                  child: Text(badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ]),
      ),
    );
  }
}
