import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../theme/redesign_fonts.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/order_status.dart';
import '../widgets/app_header.dart';
import '../widgets/commerce/product_image.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(signedInProvider)) return const _GuestOrdersScreen();
    final orders = ref.watch(ordersProvider);
    final count = orders.valueOrNull?.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RedesignFonts(
          child: Column(
            children: [
              AppHeader(
                title: 'Mes commandes',
                subtitle: count == null || count == 0
                    ? null
                    : '$count commande${count == 1 ? '' : 's'}',
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/compte'),
              ),
              orders.when(
                loading: () =>
                    const LoadingState(label: 'Chargement des commandes…'),
                error: (error, stackTrace) =>
                    ErrorState(onRetry: () => ref.invalidate(ordersProvider)),
                data: (items) => Expanded(
                  child: items.isEmpty
                      ? const _EmptyOrders()
                      // Statuses change in the ERP without notice (no push
                      // in v1): pulling down re-reads them.
                      : RefreshIndicator(
                          onRefresh: () => ref.refresh(ordersProvider.future),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                            children: [
                              _OrderFilterBar(orders: items),
                              const SizedBox(height: AppSpacing.md),
                              if (_filtered(ref, items).isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.xl),
                                  child: Text(
                                      ref.watch(_orderFilterProvider) ==
                                              _OrderFilter.current
                                          ? 'Aucune commande en cours.'
                                          : 'Aucune commande terminée.',
                                      textAlign: TextAlign.center,
                                      style: AppText.bodyMuted),
                                ),
                              for (final order in _filtered(ref, items))
                                _OrderCard(
                                    order: order,
                                    onTap: () => context.push(
                                        '/commandes/${Uri.encodeComponent(order.number)}')),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OrderFilter { all, current, done }

/// Kept while the app runs, so coming back from a detail keeps the filter.
final _orderFilterProvider =
    StateProvider<_OrderFilter>((ref) => _OrderFilter.all);

/// Delivered and cancelled orders are « terminées », the rest « en cours ».
bool _isDone(OrderSummary o) {
  final stage = OrderStage.of(o.status);
  return stage.cancelled || stage.step == 4;
}

List<OrderSummary> _filtered(WidgetRef ref, List<OrderSummary> orders) =>
    switch (ref.watch(_orderFilterProvider)) {
      _OrderFilter.all => orders,
      _OrderFilter.current => orders.where((o) => !_isDone(o)).toList(),
      _OrderFilter.done => orders.where(_isDone).toList(),
    };

/// Segmented « Toutes / En cours / Terminées », with the counts.
class _OrderFilterBar extends ConsumerWidget {
  const _OrderFilterBar({required this.orders});
  final List<OrderSummary> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_orderFilterProvider);
    final open = orders.where((o) => !_isDone(o)).length;
    final labels = {
      _OrderFilter.all: 'Toutes',
      _OrderFilter.current: open > 0 ? 'En cours ($open)' : 'En cours',
      _OrderFilter.done: 'Terminées',
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(children: [
        for (final f in _OrderFilter.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: f == current,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(_orderFilterProvider.notifier).state = f,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: f == current ? AppColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: f == current
                        ? const [
                            BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 1))
                          ]
                        : null,
                  ),
                  child: Text(labels[f]!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              f == current ? FontWeight.w700 : FontWeight.w500,
                          color: f == current
                              ? AppColors.text
                              : AppColors.textSecondary)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 56, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Aucune commande pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Vos achats apparaîtront ici.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => context.go('/boutique'),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Découvrir la boutique'),
              ),
            ],
          ),
        ),
      );
}

/// Order card of the redesign mockup: first item, number and date, the
/// 4-step tracking bar, then the status pill and the total.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.action, this.onTap});

  final OrderSummary order;

  /// Opens the order detail (member orders).
  final VoidCallback? onTap;

  /// Optional button under the card (guest orders: « Suivre »).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final stage = OrderStage.of(order.status);
    final first = order.items.isEmpty ? null : order.items.first;
    final others = order.items.length - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    // The ERP order list has no picture yet: the category icon
                    // stands in until it sends the first item.
                    child: ProductImage(
                      url: first?.imageUrl,
                      categoryId: first?.categoryId,
                      fit: BoxFit.cover,
                      iconSize: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                order.number,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: displayFont(const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .2)),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(order.createdAt, style: AppText.caption),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          first == null
                              ? 'Détail des articles indisponible'
                              : others > 0
                                  ? '${first.name} + $others autre${others > 1 ? 's' : ''}'
                                  : first.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ]),
                if (stage.step > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  OrderTrackBar(step: stage.step, color: stage.color),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Flexible(
                      child:
                          OrderStatusPill(status: order.status, stage: stage)),
                  const SizedBox(width: AppSpacing.sm),
                  const Spacer(),
                  Text(formatXof(order.totalXof),
                      style: displayFont(const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700))),
                ]),
                if (order.pointsToEarn > 0 &&
                    !stage.cancelled &&
                    stage.step < 4) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                      '+${order.pointsToEarn} points LO+ crédités à la livraison',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 4 segments (Reçue, Préparée, En route, Livrée), lit up to [step].
class OrderTrackBar extends StatelessWidget {
  const OrderTrackBar({super.key, required this.step, required this.color});
  final int step;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          for (var k = 1; k <= 4; k++) ...[
            if (k > 1) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: k <= step ? color : AppColors.border,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (var k = 1; k <= 4; k++) ...[
            if (k > 1) const SizedBox(width: 4),
            Expanded(
              child: Text(
                OrderStage.labels[k - 1],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: k == step ? AppColors.text : const Color(0xFF94A3B8),
                  fontWeight: k == step ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ]),
      ]);
}

/// Order status: icon and text in the stage colour, no background.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status, required this.stage});
  final String status;
  final OrderStage stage;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(stage.icon, size: 15, color: stage.color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            orderStatusLabel(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: stage.color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700),
          ),
        ),
      ]);
}

/// "Mes commandes" without an account: orders placed on this device, each
/// trackable with its number and phone.
class _GuestOrdersScreen extends ConsumerWidget {
  const _GuestOrdersScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(guestOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(
            title: 'Mes commandes',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/compte'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Row(children: [
                    Icon(Icons.phone_iphone, color: AppColors.primaryDark),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                          'Commandes passées sans compte sur ce téléphone. '
                          'Créez un compte pour les retrouver partout.',
                          style: TextStyle(
                              color: AppColors.primaryDark, fontSize: 13)),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Text('Aucune commande sur ce téléphone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  for (final order in orders)
                    _OrderCard(
                      order: OrderSummary(
                          id: order.number,
                          number: order.number,
                          createdAt: order.createdAt,
                          status: order.status,
                          totalXof: order.totalXof,
                          guest: true),
                      action: OutlinedButton(
                        onPressed: () => context.push(
                            '/suivi?commande=${Uri.encodeComponent(order.number)}&tel=${Uri.encodeComponent(order.phone)}'),
                        child: const Text('Suivre la commande'),
                      ),
                    ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.push('/suivi'),
                  icon: const Icon(Icons.search),
                  label: const Text('Suivre une autre commande'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: () => context.push('/inscription'),
                  child: const Text('Créer mon compte'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
