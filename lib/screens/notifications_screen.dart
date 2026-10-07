import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              AppHeader(
                  title: 'Notifications',
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/compte')),
              Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('Aucune notification.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Card(
                                color: item.read
                                    ? AppColors.white
                                    : AppColors.primarySoft,
                                child: ListTile(
                                    leading: Icon(
                                        item.read
                                            ? Icons.notifications_none
                                            : Icons.notifications,
                                        color: AppColors.primary),
                                    title: Text(item.title,
                                        style: TextStyle(
                                            fontWeight: item.read
                                                ? FontWeight.w500
                                                : FontWeight.w800)),
                                    subtitle: Text(item.message),
                                    onTap: () {
                                      final changed = [...items];
                                      changed[index] = (
                                        title: item.title,
                                        message: item.message,
                                        read: true
                                      );
                                      ref
                                          .read(notificationsProvider.notifier)
                                          .state = changed;
                                    }));
                          }))
            ])));
  }
}
