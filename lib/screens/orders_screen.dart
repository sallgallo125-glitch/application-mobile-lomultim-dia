import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/account.dart';
import '../features/account/account_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: 'Mes commandes',
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
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          Text(
                            'Historique de vos achats',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${items.length} commande${items.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (final order in items)
                            if (order.items.isEmpty)
                              _OrderProductRow(order: order)
                            else
                              for (final item in order.items)
                                _OrderProductRow(order: order, item: item),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
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

class _OrderProductRow extends StatelessWidget {
  const _OrderProductRow({required this.order, this.item});

  final OrderSummary order;
  final OrderLineSummary? item;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductImage(
                  url: item?.imageUrl,
                  categoryId: item?.categoryId,
                  fit: BoxFit.cover,
                  iconSize: 36,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.name ?? 'Détails des articles indisponibles',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Commande #${order.number}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _OrderStatus(
                        status: order.status,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      order.deliveryInfo ?? 'Commandée le ${order.createdAt}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _OrderStatus extends StatelessWidget {
  const _OrderStatus({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          status.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

Color _statusColor(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('livr') || normalized.contains('deliver')) {
    return AppColors.success;
  }
  if (normalized.contains('annul') || normalized.contains('cancel')) {
    return AppColors.danger;
  }
  return AppColors.primaryDark;
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
                    Card(
                      child: ListTile(
                        title: Text(order.number,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${order.createdAt} · ${formatXof(order.totalXof)}\n${order.status}'),
                        isThreeLine: true,
                        trailing: TextButton(
                          onPressed: () => context.push(
                              '/suivi?commande=${Uri.encodeComponent(order.number)}&tel=${Uri.encodeComponent(order.phone)}'),
                          child: const Text('Suivre'),
                        ),
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
