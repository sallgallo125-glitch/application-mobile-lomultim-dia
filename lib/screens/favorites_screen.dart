import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../contracts/product.dart';
import '../features/cart/cart_providers.dart';
import '../features/catalog/catalog_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/commerce/product_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/nav_clearance.dart';
import '../widgets/shimmer.dart' show shopGridColumnsFor;

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
                  loading: () =>
                      const LoadingState(layout: SkeletonLayout.grid),
                  error: (error, stackTrace) => const Expanded(
                      child: EmptyState(
                          icon: Icons.cloud_off_outlined,
                          accent: AppColors.danger,
                          title: 'Impossible de charger les favoris.',
                          message: 'Vérifiez votre connexion et réessayez.')),
                  data: (items) {
                    final favorites =
                        items.where((item) => ids.contains(item.id)).toList();
                    return Expanded(
                        child: favorites.isEmpty
                            ? EmptyState(
                                icon: Icons.favorite_border,
                                accent: AppColors.danger,
                                title: 'Aucun favori pour le moment',
                                message:
                                    'Touchez le cœur d’un produit pour le retrouver ici et suivre son prix.',
                                actionLabel: 'Découvrir la boutique',
                                onAction: () => context.go('/boutique'))
                            : _FavoritesGrid(favorites: favorites));
                  })
            ])));
  }
}

class _FavoritesGrid extends ConsumerStatefulWidget {
  const _FavoritesGrid({required this.favorites});
  final List<ProductSummary> favorites;
  @override
  ConsumerState<_FavoritesGrid> createState() => _FavoritesGridState();
}

class _FavoritesGridState extends ConsumerState<_FavoritesGrid> {
  bool _adding = false;

  Future<void> _addAll() async {
    final available = widget.favorites.where((p) => p.inStock).toList();
    if (available.isEmpty) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final product in available) {
        await ref.read(cartActionsProvider).add(product.id);
      }
      messenger.showSnackBar(SnackBar(
          content: Text(available.length == 1
              ? '1 article ajouté au panier'
              : '${available.length} articles ajoutés au panier'),
          action: SnackBarAction(
              label: 'Voir', onPressed: () => context.go('/panier'))));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Ajout impossible pour le moment. Réessayez.')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = widget.favorites;
    final inStock = favorites.where((p) => p.inStock).length;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = shopGridColumnsFor(constraints.maxWidth);
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final tileWidth = (constraints.maxWidth -
              2 * AppSpacing.lg -
              (columns - 1) * AppSpacing.sm) /
          columns;
      return CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.lg)),
                    child: Row(children: [
                      const Icon(Icons.favorite, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                favorites.length == 1
                                    ? '1 produit enregistré'
                                    : '${favorites.length} produits enregistrés',
                                style: AppText.subtitle),
                            Text(
                                inStock == favorites.length
                                    ? 'Tous disponibles'
                                    : '$inStock disponible${inStock > 1 ? 's' : ''}',
                                style: AppText.caption),
                          ])),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                          child: FilledButton.icon(
                          onPressed: inStock == 0 || _adding ? null : _addAll,
                          icon: _adding
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('Tout ajouter',
                              maxLines: 1, overflow: TextOverflow.ellipsis))),
                    ])))),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
              AppSpacing.lg, AppSpacing.lg + navBarClearance(context)),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                mainAxisExtent: tileWidth * .85 + 215 * textScale),
            delegate: SliverChildBuilderDelegate(
                (context, index) => ProductCardWidget(
                    product: favorites[index],
                    width: double.infinity,
                    onPressed: (item) => context.push('/produit/${item.id}')),
                childCount: favorites.length),
          ),
        ),
      ]);
    });
  }
}
