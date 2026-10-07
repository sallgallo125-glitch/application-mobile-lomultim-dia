import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/cart_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import 'app_header.dart';

/// Number of items in the cart (sum of quantities), 0 while loading.
final cartCountProvider = Provider<int>((ref) =>
    ref.watch(cartProvider).value?.items.fold<int>(0, (n, i) => n + i.quantity) ??
    0);

/// Unread notifications.
final unreadNotificationsProvider = Provider<int>((ref) =>
    ref.watch(notificationsProvider).where((n) => !n.read).length);

/// Header "Notifications" button with the real unread count.
HeaderAction notificationsHeaderAction(BuildContext context, WidgetRef ref) =>
    HeaderAction(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        count: ref.watch(unreadNotificationsProvider),
        onPressed: () => context.push('/notifications'));

/// Header "Panier" button with the real item count.
HeaderAction cartHeaderAction(BuildContext context, WidgetRef ref) =>
    HeaderAction(
        icon: Icons.shopping_cart_outlined,
        label: 'Panier',
        count: ref.watch(cartCountProvider),
        onPressed: () => context.go('/panier'));

/// Adds or removes [productId] from the favourites.
void toggleFavorite(WidgetRef ref, String productId) {
  final updated = {...ref.read(favoriteIdsProvider)};
  updated.contains(productId) ? updated.remove(productId) : updated.add(productId);
  ref.read(favoriteIdsProvider.notifier).state = updated;
}

/// Heart button used on product cards and list items.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.productId, this.size = 20});
  final String productId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteIdsProvider).contains(productId);
    return IconButton(
      tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      visualDensity: VisualDensity.compact,
      iconSize: size,
      onPressed: () => toggleFavorite(ref, productId),
      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_outline,
          color: isFavorite ? const Color(0xFFDE2E26) : null),
    );
  }
}

/// "Added to cart" confirmation with a shortcut to the cart.
void showAddedToCart(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  // Captured now: the page may be gone when the action is tapped.
  final router = GoRouter.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: const Text('Produit ajouté au panier'),
    duration: const Duration(milliseconds: 2500),
    // Since Flutter 3.32 a snack bar with an action stays until dismissed;
    // this one must close by itself.
    persist: false,
    backgroundColor: AppColors.success,
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(
        label: 'Voir le panier',
        textColor: AppColors.white,
        onPressed: () {
          messenger.clearSnackBars();
          router.go('/panier');
        }),
  ));
}

/// One-tap "add to cart" for product cards and list items (default variant).
class QuickAddButton extends ConsumerStatefulWidget {
  const QuickAddButton(
      {super.key,
      required this.productId,
      required this.inStock,
      this.fullWidth = false});
  final String productId;
  final bool inStock;

  /// Full-width "+ Ajouter" button (product cards) instead of an icon.
  final bool fullWidth;
  @override
  ConsumerState<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends ConsumerState<QuickAddButton> {
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await ref.read(cartActionsProvider).add(widget.productId);
      if (mounted) showAddedToCart(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Impossible d'ajouter ce produit. Réessayez.")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullWidth) {
      // Sober outlined button: white, thin grey border, dark text; it turns
      // dark blue while pressed.
      final enabled = widget.inStock && !_busy;
      return SizedBox(
        width: double.infinity,
        height: 38,
        child: OutlinedButton.icon(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            side: WidgetStateProperty.resolveWith((states) => BorderSide(
                color: states.contains(WidgetState.pressed)
                    ? AppColors.primaryDark
                    : AppColors.border)),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.pressed)
                    ? AppColors.primaryDark
                    : AppColors.white),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? AppColors.textSecondary
                    : states.contains(WidgetState.pressed)
                        ? AppColors.white
                        : AppColors.text),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          onPressed: enabled ? _add : null,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.shopping_cart_outlined, size: 17),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            // Weight only: the app's font family is kept.
            child: Text(
                _busy
                    ? 'Ajout…'
                    : widget.inStock
                        ? 'Ajouter'
                        : 'Rupture de stock',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ),
      );
    }
    return _iconButton();
  }

  Widget _iconButton() => IconButton.filled(
        tooltip: widget.inStock ? 'Ajouter au panier' : 'Rupture de stock',
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        onPressed: widget.inStock && !_busy ? _add : null,
        icon: _busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_shopping_cart),
      );
}
