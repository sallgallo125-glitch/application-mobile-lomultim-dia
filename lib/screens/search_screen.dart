import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/category.dart';
import '../contracts/product.dart';
import '../features/catalog/catalog_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/commerce/product_card.dart';
import '../widgets/error_state.dart';
import '../widgets/header_actions.dart';
import '../widgets/loading_state.dart';
import '../widgets/search_field.dart';
import 'photo_search_screen.dart' show startPhotoSearch;
import '../widgets/shimmer.dart' show shopGridColumnsFor;
import '../features/catalog/shop_filters.dart';
import '../widgets/commerce/shop_filters_sheet.dart';

/// Searches shown before typing.
const searchSuggestions = [
  'Ordinateur portable',
  'HP',
  'iPhone',
  'Samsung',
  'Téléviseur',
  'Imprimante',
  'Lenovo',
  'Écran',
];

/// Lower-case text without French accents, so "television" finds "Téléviseur".
String normalizeSearch(String text) {
  const from = 'àâäáãéèêëíìîïóòôöõúùûüçñÿ';
  const to = 'aaaaaeeeeiiiiooooouuuucny';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}

/// Everyday words customers type, mapped to words found in product names
/// (accent-free, lower-case).
const _synonyms = {
  'ordinateur': ['probook', 'thinkpad', 'vivobook', ' pc '],
  'ordi': ['probook', 'thinkpad', 'vivobook', ' pc '],
  'laptop': ['probook', 'thinkpad', 'vivobook', ' pc '],
  'pc': ['probook', 'thinkpad', 'vivobook'],
  'portable': [
    'probook',
    'thinkpad',
    'vivobook',
    ' pc ',
    'iphone',
    'galaxy',
    'redmi',
    'camon'
  ],
  'telephone': ['iphone', 'galaxy', 'redmi', 'camon'],
  'smartphone': ['iphone', 'galaxy', 'redmi', 'camon'],
  'tele': ['televiseur'],
  'tv': ['televiseur'],
  'ecran': ['televiseur', 'videoprojecteur'],
};

/// Full-screen search opened from the home search bar: suggestions and
/// recent searches before typing, live results grid while typing.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  /// Search filters (separate from the shop's saved filters).
  ShopFilterState _filters = const ShopFilterState();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _query => _controller.text.trim();

  void _searchFor(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    rememberSearch(ref, text);
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  List<ProductSummary> _results(
      List<ProductSummary> products, List<Category> categories,
      {bool filtered = true}) {
    final words = normalizeSearch(_query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final categoryNames = {for (final c in categories) c.id: c.name};
    final source = filtered ? applyShopFilters(products, _filters) : products;
    return source.where((p) {
      final haystack = ' ' +
          normalizeSearch(
              '${p.name} ${p.brand} ${categoryNames[p.categoryId] ?? ''}');
      // "mac book" also matches "MacBook".
      final compact = haystack.replaceAll(' ', '');
      return words.every((w) =>
          haystack.contains(w) ||
          compact.contains(w) ||
          (_synonyms[w] ?? const []).any(haystack.contains));
    }).toList();
  }

  Future<void> _showFilters(
      List<ProductSummary> products, List<Category> categories) async {
    final result = await showShopFiltersSheet(context,
        products: _results(products, categories, filtered: false),
        categories: categories,
        initial: _filters);
    if (result != null && mounted) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final products = productsAsync.value ?? const <ProductSummary>[];
    final filtered =
        _filters.activeCount > 0 || _filters.sort != CatalogSort.relevance;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(
            title: 'Recherche',
            onBack: () => context.canPop() ? context.pop() : context.go('/'),
            actions: [cartHeaderAction(context, ref)],
            searchField: Row(children: [
              Expanded(
                child: SearchField(
                  controller: _controller,
                  placeholder: 'Rechercher un produit…',
                  autofocus: true,
                  showClear: true,
                  onCamera: () => startPhotoSearch(context),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _searchFor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: filtered ? AppColors.gold : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: IconButton(
                  tooltip: 'Filtres',
                  icon: const Icon(Icons.tune, color: AppColors.primary),
                  onPressed: () => _showFilters(products, categories),
                ),
              ),
            ]),
          ),
          if (productsAsync.isLoading)
            const LoadingState(
                label: 'Chargement des produits…', layout: SkeletonLayout.grid)
          else if (productsAsync.hasError)
            ErrorState(
                message: 'Impossible de charger les produits pour le moment.',
                onRetry: () => ref.invalidate(productsProvider))
          else if (_query.isEmpty)
            Expanded(child: _Suggestions(onPick: _searchFor))
          else
            Expanded(
              child: _Results(
                query: _query,
                results: _results(products, categories),
                onPick: _searchFor,
                onOpen: (product) {
                  rememberSearch(ref, _query);
                  context.push('/produit/${product.id}');
                },
              ),
            ),
        ]),
      ),
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (recent.isNotEmpty) ...[
          Row(children: [
            const Expanded(child: _Title('Recherches récentes')),
            TextButton(
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).state = const [],
              child: const Text('Effacer'),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _Pills(items: recent, icon: Icons.history, onPick: onPick),
          const SizedBox(height: AppSpacing.xl),
        ],
        const _Title('Suggestions'),
        const SizedBox(height: AppSpacing.md),
        _Pills(items: searchSuggestions, onPick: onPick),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text));
}

class _Pills extends StatelessWidget {
  const _Pills({required this.items, required this.onPick, this.icon});
  final List<String> items;
  final ValueChanged<String> onPick;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final item in items)
            ActionChip(
              avatar: icon == null
                  ? null
                  : Icon(icon, size: 16, color: AppColors.textSecondary),
              label: Text(item),
              labelStyle: const TextStyle(color: AppColors.text, fontSize: 14),
              backgroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
              onPressed: () => onPick(item),
            ),
        ],
      );
}

class _Results extends StatelessWidget {
  const _Results(
      {required this.query,
      required this.results,
      required this.onPick,
      required this.onOpen});
  final String query;
  final List<ProductSummary> results;
  final ValueChanged<String> onPick;
  final ValueChanged<ProductSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Aucun résultat pour « $query »',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          const Text('Vérifiez l’orthographe ou essayez une suggestion.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          const _Title('Suggestions'),
          const SizedBox(height: AppSpacing.md),
          _Pills(items: searchSuggestions, onPick: onPick),
        ],
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = shopGridColumnsFor(constraints.maxWidth);
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final tileWidth = (constraints.maxWidth -
              2 * AppSpacing.lg -
              (columns - 1) * AppSpacing.sm) /
          columns;
      return CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
                '${results.length} résultat${results.length > 1 ? 's' : ''} pour « $query »',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                mainAxisExtent: tileWidth * .85 + 215 * textScale),
            itemCount: results.length,
            itemBuilder: (context, index) => ProductCardWidget(
                product: results[index],
                width: double.infinity,
                onPressed: onOpen),
          ),
        ),
      ]);
    });
  }
}
