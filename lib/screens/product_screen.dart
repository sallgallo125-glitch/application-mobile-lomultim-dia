import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contracts/product.dart';
import '../features/catalog/catalog_providers.dart';
import '../features/cart/cart_providers.dart';
import '../features/customer/customer_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../utils/loyalty.dart';
import '../widgets/app_header.dart';
import '../widgets/badge_chip.dart';
import '../widgets/commerce/product_image.dart';
import '../widgets/commerce/product_rail.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/shimmer.dart';
import '../widgets/header_actions.dart';
import '../widgets/commerce/stepper_button.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  String? _variantId;
  final Set<String> _addonIds = {};

  /// Choice per option group (Mémoire RAM…); unset = the group's default.
  final Map<String, String> _choices = {};

  ProductOptionChoice _choiceOf(ProductOptionGroup group) {
    final id = _choices[group.id] ?? group.defaultChoiceId;
    return group.choices
        .firstWhere((c) => c.id == id, orElse: () => group.choices.first);
  }

  bool _adding = false;
  int _quantity = 1;
  static const _maxQuantity = 99;

  /// Cart line created by "Ajouter au panier", and the configuration it was
  /// added with. The −/+ buttons then change that line's quantity; another
  /// configuration (option, variant, add-on) shows "Ajouter" again.
  String? _lineId;
  String? _lineConfig;

  String _configKey(ProductDetail product) => [
        _effectiveVariant(product) ?? '',
        ...(_addonIds.toList()..sort()),
        for (final g in product.optionGroups) '${g.id}=${_choiceOf(g).id}',
      ].join('|');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) markViewed(ref, widget.productId);
    });
  }

  /// Native share sheet with the product name, price and link.
  void _share(ProductDetail product) {
    SharePlus.instance.share(ShareParams(
      subject: product.name,
      text: '${product.name} — ${formatXof(_unitPrice(product))}\n'
          'Disponible chez LO Multimédia : $shopUrl/products/${product.id}',
    ));
  }

  /// The chosen variant, or the first one in stock: the page always shows
  /// what will actually go into the cart.
  String? _effectiveVariant(ProductDetail product) {
    if (_variantId != null) return _variantId;
    for (final v in product.variants) {
      if (v.inStock) return v.id;
    }
    return product.variants.isEmpty ? null : product.variants.first.id;
  }

  ProductVariant? _variant(ProductDetail product) {
    final id = _effectiveVariant(product);
    for (final v in product.variants) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Price of one unit with the variant and the selected add-ons.
  int _unitPrice(ProductDetail product) =>
      product.priceXof +
      (_variant(product)?.priceDeltaXof ?? 0) +
      product.optionGroups
          .fold<int>(0, (sum, g) => sum + _choiceOf(g).priceDeltaXof) +
      product.addons
          .where((a) => _addonIds.contains(a.id))
          .fold<int>(0, (sum, a) => sum + a.priceXof);

  /// Adds the product with the selected variant and add-ons. Returns false
  /// (and tells the user) if it failed, so callers don't navigate on error.
  Future<bool> _addToCart(ProductDetail product) async {
    if (_adding) return false;
    _adding = true;
    try {
      await ref.read(cartActionsProvider).add(product.id,
          variantId: _effectiveVariant(product),
          addonIds: _addonIds,
          options: {
            for (final g in product.optionGroups) g.id: _choiceOf(g).id,
          },
          quantity: _quantity);
      // Find the cart line holding this configuration.
      final cart = await ref.read(cartProvider.future);
      final lines = cart.items.where((i) => i.productId == product.id);
      if (lines.isNotEmpty && mounted) {
        final config = _configKey(product);
        final known =
            lines.where((i) => i.id == _lineId && _lineConfig == config);
        setState(() {
          _lineId = known.isNotEmpty ? known.first.id : lines.last.id;
          _lineConfig = config;
        });
      }
      return true;
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Impossible d'ajouter ce produit. Réessayez.")));
      return false;
    } finally {
      _adding = false;
    }
  }

  /// Opens WhatsApp with the product, options and quantity pre-filled.
  void _askSupport(ProductDetail product) {
    final variant = _variant(product);
    final message = [
      'Bonjour, je suis intéressé(e) par : ${product.name}',
      if (variant != null) 'Option : ${variant.label}',
      for (final g in product.optionGroups)
        '${g.label} : ${_choiceOf(g).label}',
      for (final a in product.addons.where((a) => _addonIds.contains(a.id)))
        '+ ${a.name}',
      'Quantité : $_quantity',
      'Total : ${formatXof(_unitPrice(product) * _quantity)}',
    ].join('\n');
    launchUrl(
        Uri.parse(
            'https://wa.me/$supportWhatsApp?text=${Uri.encodeComponent(message)}'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _buyNow(ProductDetail product) async {
    if (await _addToCart(product) && mounted) {
      context.push('/commande/paiement');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productProvider(widget.productId));
    final product = detail.value;
    return Scaffold(
        backgroundColor: AppColors.background,
        // Always visible: price + add to cart / buy now. As the Scaffold's
        // bottom bar, snack bars appear above it instead of covering it.
        bottomNavigationBar: product == null
            ? null
            : Builder(builder: (context) {
                // Quantity of this configuration in the cart (null = not
                // added yet, or removed from the cart since).
                final line = _lineConfig == _configKey(product)
                    ? ref
                        .watch(cartProvider)
                        .value
                        ?.items
                        .where((i) => i.id == _lineId)
                        .firstOrNull
                    : null;
                final actions = ref.read(cartActionsProvider);
                return _BuyBar(
                  inCartQuantity: line?.quantity,
                  maxQuantity: _maxQuantity,
                  totalXof: _unitPrice(product) * (line?.quantity ?? 1),
                  inStock: _variant(product)?.inStock ?? product.inStock,
                  onIncrement: line == null
                      ? null
                      : () => actions.update(line.id, line.quantity + 1),
                  onDecrement: line == null
                      ? null
                      : () => line.quantity > 1
                          ? actions.update(line.id, line.quantity - 1)
                          : actions.remove(line.id),
                  onAdd: () async {
                    if (await _addToCart(product) && context.mounted) {
                      showAddedToCart(context, product.name);
                    }
                  },
                  onViewCart: () => context.go('/panier'),
                  onSupport: () => _askSupport(product),
                );
              }),
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              // The name is shown under the photo: no duplicate title here.
              AppHeader(
                  title: 'Fiche produit',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/boutique'),
                  actions: [
                    if (product != null)
                      HeaderAction(
                          icon: Icons.share_outlined,
                          label: 'Partager',
                          onPressed: () => _share(product)),
                    cartHeaderAction(context, ref),
                  ]),
              detail.when(
                loading: () => const LoadingState(
                    layout: SkeletonLayout.product,
                    label: 'Chargement du produit…'),
                error: (error, stackTrace) => ErrorState(
                    message: 'Impossible de charger ce produit pour le moment.',
                    onRetry: () =>
                        ref.invalidate(productProvider(widget.productId))),
                data: (product) => Expanded(
                  child: _ProductContent(
                      product: product,
                      variantId: _effectiveVariant(product),
                      addonIds: _addonIds,
                      onVariant: (id) => setState(() => _variantId = id),
                      onAddon: (id) => setState(() => _addonIds.contains(id)
                          ? _addonIds.remove(id)
                          : _addonIds.add(id)),
                      choices: {
                        for (final g in product.optionGroups)
                          g.id: _choiceOf(g).id,
                      },
                      onChoice: (group, choice) =>
                          setState(() => _choices[group] = choice),
                      onBuyNow: () => _buyNow(product)),
                ),
              ),
            ])));
  }
}

