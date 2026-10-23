import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

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
import '../widgets/commerce/product_rail.dart';
import '../features/home/home_providers.dart';

/// Light grey page behind the white cards (Jumia / Samsung style).
const _pageBg = AppColors.white;

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  /// "Modifier" mode: checkboxes to remove several items at once.
  bool _editing = false;
  final _selected = <String>{};

  void _toggleEditing() => setState(() {
        _editing = !_editing;
        _selected.clear();
      });

  Future<void> _removeSelected(List<CartItem> items) async {
    final actions = ref.read(cartActionsProvider);
    final ids = items.where((i) => _selected.contains(i.id)).toList();
    for (final item in ids) {
      await actions.remove(item.id);
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _editing = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(ids.length > 1
              ? '${ids.length} articles retirés du panier.'
              : 'Article retiré du panier.')));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final actions = ref.read(cartActionsProvider);
    final usePoints = ref.watch(usePointsFromCartProvider);
    final isSignedIn = ref.watch(signedInProvider);
    final pointsBalance = ref.watch(loyaltyMemberProvider).value?.points ?? 0;
    final promoCode = ref.watch(cartPromoCodeProvider);
    final hasItems = cart.value?.items.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: hasItems ? _pageBg : AppColors.background,
      bottomNavigationBar: cart.maybeWhen(
        data: (value) {
          if (value.items.isEmpty) return null;
          if (_editing) {
            return _EditBar(
              allSelected: _selected.length == value.items.length,
              selectedCount: _selected.length,
              onSelectAll: (all) => setState(() {
                _selected.clear();
                if (all) _selected.addAll(value.items.map((i) => i.id));
              }),
              onRemove: () => _removeSelected(value.items),
            );
          }
          final totals = _CartTotals.of(
              value, isSignedIn && usePoints ? pointsBalance : 0, promoCode);
          return _CartCheckoutBar(
            totalXof: totals.totalXof,
            onContinue: () => context.push('/commande/paiement'),
          );
        },
        orElse: () => null,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: hasItems
                  ? 'Mon panier (${cart.value!.items.fold<int>(0, (n, i) => n + i.quantity)})'
                  : 'Mon panier',
              actions: [
                if (hasItems)
                  HeaderAction(
                      icon: _editing ? Icons.check : Icons.edit_outlined,
                      label: _editing ? 'Terminer' : 'Modifier',
                      onPressed: _toggleEditing),
                notificationsHeaderAction(context, ref),
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
                final totals = _CartTotals.of(value,
                    isSignedIn && usePoints ? pointsBalance : 0, promoCode);
                return Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                    children: [
                      _Card(
                        child: Column(children: [
                          if (_editing)
                            _SelectAllRow(
                              count: value.items.length,
                              value: _selected.length == value.items.length,
                              onChanged: (all) => setState(() {
                                _selected.clear();
                                if (all) {
                                  _selected
                                      .addAll(value.items.map((i) => i.id));
                                }
                              }),
                            ),
                          for (final item in value.items)
                            _CartLine(
                              key: ValueKey(item.id),
                              item: item,
                              selecting: _editing,
                              selected: _selected.contains(item.id),
                              onSelect: (v) => setState(() => v
                                  ? _selected.add(item.id)
                                  : _selected.remove(item.id)),
                              onMinus: () =>
                                  actions.update(item.id, item.quantity - 1),
                              onPlus: () =>
                                  actions.update(item.id, item.quantity + 1),
                              onRemove: () => _removeItem(context, ref, item),
                            ),
                        ]),
                      ),
                      _Card(
                        child: Column(children: [
                          const _PromoField(),
                          _UsePoints(totalXof: value.totalXof),
                        ]),
                      ),
                      _Card(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: _Summary(totals: totals),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _Guarantees(),
                      const _YouMayLike(),
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

/// Borderless row with a thin rule underneath, like a receipt line.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
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
      required this.onRemove,
      this.selecting = false,
      this.selected = false,
      this.onSelect});
  final CartItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Future<void> Function() onRemove;

  /// "Modifier" mode: a checkbox before the photo.
  final bool selecting;
  final bool selected;
  final ValueChanged<bool>? onSelect;

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
              // Swipe left to remove. The line collapses through `_remove`
              // (same undo snackbar as the bin icon), so the Dismissible
              // itself never leaves a dismissed widget in the tree.
              child: Dismissible(
                key: ValueKey('swipe-${widget.item.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  unawaited(_remove());
                  return false;
                },
                background: Container(
                  padding: const EdgeInsets.only(right: AppSpacing.xl),
                  alignment: Alignment.centerRight,
                  decoration: const BoxDecoration(color: AppColors.danger),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline, color: Colors.white),
                    SizedBox(width: AppSpacing.xs),
                    Text('Retirer',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ]),
                ),
                child: _Panel(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.selecting)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 28, right: AppSpacing.xs),
                            child: _BrandCheckbox(
                                value: widget.selected,
                                onChanged: (v) => widget.onSelect?.call(v)),
                          ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                  color:
                                                      AppColors.textSecondary,
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
                                                  color: AppColors.primaryDark,
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
            ),
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
            Semantics(
              label: 'Illustration d’un panier LoMultimedia',
              child: Lottie.asset(
                'assets/animations/empty_cart.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/Panier 3D blanc avec logo LM.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Votre panier est vide',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            const Text('Parcourez nos 8 rayons et ajoutez vos produits.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                ),
                onPressed: () => context.go('/boutique'),
                child: const Text('Continuer mes achats')),
          ]),
        ),
      );
}

