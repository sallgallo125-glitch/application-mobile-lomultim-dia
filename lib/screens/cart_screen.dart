import 'dart:async';

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

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final actions = ref.read(cartActionsProvider);
    final usePoints = ref.watch(usePointsFromCartProvider);
    final isSignedIn = ref.watch(signedInProvider);
    final pointsBalance = ref.watch(loyaltyMemberProvider).value?.points ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: cart.maybeWhen(
        data: (value) => value.items.isEmpty
            ? null
            : _CartCheckoutBar(
                isSignedIn: isSignedIn,
                itemCount: value.items
                    .fold<int>(0, (count, item) => count + item.quantity),
                subtotalXof: value.subtotalXof,
                deliveryFeeXof: value.deliveryFeeXof,
                freeDelivery: value.subtotalXof >= freeDeliveryThresholdXof,
                pointsDiscountXof: isSignedIn && usePoints
                    ? redeemablePoints(pointsBalance, value.totalXof) *
                        loyaltyPointValueXof
                    : 0,
                totalXof: value.totalXof -
                    (isSignedIn && usePoints
                        ? redeemablePoints(pointsBalance, value.totalXof) *
                            loyaltyPointValueXof
                        : 0),
                onContinue: () => context.push('/commande/paiement'),
              ),
        orElse: () => null,
      ),
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
                return Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.xl),
                    children: [
                      for (final item in value.items)
                        _CartLine(
                          key: ValueKey(item.id),
                          item: item,
                          onMinus: () =>
                              actions.update(item.id, item.quantity - 1),
                          onPlus: () =>
                              actions.update(item.id, item.quantity + 1),
                          onRemove: () => _removeItem(context, ref, item),
                        ),
                      _CartCardEntrance(
                        key: const ValueKey('cart-loyalty-card'),
                        child: _UsePoints(totalXof: value.totalXof),
                      ),
                      _CartCardEntrance(
                        key: const ValueKey('cart-delivery-card'),
                        child: _Panel(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.local_shipping_outlined,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              const Expanded(
                                child: Text(
                                  'Livraison estimée pour Dakar Centre. Le montant définitif sera calculé selon la zone et le mode choisis à l’étape suivante.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                      height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Future<void> _removeItem(
      BuildContext context, WidgetRef ref, CartItem item) async {
    try {
      await ref.read(cartActionsProvider).remove(item.id);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
          notice;
      final timeout = Timer(const Duration(seconds: 3), () {
        if (context.mounted) notice.close();
      });
      notice = messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: const Text('Article retiré du panier.'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () async {
            try {
              await ref.read(cartActionsProvider).add(
                    item.productId,
                    variantId: item.variantId,
                    addonIds: item.addonIds,
                    options: item.options,
                    quantity: item.quantity,
                  );
            } catch (_) {
              if (context.mounted) {
                messenger.showSnackBar(const SnackBar(
                    content: Text(
                        'Impossible de restaurer cet article. Réessayez.')));
              }
            }
          },
        ),
      ));
      unawaited(notice.closed.then((_) => timeout.cancel()));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Impossible de retirer cet article. Réessayez.')));
      }
    }
  }
}

/// White rounded card with a light border, as in the cart mock-up.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
class _CartLine extends StatefulWidget {
  const _CartLine(
      {super.key,
      required this.item,
      required this.onMinus,
      required this.onPlus,
      required this.onRemove});
  final CartItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Future<void> Function() onRemove;

  @override
  State<_CartLine> createState() => _CartLineState();
}

class _CartLineState extends State<_CartLine> {
  bool _removing = false;

  Future<void> _remove() async {
    if (_removing) return;
    setState(() => _removing = true);
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);
    if (duration != Duration.zero) {
      await Future<void>.delayed(duration);
    }
    await widget.onRemove();
  }

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
    final (title, details) = _CartLineState.splitName(widget.item.name);
    final motionDisabled = MediaQuery.of(context).disableAnimations;
    final duration =
        motionDisabled ? Duration.zero : const Duration(milliseconds: 200);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _removing
          ? const SizedBox.shrink()
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - progress)),
                  child: child,
                ),
              ),
              child: _Panel(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox.square(
                          dimension: 84,
                          child: ColoredBox(
                            color: const Color(0xFFF1F3F7),
                            child: ProductImage(
                                url: widget.item.imageUrl,
                                categoryId: widget.item.categoryId,
                                iconSize: 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                    SizedBox.square(
                                      dimension: 28,
                                      child: IconButton(
                                        tooltip: 'Retirer l’article',
                                        padding: EdgeInsets.zero,
                                        iconSize: 20,
                                        onPressed: _remove,
                                        icon: const Icon(Icons.delete_outline,
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ]),
                              if (details != null) ...[
                                const SizedBox(height: 2),
                                Text(details,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.5)),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${formatXof(widget.item.unitPriceXof)} / unité',
                                            style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12)),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: _AnimatedCartText(
                                            key: ValueKey(
                                                widget.item.unitPriceXof *
                                                    widget.item.quantity),
                                            text: formatXof(
                                                widget.item.unitPriceXof *
                                                    widget.item.quantity),
                                            style: const TextStyle(
                                                color: AppColors.text,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  _QuantityPill(
                                      quantity: widget.item.quantity,
                                      onMinus: widget.onMinus,
                                      onPlus: widget.onPlus),
                                ],
                              ),
                            ]),
                      ),
                    ]),
              ),
            ),
    );
  }
}