/// Page body, in the order of the "Mobile E-commerce App Design" mock-up:
/// brand · category + stock, title, rating, price + discount, benefits,
/// option chips, "Acheter maintenant", description, specs, "Bon à savoir",
/// reviews, "Vous aimerez aussi", "Consultés récemment".
class _ProductContent extends ConsumerStatefulWidget {
  const _ProductContent(
      {required this.product,
      required this.variantId,
      required this.addonIds,
      required this.onVariant,
      required this.onAddon,
      required this.choices,
      required this.onChoice,
      required this.onBuyNow});
  final ProductDetail product;
  final String? variantId;
  final Set<String> addonIds;
  final ValueChanged<String> onVariant;
  final ValueChanged<String> onAddon;

  /// Selected choice id per option group id.
  final Map<String, String> choices;
  final void Function(String groupId, String choiceId) onChoice;
  final VoidCallback onBuyNow;

  @override
  ConsumerState<_ProductContent> createState() => _ProductContentState();
}

class _ProductContentState extends ConsumerState<_ProductContent> {
  final _reviewsKey = GlobalKey();

  void _scrollToReviews() {
    final target = _reviewsKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    ProductVariant? selected;
    for (final item in product.variants) {
      if (item.id == widget.variantId) {
        selected = item;
        break;
      }
    }
    final price = product.priceXof +
        (selected?.priceDeltaXof ?? 0) +
        product.optionGroups.fold<int>(
            0,
            (sum, g) =>
                sum +
                (g.choices
                        .where((c) => c.id == widget.choices[g.id])
                        .firstOrNull
                        ?.priceDeltaXof ??
                    0));
    final inStock = selected?.inStock ?? product.inStock;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final category =
        categories.where((c) => c.id == product.categoryId).firstOrNull?.name;
    final photos = product.images.isNotEmpty
        ? product.images
        : [if (product.imageUrl != null) product.imageUrl!];
    final compareAt = product.compareAtPriceXof;
    final discount = compareAt != null && compareAt > price
        ? ((1 - price / compareAt) * 100).round()
        : 0;

    // "Vous aimerez aussi": the catalogue's similar products, or else the
    // same category.
    final all = ref.watch(productsProvider).value ?? const <ProductSummary>[];
    final similar = product.similarProductIds.isNotEmpty
        ? all.where((p) => product.similarProductIds.contains(p.id)).toList()
        : all
            .where(
                (p) => p.categoryId == product.categoryId && p.id != product.id)
            .take(8)
            .toList();
    final recentIds = ref
        .watch(recentlyViewedProvider)
        .where((id) => id != product.id)
        .toList();
    final recent = [
      for (final id in recentIds) ...all.where((p) => p.id == id),
    ];

    return ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          _Gallery(
              productId: product.id,
              categoryId: product.categoryId,
              photos: photos),
          // White sheet with rounded top corners, sliding over the photo
          // area like the reference design.
          Transform.translate(
            offset: const Offset(0, -_sheetOverlap),
            child: Container(
              // Shadow only; the Material below paints the white surface so
              // option tiles keep their ink effects.
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x140F173C),
                      blurRadius: 12,
                      offset: Offset(0, -4)),
                ],
              ),
              child: Material(
                color: AppColors.white,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand · category ............ ● En stock
                        Row(children: [
                          Expanded(
                            child: Text(
                                [product.brand, if (category != null) category]
                                    .join(' · ')
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StockDot(inStock: inStock),
                        ]),
                        const SizedBox(height: AppSpacing.xs),
                        if (product.badges.isNotEmpty) ...[
                          Wrap(spacing: AppSpacing.xs, children: [
                            for (final badge in product.badges)
                              BadgeChip(kind: badge)
                          ]),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(product.name,
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 22,
                                height: 1.25,
                                fontWeight: FontWeight.w800)),
                        if (product.rating != null)
                          InkWell(
                            onTap: product.reviews.isEmpty
                                ? null
                                : _scrollToReviews,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xs),
                              child: Row(children: [
                                const Icon(Icons.star,
                                    size: 17, color: Color(0xFFEDA830)),
                                const SizedBox(width: 4),
                                Text('${product.rating}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Flexible(
                                  child: Text(
                                      ' · ${product.reviewCount ?? 0} avis clients',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                ),
                                if (product.reviews.isNotEmpty)
                                  const Icon(Icons.chevron_right,
                                      size: 18, color: AppColors.textSecondary),
                              ]),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        // Price, then old price + discount pill.
                        Text(formatXof(price),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5)),
                        if (discount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(formatXof(compareAt!),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        decoration:
                                            TextDecoration.lineThrough)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.dangerSoft,
                                      borderRadius: BorderRadius.circular(5)),
                                  child: Text('−$discount %',
                                      style: const TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ),
                        if (discount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                                'Vous économisez ${formatXof(compareAt! - price)}',
                                style: AppText.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700)),
                          ),
                        if (loyaltyPointsFor(price) > 0)
                          Container(
                            margin: const EdgeInsets.only(top: AppSpacing.sm),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.stars_rounded,
                                  size: 16, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Flexible(child: Text(
                                  '+${loyaltyPointsFor(price)} points LO+ avec cet achat',
                                  style: AppText.caption.copyWith(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w700))),
                            ]),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        // Benefits strip.
                        const Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _Benefit(Icons.local_shipping_outlined,
                                'Livraison au Sénégal'),
                            _Benefit(Icons.verified_user_outlined,
                                'Garantie 12 mois'),
                            _Benefit(Icons.phone_android,
                                'Wave · Orange Money'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.lg),
                        if (product.variants.isNotEmpty)
                          _OptionGroup(
                            title: 'Version',
                            hint: selected?.label,
                            children: [
                              for (final item in product.variants)
                                _OptionChip(
                                  label: item.label,
                                  extra: item.priceDeltaXof == null
                                      ? null
                                      : '+${formatXof(item.priceDeltaXof!)}',
                                  selected: widget.variantId == item.id,
                                  enabled: item.inStock,
                                  onTap: () => widget.onVariant(item.id),
                                ),
                            ],
                          ),
                        for (final group in product.optionGroups)
                          _OptionGroup(
                            title: group.label,
                            hint: group.choices
                                .where((c) => c.id == widget.choices[group.id])
                                .firstOrNull
                                ?.label,
                            children: [
                              for (final choice in group.choices)
                                _OptionChip(
                                  label: choice.label,
                                  extra: choice.priceDeltaXof == 0
                                      ? null
                                      : '${choice.priceDeltaXof > 0 ? '+' : '−'}${formatXof(choice.priceDeltaXof.abs())}',
                                  selected:
                                      widget.choices[group.id] == choice.id,
                                  enabled: choice.inStock,
                                  onTap: () =>
                                      widget.onChoice(group.id, choice.id),
                                ),
                            ],
                          ),
                        if (product.addons.isNotEmpty)
                          _OptionGroup(
                            title: 'Complétez votre équipement',
                            hint: 'Optionnel',
                            children: [
                              for (final item in product.addons)
                                _OptionChip(
                                  label: item.name,
                                  extra: '+${formatXof(item.priceXof)}',
                                  selected: widget.addonIds.contains(item.id),
                                  enabled: true,
                                  onTap: () => widget.onAddon(item.id),
                                ),
                            ],
                          ),
                        if (inStock)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: widget.onBuyNow,
                              child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text('Acheter maintenant',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800)),
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ]),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        if (product.description != null)
                          _DetailSection(
                              title: 'Description',
                              child: _ExpandableText(product.description!)),
                        if (product.specifications.isNotEmpty)
                          _DetailSection(
                            title: 'Caractéristiques techniques',
                            child: _SpecTable(product.specifications),
                          ),
                        const _DetailSection(
                          title: 'Bon à savoir',
                          child: _ServiceGrid(children: [
                            _Service(
                                Icons.local_shipping_outlined,
                                'Livraison rapide',
                                'À Dakar et partout au Sénégal'),
                            _Service(
                                Icons.verified_user_outlined,
                                'Garantie 12 mois',
                                'Un achat en toute sérénité'),
                            _Service(Icons.replay, 'Retours faciles',
                                '7 jours pour changer d’avis'),
                            _Service(Icons.payments_outlined, 'Paiement',
                                'À la livraison ou au retrait en showroom'),
                          ]),
                        ),
                        if (product.reviews.isNotEmpty)
                          _DetailSection(
                            key: _reviewsKey,
                            title: 'Avis clients',
                            action: product.reviews.length > 2
                                ? ('Voir tout', () => _showAllReviews(product))
                                : null,
                            child: Column(children: [
                              _ReviewsHeader(product: product),
                              for (final review in product.reviews.take(2))
                                _ReviewCard(review: review),
                            ]),
                          ),
                      ]),
                ),
              ),
            ),
          ),
          if (similar.isNotEmpty) ...[
            const _RailTitle(title: 'Vous aimerez aussi'),
            ProductRail(products: similar),
          ],
          if (recent.isNotEmpty) ...[
            _RailTitle(
              title: 'Consultés récemment',
              arrow: false,
              action: (
                'Effacer',
                () => ref.read(recentlyViewedProvider.notifier).state = [
                      product.id
                    ],
              ),
            ),
            ProductRail(products: recent),
          ],
        ]);
  }

  void _showAllReviews(ProductDetail product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          children: [
            Text('Avis clients (${product.reviews.length})',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            _ReviewsHeader(product: product),
            for (final review in product.reviews) _ReviewCard(review: review),
          ],
        ),
      ),
    );
  }
}