/// Amounts shown in the summary card and the bottom bar.
class _CartTotals {
  const _CartTotals({
    required this.itemCount,
    required this.subtotalXof,
    required this.promoDiscountXof,
    required this.pointsDiscountXof,
    required this.freeDelivery,
    required this.deliveryFeeXof,
    required this.totalXof,
  });

  /// [pointsBalance] is 0 when the customer does not spend points.
  factory _CartTotals.of(Cart cart, int pointsBalance, String promoCode) {
    final promo = isValidPromoCode(promoCode)
        ? (cart.subtotalXof * promoRate).round()
        : 0;
    final points = pointsBalance == 0
        ? 0
        : redeemablePoints(pointsBalance, cart.totalXof - promo) *
            loyaltyPointValueXof;
    final total = cart.totalXof - promo - points;
    return _CartTotals(
      itemCount: cart.items.fold<int>(0, (n, i) => n + i.quantity),
      subtotalXof: cart.subtotalXof,
      promoDiscountXof: promo,
      pointsDiscountXof: points,
      freeDelivery: cart.subtotalXof >= freeDeliveryThresholdXof,
      deliveryFeeXof: cart.deliveryFeeXof,
      totalXof: total < 0 ? 0 : total,
    );
  }

  final int itemCount;
  final int subtotalXof;
  final int promoDiscountXof;
  final int pointsDiscountXof;
  final bool freeDelivery;
  final int deliveryFeeXof;
  final int totalXof;
}

/// White rounded card on the grey page, no border.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.white,
          // White page: the outline keeps the blocks apart.
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

/// Round checkbox in the brand's dark blue.
class _BrandCheckbox extends StatelessWidget {
  const _BrandCheckbox({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        shape: const CircleBorder(),
        activeColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
        visualDensity: VisualDensity.compact,
      );
}

class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow(
      {required this.count, required this.value, required this.onChanged});
  final int count;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            _BrandCheckbox(value: value, onChanged: onChanged),
            Text('Tout sélectionner ($count)',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// Bottom bar in "Modifier" mode: select all + remove the selection.
class _EditBar extends StatelessWidget {
  const _EditBar({
    required this.allSelected,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onRemove,
  });
  final bool allSelected;
  final int selectedCount;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => _BarShell(
        child: Row(children: [
          _BrandCheckbox(value: allSelected, onChanged: onSelectAll),
          const Expanded(
              child:
                  Text('Tout', style: TextStyle(fontWeight: FontWeight.w700))),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              ),
              onPressed: selectedCount == 0 ? null : onRemove,
              child: Text('Supprimer ($selectedCount)'),
            ),
          ),
        ]),
      );
}

/// White bar pinned at the bottom, with a hairline on top.
class _BarShell extends StatelessWidget {
  const _BarShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.white,
        child: Container(
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
              child: child,
            ),
          ),
        ),
      );
}

/// One-line bar: total (and savings) on the left, "Commander (n)" right.
class _CartCheckoutBar extends StatelessWidget {
  // Item count is in the page title and savings in the summary: the bar
  // only carries the total and the button.
  const _CartCheckoutBar({
    required this.totalXof,
    required this.onContinue,
  });

  final int totalXof;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _BarShell(
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(
                        text: 'Total  ',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: _AnimatedCartText(
                        text: formatXof(totalXof),
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ])),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              onPressed: onContinue,
              child: const Text('Commander'),
            ),
          ),
        ]),
      );
}

/// Promo code line; the code is carried over to the checkout page.
class _PromoField extends ConsumerStatefulWidget {
  const _PromoField();

  @override
  ConsumerState<_PromoField> createState() => _PromoFieldState();
}

