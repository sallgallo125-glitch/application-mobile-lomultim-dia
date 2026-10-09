import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/category.dart';
import '../contracts/product.dart';
import '../features/catalog/catalog_providers.dart';
import '../features/catalog/shop_filters.dart';
import '../features/home/home_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../widgets/app_header.dart';
import '../widgets/commerce/product_card.dart';
import '../widgets/commerce/shop_filters_sheet.dart';
import '../widgets/shimmer.dart' show shopGridColumnsFor;
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/search_field.dart';
import 'photo_search_screen.dart' show startPhotoSearch;
import '../widgets/nav_clearance.dart';

export '../features/catalog/shop_filters.dart' show CatalogSort;

/// Sort requested by another screen (e.g. "Les plus vendus → Voir"); the
/// shop applies it.
final shopSortRequestProvider = StateProvider<CatalogSort?>((ref) => null);

/// True when the shop was opened from a home "Nos rayons" circle: the shop
/// then shows a back button to the home page.
final shopOpenedFromHomeProvider = StateProvider<bool>((ref) => false);

class BoutiqueScreen extends ConsumerStatefulWidget {
  const BoutiqueScreen({super.key});
  @override
  ConsumerState<BoutiqueScreen> createState() => _BoutiqueScreenState();
}

class _BoutiqueScreenState extends ConsumerState<BoutiqueScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(globalSearchQueryProvider));
    final sort = ref.read(shopSortRequestProvider);
    if (sort != null) {
      Future.microtask(() =>
          _setFilters(ref.read(shopFiltersProvider).copyWith(sort: sort)));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilters(ShopFilterState f) =>
      ref.read(shopFiltersProvider.notifier).state = f;

  Future<void> _openFilters(
      List<ProductSummary> products, List<Category> categories) async {
    final result = await showShopFiltersSheet(context,
        products: products,
        categories: categories,
        initial: ref.read(shopFiltersProvider),
        query: _search.text);
    if (result != null && mounted) _setFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final filters = ref.watch(shopFiltersProvider);
    ref.listen(shopSortRequestProvider, (_, sort) {
      if (sort != null) _setFilters(filters.copyWith(sort: sort));
    });
    final loading = productsAsync.isLoading || categoriesAsync.isLoading;
    final failed = productsAsync.hasError || categoriesAsync.hasError;
    ref.listen(globalSearchQueryProvider, (_, next) {
      if (_search.text != next) {
        _search.value = TextEditingValue(text: next);
      }
    });
    final products = productsAsync.value ?? const <ProductSummary>[];
    final categories = categoriesAsync.value ?? const <Category>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
          bottom: false,
          child: Column(children: [
            AppHeader(
              title: '',
              onBack: ref.watch(shopOpenedFromHomeProvider)
                  ? () {
                      ref.read(shopOpenedFromHomeProvider.notifier).state =
                          false;
                      context.go('/');
                    }
                  : null,
              searchField: SearchField(
                  controller: _search,
                  placeholder: 'Rechercher un produit, une marque…',
                  onCamera: () => startPhotoSearch(context),
                  onChanged: (value) {
                    ref.read(globalSearchQueryProvider.notifier).state = value;
                    setState(() {});
                  }),
            ),
            if (loading)
              const LoadingState(
                  label: 'Chargement des produits…',
                  layout: SkeletonLayout.grid)
            else if (failed)
              ErrorState(
                  message: 'Impossible de charger la boutique pour le moment.',
                  onRetry: () {
                    ref.invalidate(productsProvider);
                    ref.invalidate(categoriesProvider);
                  })
            else
              Expanded(
                  child: _Content(
                products:
                    applyShopFilters(products, filters, query: _search.text),
                categories: categories,
                filters: filters,
                onChanged: _setFilters,
                onOpenFilters: () => _openFilters(products, categories),
              )),
          ])),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content(
      {required this.products,
      required this.categories,
      required this.filters,
      required this.onChanged,
      required this.onOpenFilters});
  final List<ProductSummary> products;
  final List<Category> categories;
  final ShopFilterState filters;
  final ValueChanged<ShopFilterState> onChanged;
  final VoidCallback onOpenFilters;

  /// Removable chips for every active filter.
  List<Widget> _activeChips() {
    final f = filters;
    final names = {for (final c in categories) c.id: c.name};
    Widget chip(String label, ShopFilterState without) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: InputChip(
            label: Text(label),
            onDeleted: () => onChanged(without),
            deleteButtonTooltipMessage: 'Retirer',
            backgroundColor: AppColors.primarySoft,
            side: BorderSide.none,
            labelStyle: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        );
    String price() {
      if (f.minPriceXof != null && f.maxPriceXof != null) {
        return '${formatXof(f.minPriceXof!)} – ${formatXof(f.maxPriceXof!)}';
      }
      return f.minPriceXof != null
          ? 'Dès ${formatXof(f.minPriceXof!)}'
          : 'Jusqu’à ${formatXof(f.maxPriceXof!)}';
    }

    return [
      if (f.categoryIds.length > 1)
        for (final id in f.categoryIds)
          chip(names[id] ?? id,
              f.copyWith(categoryIds: {...f.categoryIds}..remove(id))),
      for (final b in f.brands)
        chip(b, f.copyWith(brands: {...f.brands}..remove(b))),
      if (f.minPriceXof != null || f.maxPriceXof != null)
        chip(price(),
            f.copyWith(minPriceXof: () => null, maxPriceXof: () => null)),
      if (f.minRating != null)
        chip('${f.minRating}★ et plus', f.copyWith(minRating: () => null)),
      if (f.inStockOnly) chip('En stock', f.copyWith(inStockOnly: false)),
      if (f.promoOnly) chip('En promotion', f.copyWith(promoOnly: false)),
    ];
  }

  /// Category chips: scroll away with the products (not pinned).
  Widget _categoryRow() {
    final single =
        filters.categoryIds.length == 1 ? filters.categoryIds.first : null;
    return Container(
        color: AppColors.white,
        height: 56,
        child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            children: [
              _Chip(
                  label: 'Tout',
                  selected: filters.categoryIds.isEmpty,
                  onPressed: () =>
                      onChanged(filters.copyWith(categoryIds: {}))),
              for (final category in categories)
                _Chip(
                    label: category.name,
                    selected: single == category.id,
                    onPressed: () => onChanged(
                        filters.copyWith(categoryIds: {category.id}))),
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final chips = _activeChips();
    // Pinned once it reaches the search bar: white, like the header.
    final bar = DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: _ShopBar(
          categories: categories,
          filters: filters,
          onChanged: onChanged,
          onOpenFilters: onOpenFilters),
    );
    final activeChips = chips.isEmpty
        ? const SizedBox.shrink()
        : SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: 4),
              children: [
                ...chips,
                TextButton(
                    onPressed: () => onChanged(filters.cleared()),
                    child: const Text('Tout effacer')),
              ],
            ),
          );
    return products.isEmpty
        ? Column(children: [
            _categoryRow(),
            bar,
            activeChips,
            const Expanded(child: _Empty()),
          ])
        : _BackToTop(
            builder: (controller) =>
                LayoutBuilder(builder: (context, constraints) {
                  // 2 columns on phones, 3 on small tablets, 4 on large.
                  final columns = shopGridColumnsFor(constraints.maxWidth);
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final tileWidth = (constraints.maxWidth -
                          2 * AppSpacing.lg -
                          (columns - 1) * AppSpacing.sm) /
                      columns;
                  return CustomScrollView(controller: controller, slivers: [
                    // Categories scroll away; the filter bar sticks
                    // under the search.
                    SliverToBoxAdapter(child: _categoryRow()),
                    PinnedHeaderSliver(child: bar),
                    SliverToBoxAdapter(child: activeChips),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg + navBarClearance(context)),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            // Same card as the home rails.
                            mainAxisExtent: tileWidth * .85 + 215 * textScale),
                        delegate: SliverChildBuilderDelegate(
                            (context, index) => ProductCardWidget(
                                product: products[index],
                                width: double.infinity,
                                onPressed: (item) =>
                                    context.push('/produit/${item.id}')),
                            childCount: products.length),
                      ),
                    ),
                  ]);
                }));
  }
}