/// Long text folded after a few lines, with "Lire la suite".
class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;
  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _foldedLines = 4;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textSecondary, height: 1.6);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: _foldedLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final long = painter.didExceedMaxLines;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSize(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: Text(widget.text,
              style: style,
              maxLines: _open || !long ? null : _foldedLines,
              overflow: _open || !long ? null : TextOverflow.fade),
        ),
        if (long)
          TextButton(
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primary),
            onPressed: () => setState(() => _open = !_open),
            child: Text(_open ? 'Réduire' : 'Lire la suite',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
      ]);
    });
  }
}

/// Striped key/value table; long lists show the first rows then "Voir tout".
class _SpecTable extends StatefulWidget {
  const _SpecTable(this.specs);
  final Map<String, String> specs;
  @override
  State<_SpecTable> createState() => _SpecTableState();
}

class _SpecTableState extends State<_SpecTable> {
  static const _folded = 5;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.specs.entries.toList();
    final shown = _open ? entries : entries.take(_folded).toList();
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(children: [
            for (var i = 0; i < shown.length; i++)
              Container(
                color: i.isEven ? AppColors.primarySoft : AppColors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child:
                              Text(shown[i].key, style: AppText.bodyMuted)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(shown[i].value,
                            textAlign: TextAlign.right,
                            style: AppText.body
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ]),
              ),
          ]),
        ),
      ),
      if (entries.length > _folded)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                foregroundColor: AppColors.primary),
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            label: Text(
                _open
                    ? 'Réduire'
                    : 'Voir toutes les caractéristiques (${entries.length})',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }
}

