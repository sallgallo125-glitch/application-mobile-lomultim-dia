import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_providers.dart';
import '../features/cart/cart_providers.dart';
import '../features/member/member_providers.dart';
import '../theme/tokens.dart';
import '../contracts/cart.dart';
import '../utils/currency.dart';
import '../utils/delivery.dart';
import '../widgets/commerce/product_image.dart';
import '../utils/loyalty.dart';
import '../widgets/app_header.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/header_actions.dart';
import '../widgets/commerce/stepper_button.dart';
import '../widgets/nav_clearance.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const _navy = Color(0xFF1E2A5A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final actions = ref.read(cartActionsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: 'Mon panier',
              actions: [
                notificationsHeaderAction(context, ref),
                cartHeaderAction(context, ref),
              ],
            ),
            cart.when(
              loading: () => const LoadingState(label: 'Chargement du panier…'),
              error: (error, stackTrace) =>
                  ErrorState(onRetry: () => ref.invalidate(cartProvider)),
              data: (value) {
                if (value.items.isEmpty) {
                  return const Expanded(child: _EmptyCart());
                }
                final count =
                    value.items.fold<int>(0, (n, i) => n + i.quantity);
                final freeDelivery =
                    value.subtotalXof >= freeDeliveryThresholdXof;
                return Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xl + navBarClearance(context)),
                    children: [
                      for (final item in value.items)
                        _CartLine(
                          item: item,
                          onMinus: () =>
                              actions.update(item.id, item.quantity - 1),
                          onPlus: () =>
                              actions.update(item.id, item.quantity + 1),
                          onRemove: () => actions.remove(item.id),
                        ),
                      _Panel(
                        child: Column(children: [
                          _line(
                              'Sous-total ($count article${count > 1 ? 's' : ''})',
                              formatXof(value.subtotalXof),
                              valueBold: true),
                          _line(
                              value.deliveryFeeXof == 0 && !freeDelivery
                                  ? 'Retrait en showroom'
                                  : 'Livraison estimée',
                              value.deliveryFeeXof == 0
                                  ? 'Offerte'
                                  : formatXof(value.deliveryFeeXof),
                              valueBold: true),
                          _line('Points Lo+ gagnés',
                              '+${loyaltyPointsFor(value.subtotalXof)} pts',
                              accent: AppColors.success, valueBold: true),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(height: 1, thickness: 1.5),
                          ),
                          Row(children: [
                            const Text('Total',
                                style: TextStyle(
                                    color: _navy,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(formatXof(value.totalXof),
                                      style: const TextStyle(
                                          color: _navy,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                      _UsePoints(totalXof: value.totalXof),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          onPressed: () => context.push('/commande/paiement'),
                          child: const Text('Passer commande →'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                          'Frais de livraison définitifs selon la zone et le mode choisis au paiement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value,
          {Color? accent, bool valueBold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: accent ?? const Color(0xFF475569), fontSize: 14))),
          const SizedBox(width: AppSpacing.sm),
          Text(value,
              style: TextStyle(
                  color: accent ?? AppColors.text,
                  fontSize: 14,
                  fontWeight: valueBold ? FontWeight.w800 : null)),
        ]),
      );
}

/// White rounded card with a light border, as in the cart mock-up.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

/// One cart line: photo tile; name, options in grey and ✕ at the top;
/// line price and "− 1 +" at the bottom.
class _CartLine extends StatelessWidget {
  const _CartLine(
      {required this.item,
      required this.onMinus,
      required this.onPlus,
      required this.onRemove});
  final CartItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  /// "HP ProBook 450 G10 — Intel Core i5 · 16 Go · 512 Go SSD" →
  /// ("HP ProBook 450 G10", "Intel Core i5 · 16 Go · 512 Go SSD").
  static (String, String?) splitName(String name) {
    final parts = name.split(' · ');
    var title = parts.first;
    final details = <String>[];
    final dash = title.indexOf(' — ');
    if (dash > 0) {
      details.add(title.substring(dash + 3));
      title = title.substring(0, dash);
    }
    details.addAll(parts.skip(1));
    return (title, details.isEmpty ? null : details.join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    final (title, details) = splitName(item.name);
    return _Panel(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox.square(
            dimension: 84,
            child: ColoredBox(
              color: const Color(0xFFF1F3F7),
              child: ProductImage(
                  url: item.imageUrl,
                  categoryId: item.categoryId,
                  iconSize: 30),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700)),
              ),
              // ✕ removes the line.
              SizedBox.square(
                dimension: 28,
                child: IconButton(
                  tooltip: 'Retirer',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ),
            ]),
            if (details != null) ...[
              const SizedBox(height: 2),
              Text(details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatXof(item.unitPriceXof * item.quantity),
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _QuantityPill(
                  quantity: item.quantity, onMinus: onMinus, onPlus: onPlus),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// "− 1 +" with the shared ordering-flow buttons.
class _QuantityPill extends StatelessWidget {
  const _QuantityPill(
      {required this.quantity, required this.onMinus, required this.onPlus});
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        StepperButton.minus(
            tooltip: quantity > 1 ? 'Diminuer' : 'Retirer', onPressed: onMinus),
        SizedBox(
          width: 32,
          child: Text('$quantity',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        StepperButton.plus(tooltip: 'Augmenter', onPressed: onPlus),
      ]);
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shopping_cart_outlined,
                size: 64, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            const Text('Votre panier est vide',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            const Text('Découvrez nos produits et nos promotions du moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
                onPressed: () => context.go('/boutique'),
                child: const Text('Voir la boutique')),
          ]),
        ),
      );
}

/// "Utiliser mes points LO+" right from the cart (1 point = 100 FCFA).
class _UsePoints extends ConsumerWidget {
  const _UsePoints({required this.totalXof});
  final int totalXof;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(signedInProvider)) return const SizedBox.shrink();
    final balance = ref.watch(loyaltyMemberProvider).value?.points ?? 0;
    final usable = redeemablePoints(balance, totalXof);
    if (usable == 0) return const SizedBox.shrink();
    final on = ref.watch(usePointsFromCartProvider);
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: SwitchListTile(
        value: on,
        onChanged: (v) =>
            ref.read(usePointsFromCartProvider.notifier).state = v,
        secondary: const Icon(Icons.stars_rounded, color: AppColors.gold),
        title: const Text('Utiliser mes points LO+',
            style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            '$balance points · $usable points = −${formatXof(usable * loyaltyPointValueXof)} sur cette commande'),
      ),
    );
  }
}