class _CartCardEntrance extends StatelessWidget {
  const _CartCardEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - progress)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AnimatedCartText extends StatelessWidget {
  const _AnimatedCartText({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Text(text, key: ValueKey(text), style: style),
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
          child: _AnimatedCartText(
            key: ValueKey(quantity),
            text: '$quantity',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
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
            Image.asset(
              'assets/images/Panier 3D blanc avec logo LM.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              semanticLabel: 'Illustration d’un panier LoMultimedia',
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Votre panier est vide',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            const Text('Parcourez nos 8 rayons et ajoutez vos produits.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: () => context.go('/boutique'),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Voir la boutique')),
            ),
          ]),
        ),
      );
}

class _CartCheckoutBar extends StatefulWidget {
  const _CartCheckoutBar({
    required this.isSignedIn,
    required this.itemCount,
    required this.subtotalXof,
    required this.deliveryFeeXof,
    required this.freeDelivery,
    required this.pointsDiscountXof,
    required this.totalXof,
    required this.onContinue,
  });

  final bool isSignedIn;
  final int itemCount;
  final int subtotalXof;
  final int deliveryFeeXof;
  final bool freeDelivery;
  final int pointsDiscountXof;
  final int totalXof;
  final VoidCallback onContinue;

  @override
  State<_CartCheckoutBar> createState() => _CartCheckoutBarState();
}

class _CartCheckoutBarState extends State<_CartCheckoutBar> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.white,
        elevation: 12,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _detailsExpanded = !_detailsExpanded),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _detailsExpanded
                              ? 'Masquer le détail'
                              : 'Afficher le détail',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          _detailsExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _detailsExpanded
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _summaryRow(
                                'Sous-total (${widget.itemCount} article${widget.itemCount == 1 ? '' : 's'})',
                                formatXof(widget.subtotalXof)),
                            _summaryRow(
                                'Livraison standard · Dakar Centre',
                                widget.deliveryFeeXof == 0
                                    ? widget.freeDelivery
                                        ? 'Offerte'
                                        : 'À confirmer'
                                    : formatXof(widget.deliveryFeeXof)),
                            if (widget.pointsDiscountXof > 0)
                              _summaryRow('Réduction avec vos points LO+',
                                  '−${formatXof(widget.pointsDiscountXof)}'),
                            _summaryRow(
                              widget.isSignedIn
                                  ? 'Points LO+ gagnés'
                                  : 'Avec un compte LO+',
                              '+${loyaltyPointsFor(widget.subtotalXof - widget.pointsDiscountXof)} pts',
                              valueColor: widget.isSignedIn
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                            if (!widget.isSignedIn)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => context.push('/connexion'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xs),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                      'Connectez-vous pour les cumuler',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            const Divider(height: AppSpacing.md),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          widget.pointsDiscountXof > 0
                              ? 'Total après points'
                              : 'Total estimé',
                          style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _AnimatedCartText(
                          text: formatXof(widget.totalXof),
                          style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 19,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    onPressed: widget.onContinue,
                    icon: const Icon(Icons.lock_outline, size: 19),
                    label: const Text('Continuer la commande'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _summaryRow(String label, String value, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(value,
                style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)
                    .copyWith(color: valueColor)),
          ],
        ),
      );
}

/// "Utiliser mes points LO+" right from the cart (1 point = 100 FCFA).
class _UsePoints extends ConsumerWidget {
  const _UsePoints({required this.totalXof});
  final int totalXof;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final margin = const EdgeInsets.symmetric(vertical: AppSpacing.md);

    if (!signedIn) {
      return Card(
        margin: margin,
        child: ListTile(
          leading: const Icon(Icons.stars_rounded, color: AppColors.gold),
          title: const Text('Utiliser mes points LO+',
              style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text(
              'Connectez-vous à votre compte LO+ pour utiliser vos points sur cette commande.'),
          trailing: TextButton(
            onPressed: () => context.push('/connexion'),
            child: const Text('Se connecter'),
          ),
        ),
      );
    }

    return ref.watch(loyaltyMemberProvider).when(
          loading: () => Card(
            margin: margin,
            child: const ListTile(
              leading: Icon(Icons.stars_rounded, color: AppColors.gold),
              title: Text('Utiliser mes points LO+',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Chargement de votre solde LO+…'),
              trailing: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, stackTrace) => Card(
            margin: margin,
            child: ListTile(
              leading: const Icon(Icons.stars_rounded, color: AppColors.gold),
              title: const Text('Utiliser mes points LO+',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Impossible de charger votre solde LO+.'),
              trailing: IconButton(
                tooltip: 'Réessayer',
                onPressed: () => ref.invalidate(loyaltyMemberProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
          data: (member) {
            final balance = member.points;
            final usable = redeemablePoints(balance, totalXof);
            if (usable == 0) {
              return Card(
                margin: margin,
                child: ListTile(
                  leading:
                      const Icon(Icons.stars_rounded, color: AppColors.gold),
                  title: const Text('Utiliser mes points LO+',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    balance == 0
                        ? 'Aucun point disponible pour le moment.'
                        : '$balance points disponibles · 10 points minimum pour les utiliser.',
                  ),
                ),
              );
            }
            final on = ref.watch(usePointsFromCartProvider);
            final pointsUsed = on ? usable : 0;
            final savings = pointsUsed * loyaltyPointValueXof;
            return Card(
              margin: margin,
              child: SwitchListTile(
                value: on,
                onChanged: (v) =>
                    ref.read(usePointsFromCartProvider.notifier).state = v,
                secondary:
                    const Icon(Icons.stars_rounded, color: AppColors.gold),
                title: const Text('Utiliser mes points LO+',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: AnimatedSwitcher(
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Text(
                    on
                        ? '$pointsUsed points utilisés · Économie de ${formatXof(savings)}'
                        : '$balance points disponibles · Jusqu’à ${formatXof(usable * loyaltyPointValueXof)} d’économie',
                    key: ValueKey(on),
                  ),
                ),
              ),
            );
          },
        );
  }
}
