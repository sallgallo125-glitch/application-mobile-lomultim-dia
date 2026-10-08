import 'package:flutter/material.dart';

import '../../contracts/category.dart';
import '../../contracts/product.dart';
import '../../features/catalog/shop_filters.dart';
import '../../theme/tokens.dart';
import '../../utils/currency.dart';

/// Opens the full "Filtres" page (sort, category, price, brand, rating,
/// stock, promo). Returns the new state, or null when closed with ✕.
Future<ShopFilterState?> showShopFiltersSheet(
  BuildContext context, {
  required List<ProductSummary> products,
  required List<Category> categories,
  required ShopFilterState initial,
  String query = '',
  bool showSort = true,
}) =>
    showModalBottomSheet<ShopFilterState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Above the bottom navigation bar, so the footer stays reachable.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopFiltersSheet(
          products: products,
          categories: categories,
          initial: initial,
          query: query,
          showSort: showSort),
    );

/// Opens a quick bottom sheet specifically for selecting the sorting option.
Future<CatalogSort?> showSortSheet(
  BuildContext context, {
  required CatalogSort current,
}) =>
    showModalBottomSheet<CatalogSort>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: AppColors.white,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.swap_vert, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Trier par',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final s in CatalogSort.values)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  s == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: s == current ? AppColors.primary : AppColors.textSecondary,
                  size: 20,
                ),
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontWeight: s == current ? FontWeight.w800 : FontWeight.w500,
                    color: s == current ? AppColors.primary : AppColors.text,
                  ),
                ),
                onTap: () => Navigator.pop(context, s),
              ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
          ],
        ),
      ),
    );

/// Quick price ranges under the slider.
const _priceRanges = [
  ('< 50 000', null, 50000),
  ('50 – 200 000', 50000, 200000),
  ('200 – 500 000', 200000, 500000),
  ('> 500 000', 500000, null),
];

class ShopFiltersSheet extends StatefulWidget {
  const ShopFiltersSheet(
      {super.key,
      required this.products,
      required this.categories,
      required this.initial,
      this.query = '',
      this.showSort = true});
  final List<ProductSummary> products;
  final List<Category> categories;
  final ShopFilterState initial;
  final String query;
  final bool showSort;

  @override
  State<ShopFiltersSheet> createState() => _ShopFiltersSheetState();
}

class _ShopFiltersSheetState extends State<ShopFiltersSheet> {
  late ShopFilterState f = widget.initial;
  bool _allBrands = false;
  String _brandQuery = '';

  late final int _priceFloor = widget.products.isEmpty
      ? 0
      : widget.products.map((p) => p.priceXof).reduce((a, b) => a < b ? a : b);
  late final int _priceCeil = widget.products.isEmpty
      ? 1000000
      : widget.products.map((p) => p.priceXof).reduce((a, b) => a > b ? a : b);

  int get _resultCount =>
      applyShopFilters(widget.products, f, query: widget.query, sort: false)
          .length;

  void _set(ShopFilterState next) => setState(() => f = next);

