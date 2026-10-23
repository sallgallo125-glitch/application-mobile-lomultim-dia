import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/errors.dart';
import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../features/cart/cart_providers.dart';
import '../features/digital/digital_catalog.dart';
import '../features/digital/digital_code_providers.dart';
import 'digital_codes_screen.dart' show DigitalCodeTile;
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/order_status.dart';
import '../widgets/commerce/product_image.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/sub_page.dart';
import '../widgets/whatsapp_button.dart';
import 'orders_screen.dart' show OrderStatusPill;

/// Detail of one member order: timed tracking, items, delivery, payment,
/// price breakdown, and the actions (cancel, contact).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.number});
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(orderDetailProvider(number));
    return RedesignFonts(
      child: SubPage(
        title: 'Commande',
        subtitle: number,
        fallbackRoute: '/commandes',
        child: detail.when(
          loading: () =>
              const LoadingState(label: 'Chargement de la commande…'),
          error: (error, stackTrace) => ErrorState(
              onRetry: () => ref.invalidate(orderDetailProvider(number))),
          // Statuses change in the ERP without notice: pulling down re-reads.
          data: (order) => RefreshIndicator(
            onRefresh: () => ref.refresh(orderDetailProvider(number).future),
            child: _DetailBody(order: order),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = order.summary;
    final stage = OrderStage.of(summary.status);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      children: [
        Row(children: [
          Flexible(
              child: OrderStatusPill(status: summary.status, stage: stage)),
          const Spacer(),
          Text('Passée le ${summary.createdAt}', style: AppText.caption),
        ]),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Suivi',
          child: _Timeline(
              events: order.events,
              stage: stage,
              // Codes only: no preparation nor shipping steps.
              digital: summary.items.isNotEmpty &&
                  summary.items
                      .every((i) => digitalCatalog.containsKey(i.productId))),
        ),
        _Section(
          title:
              'Articles (${summary.items.fold<int>(0, (n, i) => n + i.quantity)})',
          child: Column(children: [
            for (final (i, item) in summary.items.indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              _ItemRow(item: item),
            ],
          ]),
        ),
        if (orderDigitalCodes(summary) case final codes when codes.isNotEmpty)
          _Section(
            title: 'Codes numériques (${codes.length})',
            icon: Icons.vpn_key_outlined,
            child: Column(children: [
              for (final c in codes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DigitalCodeTile(code: c),
                ),
            ]),
          ),
        _Section(
          title: order.deliveryLabel,
          icon: Icons.local_shipping_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.recipient?.isNotEmpty ?? false)
                Text(order.recipient!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              if (order.address != null)
                Text(order.address!, style: AppText.bodyMuted),
              if (summary.deliveryInfo != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(summary.deliveryInfo!, style: AppText.caption),
                ),
            ],
          ),
        ),
        _Section(
          title: 'Paiement',
          icon: Icons.account_balance_wallet_outlined,
          child: Row(children: [
            Expanded(child: Text(order.paymentLabel)),
            Text(
              order.paid ? 'Payée' : 'À payer',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:
                      order.paid ? AppColors.success : OrderStage.of('').color),
            ),
          ]),
        ),
        _Section(title: 'Montant', child: _Totals(order: order)),
        if (stage.cancelled || stage.step == 4)
          if (summary.items.any((i) => i.productId != null)) ...[
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: () => _buyAgain(context, ref),
              icon: const Icon(Icons.replay),
              label: const Text('Racheter'),
            ),
          ],
        if (order.cancellable) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger)),
            onPressed: () => _confirmCancel(context, ref),
            icon: const Icon(Icons.close),
            label: const Text('Annuler la commande'),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
              Uri.parse(
                  'https://wa.me/$whatsAppSupportNumber?text=${Uri.encodeComponent('Bonjour LO Multimédia, j’ai une question sur ma commande ${summary.number}.')}'),
              mode: LaunchMode.externalApplication),
          icon: const WhatsAppLogo(size: 20),
          label: const Text('Une question ? Écrire sur WhatsApp'),
        ),
      ],
    );
  }

  /// Puts the order's products back in the cart (base versions: the
  /// options chosen at the time are not kept), then opens the cart.
  Future<void> _buyAgain(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    var missing = 0;
    for (final item in order.summary.items) {
      if (item.productId == null) {
        missing++;
        continue;
      }
      try {
        await ref
            .read(cartActionsProvider)
            .add(item.productId!, quantity: item.quantity);
      } catch (_) {
        missing++;
      }
    }
    messenger.showSnackBar(SnackBar(
        content: Text(missing == 0
            ? 'Articles ajoutés au panier.'
            : 'Articles ajoutés, sauf $missing indisponible${missing > 1 ? 's' : ''}.')));
    router.go('/panier');
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final number = order.summary.number;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: Text('La commande $number sera annulée. '
            'Si vous avez déjà payé, vous serez remboursé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Garder')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Annuler la commande')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountRepositoryProvider).cancelOrder(number);
      ref.invalidate(orderDetailProvider(number));
      ref.invalidate(ordersProvider);
      messenger
          .showSnackBar(const SnackBar(content: Text('Commande annulée.')));
    } on ApiHttpError catch (e) {
      ref.invalidate(orderDetailProvider(number));
      messenger.showSnackBar(SnackBar(
          content: Text(e.message ?? 'Impossible d’annuler la commande.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Impossible d’annuler la commande. Réessayez.')));
    }
  }
}