/// "Bon à savoir" services, two per row.
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - AppSpacing.sm) / 2;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final child in children)
                Container(
                  width: width,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: child,
                ),
            ],
          );
        },
      );
}

class _StockDot extends StatelessWidget {
  const _StockDot({required this.inStock});
  final bool inStock;
  @override
  Widget build(BuildContext context) {
    final color = inStock ? AppColors.success : AppColors.danger;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(inStock ? 'En stock' : 'Rupture',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ]);
}

/// "Title ......... hint" + a wrap of option chips.
class _OptionGroup extends StatelessWidget {
  const _OptionGroup({required this.title, this.hint, required this.children});
  final String title;
  final String? hint;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800))),
            if (hint != null)
              Text(hint!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: children),
        ]),
      );
}

class _OptionChip extends StatelessWidget {
  const _OptionChip(
      {required this.label,
      this.extra,
      required this.selected,
      required this.enabled,
      required this.onTap});
  final String label;
  final String? extra;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: Material(
            color: selected ? AppColors.primarySoft : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color:
                      selected ? AppColors.primary : AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary)),
                      if (extra != null)
                        Text(extra!,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary)),
                    ]),
              ),
            ),
          ),
        ),
      );
}

/// Section with a top rule, as in the mock-up (`.detail-section`).
class _DetailSection extends StatelessWidget {
  const _DetailSection(
      {super.key, required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final (String, VoidCallback)? action;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionHead(title: title, action: action, size: 16),
          const SizedBox(height: AppSpacing.sm),
          child,
        ]),
      );
}