  @override
  Widget build(BuildContext context) {
    final count = _resultCount;
    // Material (not a coloured box) so list tiles keep their ink effects.
    return Material(
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: Column(children: [
          // Header: ✕ · Filtres · Effacer
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Row(children: [
              IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
              const Expanded(
                child: Text('Filtres',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              TextButton(
                  onPressed:
                      f.activeCount == 0 ? null : () => _set(f.cleared()),
                  child: const Text('Effacer')),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                if (widget.showSort)
                  _Section(
                    title: 'Trier par',
                    child: Column(children: [
                      for (final s in CatalogSort.values)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            s == f.sort
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: s == f.sort
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          title: Text(s.label),
                          onTap: () => _set(f.copyWith(sort: s)),
                        ),
                    ]),
                  ),
                if (widget.categories.isNotEmpty)
                  _Section(
                    title: 'Catégorie',
                    badge: f.categoryIds.length,
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in widget.categories)
                        FilterChip(
                          label: Text(c.name),
                          selected: f.categoryIds.contains(c.id),
                          onSelected: (on) => _set(f.copyWith(
                              categoryIds: on
                                  ? {...f.categoryIds, c.id}
                                  : ({...f.categoryIds}..remove(c.id)))),
                        ),
                    ]),
                  ),
                _Section(
                  title: 'Prix (FCFA)',
                  badge: f.minPriceXof != null || f.maxPriceXof != null ? 1 : 0,
                  child: _priceBlock(),
                ),
                _Section(
                  title: 'Marque',
                  badge: f.brands.length,
                  child: _brandBlock(),
                ),
                _Section(
                  title: 'Note client',
                  badge: f.minRating == null ? 0 : 1,
                  child: Column(children: [
                    for (final stars in [4, 3])
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          f.minRating == stars
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: f.minRating == stars
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        title: Row(children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(i <= stars ? Icons.star : Icons.star_border,
                                size: 18, color: AppColors.gold),
                          const SizedBox(width: 6),
                          const Text('et plus'),
                        ]),
                        onTap: () => _set(f.copyWith(
                            minRating: () =>
                                f.minRating == stars ? null : stars)),
                      ),
                  ]),
                ),
                _Section(
                  title: 'Disponibilité et offres',
                  badge: (f.inStockOnly ? 1 : 0) + (f.promoOnly ? 1 : 0),
                  child: Column(children: [
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('En stock uniquement'),
                      value: f.inStockOnly,
                      onChanged: (v) => _set(f.copyWith(inStockOnly: v)),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('En promotion'),
                      value: f.promoOnly,
                      onChanged: (v) => _set(f.copyWith(promoOnly: v)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          // Footer: Effacer · Voir N produits
          Container(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  onPressed:
                      f.activeCount == 0 ? null : () => _set(f.cleared()),
                  child: const Text('Effacer'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  onPressed: () => Navigator.pop(context, f),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(count == 0
                        ? 'Aucun produit'
                        : 'Voir $count produit${count > 1 ? 's' : ''}'),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _priceBlock() {
    final lo = (f.minPriceXof ?? _priceFloor).clamp(_priceFloor, _priceCeil);
    final hi = (f.maxPriceXof ?? _priceCeil).clamp(lo, _priceCeil);
    final span = (_priceCeil - _priceFloor).clamp(1, 1 << 40);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RangeSlider(
        min: _priceFloor.toDouble(),
        max: _priceCeil.toDouble() + (span == 1 ? 1 : 0),
        divisions: 100,
        values: RangeValues(lo.toDouble(), hi.toDouble()),
        labels: RangeLabels(formatXof(lo), formatXof(hi)),
        onChanged: (v) {
          // Round to 1 000 FCFA; a handle at the end means "no limit".
          int round(double x) => (x / 1000).round() * 1000;
          final min = round(v.start), max = round(v.end);
          _set(f.copyWith(
              minPriceXof: () => min <= _priceFloor ? null : min,
              maxPriceXof: () => max >= _priceCeil ? null : max));
        },
      ),
      Row(children: [
        Expanded(child: _PriceBox(formatXof(lo))),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
        Expanded(child: _PriceBox(formatXof(hi))),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (label, min, max) in _priceRanges)
          ChoiceChip(
            label: Text(label),
            selected: f.minPriceXof == min && f.maxPriceXof == max,
            onSelected: (on) => _set(f.copyWith(
                minPriceXof: () => on ? min : null,
                maxPriceXof: () => on ? max : null)),
          ),
      ]),
    ]);
  }

  Widget _brandBlock() {
    final counts = <String, int>{};
    for (final p in widget.products) {
      counts[p.brand] = (counts[p.brand] ?? 0) + 1;
    }
    final all = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final q = _brandQuery.trim().toLowerCase();
    final matching = q.isEmpty
        ? all
        : all.where((b) => b.toLowerCase().contains(q)).toList();
    // Selected brands always stay visible.
    final shown = _allBrands || q.isNotEmpty
        ? matching
        : {...all.take(6), ...f.brands.where(all.contains)}.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (all.length > 6)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            onChanged: (v) => setState(() => _brandQuery = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Rechercher une marque',
              prefixIcon: const Icon(Icons.search, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      for (final brand in shown)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(brand),
          secondary: Text('${counts[brand]}',
              style: const TextStyle(color: AppColors.textSecondary)),
          value: f.brands.contains(brand),
          onChanged: (on) => _set(f.copyWith(
              brands: on == true
                  ? {...f.brands, brand}
                  : ({...f.brands}..remove(brand)))),
        ),
      if (!_allBrands && q.isEmpty && all.length > shown.length)
        TextButton(
          onPressed: () => setState(() => _allBrands = true),
          child: Text('Voir toutes les marques (${all.length}) ›'),
        ),
    ]);
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child:
              Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

/// Collapsible section with a title and an optional count badge.
class _Section extends StatefulWidget {
  const _Section({required this.title, required this.child, this.badge = 0});
  final String title;
  final Widget child;
  final int badge;
  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _open = true;
  @override
  Widget build(BuildContext context) => Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (widget.badge > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(99)),
                  child: Text('${widget.badge}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              Icon(_open ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: widget.child,
          ),
        const Divider(height: 1),
      ]);
}