/// Filter/sort row, pinned under the search while the products scroll.
class _ShopBar extends StatelessWidget {
  const _ShopBar(
      {required this.categories,
      required this.filters,
      required this.onChanged,
      required this.onOpenFilters});
  final List<Category> categories;
  final ShopFilterState filters;
  final ValueChanged<ShopFilterState> onChanged;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: onOpenFilters,
            icon: const Icon(Icons.tune, size: 18),
            label: Text(filters.activeCount > 0
                ? 'Filtres · ${filters.activeCount}'
                : 'Filtres'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final sort =
                      await showSortSheet(context, current: filters.sort);
                  if (sort != null) onChanged(filters.copyWith(sort: sort));
                },
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(filters.sort.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: AppSpacing.xs),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onPressed});
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onPressed()));
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('Aucun produit ne correspond à votre recherche.'));
}

/// "Back to top" button over a scrolling list: it appears only while the
/// customer scrolls UP (far enough from the top) and hides when scrolling
/// down or back at the top.
class _BackToTop extends StatefulWidget {
  const _BackToTop({required this.builder});
  final Widget Function(ScrollController controller) builder;
  @override
  State<_BackToTop> createState() => _BackToTopState();
}

class _BackToTopState extends State<_BackToTop> {
  final _controller = ScrollController();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final position = _controller.position;
    final show = position.userScrollDirection == ScrollDirection.forward &&
            position.pixels > 400 ||
        (_visible &&
            position.userScrollDirection == ScrollDirection.idle &&
            position.pixels > 400);
    if (show != _visible) setState(() => _visible = show);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.builder(_controller),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.lg + navBarClearance(context),
          child: Center(
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, 1.5),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Material(
                    // See-through background; the text stays fully readable.
                    color: AppColors.primaryDark.withValues(alpha: .65),
                    elevation: 0,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () {
                        setState(() => _visible = false);
                        _controller.animateTo(0,
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.arrow_upward_rounded,
                              size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Haut de page',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
}
