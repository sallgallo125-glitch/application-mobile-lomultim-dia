import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/cart_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import 'app_header.dart';

/// Number of items in the cart (sum of quantities), 0 while loading.
final cartCountProvider = Provider<int>((ref) =>
    ref
        .watch(cartProvider)
        .value
        ?.items
        .fold<int>(0, (n, i) => n + i.quantity) ??
    0);

/// Unread notifications.
final unreadNotificationsProvider = Provider<int>(
    (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);

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
  updated.contains(productId)
      ? updated.remove(productId)
      : updated.add(productId);
  ref.read(favoriteIdsProvider.notifier).state = updated;
}

/// Heart button used on product cards and list items.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.productId,
    this.size = 13,
    this.useContainer = true,
  });
  final String productId;
  final double size;
  final bool useContainer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteIdsProvider).contains(productId);
    final iconWidget = Icon(
      isFavorite ? Icons.favorite : Icons.favorite_border,
      size: size,
      color: isFavorite ? AppColors.danger : const Color(0xFF79859A),
    );

    if (!useContainer) {
      return IconButton(
        tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
        visualDensity: VisualDensity.compact,
        iconSize: size,
        onPressed: () => toggleFavorite(ref, productId),
        icon: iconWidget,
      );
    }

    return Semantics(
      button: true,
      label: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      child: Tooltip(
        message: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
        child: InkWell(
          onTap: () => toggleFavorite(ref, productId),
          borderRadius: BorderRadius.circular(20),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1417233E),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: iconWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact confirmation shown after adding a product to the cart.
void showAddedToCart(BuildContext context, String productName) {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  messenger.clearSnackBars();
  const productNameStyle =
      TextStyle(color: AppColors.white, fontWeight: FontWeight.w800);
  const addedLabel = 'ajouté au panier';
  const addedLabelStyle = TextStyle(color: AppColors.white, fontSize: 13);
  final maxToastWidth = math.min(MediaQuery.sizeOf(context).width - 32, 360.0);
  final maxTextWidth = math.max(0.0, maxToastWidth - 60);
  double textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);
    return painter.width;
  }

  final contentWidth = math.max(
    textWidth(productName, productNameStyle),
    textWidth(addedLabel, addedLabelStyle),
  );
  messenger.showSnackBar(SnackBar(
    width: contentWidth + 60,
    content: InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () {
        messenger.clearSnackBars();
        router.go('/panier');
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, color: AppColors.white, size: 20),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: contentWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: productNameStyle,
                ),
                const Text(addedLabel, style: addedLabelStyle),
              ],
            ),
          ),
        ],
      ),
    ),
    duration: const Duration(milliseconds: 2500),
    persist: false,
    backgroundColor: const Color(0xFF17233E),
    behavior: SnackBarBehavior.floating,
    elevation: 6,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md)),
  ));
}

/// One-tap "add to cart" for product cards and list items (default variant).
class QuickAddButton extends ConsumerStatefulWidget {
  const QuickAddButton(
      {super.key,
      required this.productId,
      required this.productName,
      required this.inStock,
      this.fullWidth = false});
  final String productId;
  final String productName;
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
      if (mounted) showAddedToCart(context, widget.productName);
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
            foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
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
