import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../widgets/app_header.dart';
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
                    ? const Center(
                        child: Text('Aucune commande pour le moment.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final order = items[index];
                          return Card(
                            child: ListTile(
                              title: Text(order.number,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle:
                                  Text('${order.createdAt}\n${order.status}'),
                              isThreeLine: true,
                              trailing: Text(formatXof(order.totalXof),
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800)),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
