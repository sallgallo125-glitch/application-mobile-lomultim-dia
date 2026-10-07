import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/catalog/catalog_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/commerce/product_list_item.dart';
import '../widgets/loading_state.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final ids = ref.watch(favoriteIdsProvider);
    return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              AppHeader(
                  title: 'Mes favoris',
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/compte')),
              products.when(
                  loading: () => const LoadingState(),
                  error: (error, stackTrace) => const Expanded(
                      child: Center(
                          child: Text('Impossible de charger les favoris.'))),
                  data: (items) {
                    final favorites =
                        items.where((item) => ids.contains(item.id)).toList();
                    return Expanded(
                        child: favorites.isEmpty
                            ? Center(
                                child: ElevatedButton(
                                    onPressed: () => context.go('/boutique'),
                                    child: const Text(
                                        'Aucun favori · Voir la boutique')))
                            : ListView.separated(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                itemCount: favorites.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) =>
                                    ProductListItem(
                                        product: favorites[index],
                                        onPressed: (item) => context
                                            .push('/produit/${item.id}'))));
                  })
            ])));
  }
}