/// "Title ............ Action →" (`.section-head`).
class _SectionHead extends StatelessWidget {
  const _SectionHead(
      {required this.title, this.action, this.size = 18, this.arrow = true});
  final String title;
  final (String, VoidCallback)? action;
  final double size;

  /// Arrow after the action label: only for links that open something.
  final bool arrow;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3))),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 4)),
            onPressed: action!.$2,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!.$1,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (arrow) ...[
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ]),
          ),
      ]);
}

/// Title above a full-width product rail.
class _RailTitle extends StatelessWidget {
  const _RailTitle({required this.title, this.action, this.arrow = true});
  final String title;
  final (String, VoidCallback)? action;
  final bool arrow;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
        child: _SectionHead(title: title, action: action, arrow: arrow),
      );
}

class _Service extends StatelessWidget {
  const _Service(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: AppText.subtitle.copyWith(fontSize: 13.5)),
        const SizedBox(height: 2),
        Text(subtitle, style: AppText.caption),
      ]);
}

class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final avgRating = product.rating ?? 4.8;
    final totalReviews = product.reviewCount ?? product.reviews.length;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rating Badge
              Column(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= avgRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 15,
                          color: const Color(0xFFEDA830),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalReviews avis',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              // Vertical divider line
              Container(
                width: 1,
                height: 56,
                color: AppColors.border,
              ),
              const SizedBox(width: AppSpacing.md),
              // Rating breakdown bars
              const Expanded(
                child: Column(
                  children: [
                    _RatingBarRow(stars: 5, pct: 0.85),
                    _RatingBarRow(stars: 4, pct: 0.12),
                    _RatingBarRow(stars: 3, pct: 0.03),
                    _RatingBarRow(stars: 2, pct: 0.00),
                    _RatingBarRow(stars: 1, pct: 0.00),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.xs),
          const Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 14, color: AppColors.success),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  '100% d\'avis authentiques d\'acheteurs vérifiés',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingBarRow extends StatelessWidget {
  const _RatingBarRow({required this.stars, required this.pct});
  final int stars;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text(
            '$stars★',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: const Color(0xFFE2E8F0),
                color: const Color(0xFFEDA830),
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 26,
            child: Text(
              '${(pct * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.review});
  final ProductReview review;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _liked = false;
  int _likesCount = 4;

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
    [Color(0xFF00B4DB), Color(0xFF0083B0)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    [Color(0xFFF7971E), Color(0xFFFFD200)],
  ];

  List<Color> _getGradient(String name) {
    final hash = name.hashCode.abs();
    return _avatarGradients[hash % _avatarGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final gradient = _getGradient(review.author);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  review.author.isEmpty ? '?' : review.author[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.author,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (review.verified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: .12),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 11, color: AppColors.success),
                                SizedBox(width: 3),
                                Text(
                                  'Achat vérifié',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        for (var k = 1; k <= 5; k++)
                          Icon(
                            k <= review.rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 13,
                            color: const Color(0xFFEDA830),
                          ),
                        const SizedBox(width: 6),
                        const Text(
                          'Avis certifié',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            review.comment,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () {
                setState(() {
                  _liked = !_liked;
                  _likesCount += _liked ? 1 : -1;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 14,
                      color:
                          _liked ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Utile ($_likesCount)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _liked ? FontWeight.w800 : FontWeight.w600,
                        color: _liked
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How far the content sheet slides over the photo area.
const double _sheetOverlap = 24;

/// Public website, used in shared product links.
const shopUrl = 'https://lomultimedia.com';

/// WhatsApp number of the shop (same as the site's contact page).
const supportWhatsApp = '221779980404';

/// Sticky bottom bar. Before adding: total + "Ajouter au panier". Once in
/// the cart: "− n +" (changes the cart quantity) + "Voir le panier".
class _BuyBar extends StatelessWidget {
  const _BuyBar(
      {required this.inCartQuantity,
      required this.maxQuantity,
      required this.totalXof,
      required this.inStock,
      required this.onIncrement,
      required this.onDecrement,
      required this.onAdd,
      required this.onViewCart,
      required this.onSupport});

  /// Quantity in the cart, or null when not added yet.
  final int? inCartQuantity;
  final int maxQuantity;
  final int totalXof;
  final bool inStock;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback onAdd;
  final VoidCallback onViewCart;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final added = inCartQuantity != null;
    final quantity = inCartQuantity ?? 0;
    return Material(
      color: AppColors.white,
      // Thin top border: separates the bar from the scrolling content.
      shape: const Border(top: BorderSide(color: AppColors.border)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (added) ...[
                // Shown only once the product is in the cart.
                const Text('Dans le panier',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: AppSpacing.sm),
                StepperButton.minus(
                    tooltip: quantity > 1
                        ? 'Diminuer la quantité'
                        : 'Retirer du panier',
                    size: 32,
                    onPressed: onDecrement),
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  label: 'Quantité dans le panier $quantity',
                  child: ExcludeSemantics(
                    child: Text('$quantity',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StepperButton.plus(
                    tooltip: 'Augmenter la quantité',
                    size: 32,
                    onPressed: quantity < maxQuantity ? onIncrement : null),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: added
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(added ? 'Total' : 'Prix',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: added
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(formatXof(totalXof),
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: added
                      ? OutlinedButton.icon(
                          onPressed: onViewCart,
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Voir le panier',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                          ))
                      : ElevatedButton.icon(
                          onPressed: inStock ? onAdd : null,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                                inStock
                                    ? 'Ajouter au panier'
                                    : 'Rupture de stock',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                          )),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox.square(
                dimension: 48,
                child: IconButton.filledTonal(
                    tooltip: 'Une question ? Écrivez-nous sur WhatsApp',
                    onPressed: onSupport,
                    icon: const Icon(Icons.support_agent)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Photo gallery: swipe between photos, thumbnails, heart on the photo,
/// tap to open full screen with pinch-to-zoom.
class _Gallery extends ConsumerStatefulWidget {
  const _Gallery(
      {required this.productId,
      required this.categoryId,
      required this.photos});
  final String productId;
  final String categoryId;
  final List<String> photos;
  @override
  ConsumerState<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends ConsumerState<_Gallery> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(i,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  void _openFullScreen() {
    if (widget.photos.isEmpty) return;
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullScreenPhotos(photos: widget.photos, initial: _index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final height = (MediaQuery.sizeOf(context).width * 0.8).clamp(240.0, 440.0);
    return Container(
      color: AppColors.white,
      child: Column(children: [
        SizedBox(
          height: height,
          child: Stack(children: [
            Positioned.fill(
              child: photos.isEmpty
                  ? ProductImage(
                      url: null, categoryId: widget.categoryId, iconSize: 72)
                  : PageView.builder(
                      controller: _pages,
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: _openFullScreen,
                        child: Semantics(
                          label:
                              'Photo ${i + 1} sur ${photos.length}, toucher pour agrandir',
                          image: true,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: ProductImage(
                                url: photos[i],
                                categoryId: widget.categoryId,
                                iconSize: 72,
                                fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x290F173C),
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: FavoriteButton(productId: widget.productId, size: 22),
              ),
            ),
          ]),
        ),
        if (photos.length > 1)
          Padding(
            // Bottom room for the content sheet that overlaps this area.
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg, AppSpacing.lg + _sheetOverlap),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < photos.length; i++)
                  Semantics(
                    button: true,
                    selected: i == _index,
                    label: 'Afficher la photo ${i + 1}',
                    child: GestureDetector(
                      onTap: () => _go(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: i == _index
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: i == _index ? 2 : 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(6),
                        child: ProductImage(
                            url: photos[i],
                            categoryId: widget.categoryId,
                            iconSize: 24,
                            fit: BoxFit.contain),
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          const SizedBox(height: _sheetOverlap),
      ]),
    );
  }
}

class _FullScreenPhotos extends StatelessWidget {
  const _FullScreenPhotos({required this.photos, required this.initial});
  final List<String> photos;
  final int initial;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop()),
        ),
        body: PageView.builder(
          controller: PageController(initialPage: initial),
          itemCount: photos.length,
          itemBuilder: (context, i) => InteractiveViewer(
            maxScale: 4,
            child: Center(
                child: ProductImage(url: photos[i], fit: BoxFit.contain)),
          ),
        ),
      );
}