/// White card with a title, like the order cards of the list.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.icon});
  final String title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg - 2),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(title,
                    style: displayFont(const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700))),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      );
}

/// The 4 steps, each with the time it was reached (from the ERP status
/// history); a cancelled order shows its history as is.
class _Timeline extends StatelessWidget {
  const _Timeline(
      {required this.events, required this.stage, this.digital = false});
  final List<OrderEvent> events;
  final OrderStage stage;
  final bool digital;

  @override
  Widget build(BuildContext context) {
    if (stage.cancelled || digital) {
      return Column(children: [
        for (final (i, e) in events.indexed)
          _Step(
            label: orderStatusLabel(e.status),
            detail: [e.at, if (e.comment != null) e.comment!].join(' · '),
            done: true,
            current: i == events.length - 1,
            color:
                i == events.length - 1 ? stage.color : AppColors.textSecondary,
            last: i == events.length - 1,
          ),
      ]);
    }
    // Last event reached for each step (a step can have several statuses,
    // e.g. Reçue then Confirmée).
    final reached = <int, OrderEvent>{};
    for (final e in events) {
      reached[OrderStage.of(e.status).step] = e;
    }
    return Column(children: [
      for (var k = 1; k <= 4; k++)
        _Step(
          label: reached[k] == null
              ? OrderStage.labels[k - 1]
              : orderStatusLabel(reached[k]!.status),
          detail: reached[k] == null
              ? (k == stage.step + 1 ? 'Prochaine étape' : null)
              : [
                  reached[k]!.at,
                  if (reached[k]!.comment != null) reached[k]!.comment!
                ].join(' · '),
          done: k <= stage.step,
          current: k == stage.step,
          color: stage.color,
          last: k == 4,
        ),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.detail,
    required this.done,
    required this.current,
    required this.color,
    required this.last,
  });
  final String label;
  final String? detail;
  final bool done;
  final bool current;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 22,
            child: Column(children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : AppColors.white,
                  border: Border.all(
                      color: done ? color : AppColors.border, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color:
                        done ? color.withValues(alpha: .4) : AppColors.border,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              current ? FontWeight.w700 : FontWeight.w500,
                          color:
                              done ? AppColors.text : AppColors.textSecondary)),
                  if (detail != null) Text(detail!, style: AppText.caption),
                ],
              ),
            ),
          ),
        ]),
      );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderLineSummary item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: ProductImage(
              url: item.imageUrl,
              categoryId: item.categoryId,
              fit: BoxFit.cover,
              iconSize: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.3)),
                Text('Quantité ${item.quantity}', style: AppText.caption),
              ],
            ),
          ),
          if (item.unitPriceXof != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(formatXof(item.unitPriceXof! * item.quantity),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ]),
      );
}

class _Totals extends StatelessWidget {
  const _Totals({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final s = order.summary;
    Widget line(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: AppText.bodyMuted)),
            Text(value, style: TextStyle(color: color ?? AppColors.text)),
          ]),
        );
    return Column(children: [
      line('Sous-total', formatXof(order.subtotalXof)),
      line(
          'Livraison',
          order.deliveryFeeXof == 0
              ? 'Gratuite'
              : formatXof(order.deliveryFeeXof)),
      if (order.promoDiscountXof > 0)
        line('Code promo', '− ${formatXof(order.promoDiscountXof)}',
            color: AppColors.success),
      if (s.pointsDiscountXof > 0)
        line('Points LO+', '− ${formatXof(s.pointsDiscountXof)}',
            color: AppColors.success),
      if (s.giftCardAppliedXof > 0)
        line('Carte cadeau', '− ${formatXof(s.giftCardAppliedXof)}',
            color: AppColors.success),
      const Divider(height: AppSpacing.lg, color: AppColors.border),
      Row(children: [
        Expanded(
          child: Text('Total',
              style: displayFont(
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ),
        Text(formatXof(s.amountDueXof),
            style: displayFont(
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      ]),
      if (s.pointsToEarn > 0 && !OrderStage.of(s.status).cancelled)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            OrderStage.of(s.status).step == 4
                ? '+${s.pointsToEarn} points LO+ crédités'
                : '+${s.pointsToEarn} points LO+ crédités à la livraison',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ),
    ]);
  }
}