class _PromoFieldState extends ConsumerState<_PromoField> {
  late final _controller =
      TextEditingController(text: ref.read(cartPromoCodeProvider));
  bool _tried = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    ref.read(cartPromoCodeProvider.notifier).state =
        _controller.text.trim().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(cartPromoCodeProvider);
    final valid = isValidPromoCode(code);
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_offer_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _apply(),
              decoration: const InputDecoration(
                hintText: 'Code promo',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                textStyle: const TextStyle(fontWeight: FontWeight.w800)),
            onPressed: _apply,
            child: const Text('Appliquer'),
          ),
        ]),
        if (_tried && code.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: AppSpacing.xs),
            child: Text(
              valid
                  ? 'Code $code appliqué · −${(promoRate * 100).round()} %'
                  : 'Code invalide ou expiré',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valid ? AppColors.success : AppColors.danger),
            ),
          ),
      ]),
    );
  }
}

/// Receipt-style summary card.
class _Summary extends StatelessWidget {
  const _Summary({required this.totals});
  final _CartTotals totals;

  Widget _row(String label, String value, {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: bold ? AppColors.text : AppColors.textSecondary,
                    fontSize: bold ? 16 : 14,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
          ),
          Text(value,
              style: TextStyle(
                  color: color ?? AppColors.text,
                  fontSize: bold ? 18 : 14,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        _row('Sous-total', formatXof(totals.subtotalXof)),
        if (totals.promoDiscountXof > 0)
          _row('Code promo', '−${formatXof(totals.promoDiscountXof)}',
              color: AppColors.success),
        if (totals.pointsDiscountXof > 0)
          _row('Réduction LO+', '−${formatXof(totals.pointsDiscountXof)}',
              color: AppColors.success),
        _row(
            'Livraison',
            totals.freeDelivery
                ? 'Offerte'
                : totals.deliveryFeeXof == 0
                    ? 'À l’étape suivante'
                    : formatXof(totals.deliveryFeeXof),
            color: totals.freeDelivery ? AppColors.success : null),
        const Divider(height: AppSpacing.lg, color: AppColors.border),
        _row('Total', formatXof(totals.totalXof), bold: true),
      ]);
}

/// Reassurance line under the cart: small grey outline icons.
class _Guarantees extends StatelessWidget {
  const _Guarantees();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: AppText.caption),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          item(Icons.lock_outline, 'Paiement sécurisé'),
          item(Icons.verified_outlined, 'Garantie officielle'),
          item(Icons.support_agent, 'SAV agréé'),
        ],
      ),
    );
  }
}

/// "Vous aimerez aussi": the home page's recommended products.
class _YouMayLike extends ConsumerWidget {
  const _YouMayLike();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products =
        ref.watch(homeContentProvider).value?.recommendedProducts ?? const [];
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vous aimerez aussi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          // Same cards as the home rails.
          ProductRail(products: products, padding: 0),
        ],
      ),
    );
  }
}

/// "Utiliser mes points LO+" right from the cart (1 point = 100 FCFA):
/// one plain line with a switch, no card.
class _UsePoints extends ConsumerWidget {
  const _UsePoints({required this.totalXof});
  final int totalXof;

  Widget _line(String title, String? subtitle, Widget? trailing) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption),
              ],
            ]),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(signedInProvider)) {
      return _line(
          'Utiliser mes points LO+',
          'Connectez-vous pour les utiliser sur cette commande.',
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
            onPressed: () => context.push('/connexion'),
            child: const Text('Se connecter'),
          ));
    }

    return ref.watch(loyaltyMemberProvider).when(
          loading: () => _line(
              'Utiliser mes points LO+',
              'Chargement de votre solde…',
              const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
          error: (error, stackTrace) => _line(
              'Utiliser mes points LO+',
              'Impossible de charger votre solde.',
              IconButton(
                tooltip: 'Réessayer',
                onPressed: () => ref.invalidate(loyaltyMemberProvider),
                icon: const Icon(Icons.refresh_rounded),
              )),
          data: (member) {
            final balance = member.points;
            final usable = redeemablePoints(balance, totalXof);
            if (usable == 0) {
              return _line(
                  'Utiliser mes points LO+',
                  balance == 0
                      ? 'Aucun point disponible pour le moment.'
                      : '$balance pts · $loyaltyMinRedeemPoints points minimum.',
                  null);
            }
            final on = ref.watch(usePointsFromCartProvider);
            return _line(
                'Utiliser mes $usable pts '
                '(−${formatXof(usable * loyaltyPointValueXof)})',
                // The discount itself is in the summary: show what is left.
                on
                    ? 'Il vous restera ${balance - usable} pts'
                    : '$balance pts disponibles',
                Switch(
                  value: on,
                  activeThumbColor: AppColors.white,
                  activeTrackColor: AppColors.primaryDark,
                  onChanged: (v) =>
                      ref.read(usePointsFromCartProvider.notifier).state = v,
                ));
          },
        );
  }
}
