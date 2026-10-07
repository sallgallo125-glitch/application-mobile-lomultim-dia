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
