import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contracts/product.dart';
import '../features/catalog/catalog_providers.dart';
import '../features/cart/cart_providers.dart';
import '../features/account/account_providers.dart';
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
  final int _quantity = 1;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Impossible d'ajouter ce produit. Réessayez.")));
      }
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
                      onSupport: () => _askSupport(product)),
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
      required this.onSupport});
  final ProductDetail product;
  final String? variantId;
  final Set<String> addonIds;
  final ValueChanged<String> onVariant;
  final ValueChanged<String> onAddon;

  /// Selected choice id per option group id.
  final Map<String, String> choices;
  final void Function(String groupId, String choiceId) onChoice;
  /// Opens WhatsApp about this product.
  final VoidCallback onSupport;

  @override
  ConsumerState<_ProductContent> createState() => _ProductContentState();
}

class _ProductContentState extends ConsumerState<_ProductContent> {
  final _reviewsKey = GlobalKey<_FoldSectionState>();

  void _scrollToReviews() {
    _reviewsKey.currentState?.open();
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

    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _Gallery(
                productId: product.id,
                categoryId: product.categoryId,
                photos: photos),
            // White sheet with rounded top corners, sliding over the grey
            // photo area; the rails below sit on the same grey.
            Transform.translate(
              offset: const Offset(0, -_sheetOverlap),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      // Shadow only; the Material below paints the white
                      // surface so option tiles keep their ink effects.
                      decoration: const BoxDecoration(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
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
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24))),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                              AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Brand · category ........ ● En stock
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                        [
                                          product.brand,
                                          if (category != null) category
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.caption.copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
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
                                        fontWeight: FontWeight.w700)),
                                if (product.rating != null)
                                  InkWell(
                                    onTap: product.reviews.isEmpty
                                        ? null
                                        : _scrollToReviews,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.xs),
                                      child: Row(children: [
                                        const Icon(Icons.star,
                                            size: 16, color: _reviewStar),
                                        const SizedBox(width: 4),
                                        Text('${product.rating}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        Flexible(
                                          child: Text(
                                              '  (${product.reviewCount ?? 0} avis)',
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.bodyMuted),
                                        ),
                                      ]),
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.md),
                                Text(formatXof(price),
                                    style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.5)),
                                // Old price + discount: the page's only red.
                                if (discount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: AppSpacing.xs),
                                    child: Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.xs,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(formatXof(compareAt!),
                                            style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 14,
                                                decoration: TextDecoration
                                                    .lineThrough)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: AppColors.dangerSoft,
                                              borderRadius:
                                                  BorderRadius.circular(5)),
                                          child: Text('−$discount %',
                                              style: const TextStyle(
                                                  color: AppColors.danger,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                        ),
                                        Text(
                                            'soit ${formatXof(compareAt - price)} d’économie',
                                            style: AppText.caption),
                                      ],
                                    ),
                                  ),
                                if (loyaltyPointsFor(price) > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: AppSpacing.sm),
                                    child: Row(children: [
                                      const Icon(Icons.stars_rounded,
                                          size: 16, color: AppColors.gold),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                            '+${loyaltyPointsFor(price)} points LO+ avec cet achat',
                                            style: AppText.caption
                                                .copyWith(fontSize: 13)),
                                      ),
                                    ]),
                                  ),
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(
                                    height: 1, color: AppColors.border),
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
                                          onTap: () =>
                                              widget.onVariant(item.id),
                                        ),
                                    ],
                                  ),
                                for (final group in product.optionGroups)
                                  _OptionGroup(
                                    title: group.label,
                                    hint: group.choices
                                        .where((c) =>
                                            c.id == widget.choices[group.id])
                                        .firstOrNull
                                        ?.label,
                                    children: [
                                      for (final choice in group.choices)
                                        _OptionChip(
                                          label: choice.label,
                                          extra: choice.priceDeltaXof == 0
                                              ? null
                                              : '${choice.priceDeltaXof > 0 ? '+' : '−'}${formatXof(choice.priceDeltaXof.abs())}',
                                          selected: widget.choices[group.id] ==
                                              choice.id,
                                          enabled: choice.inStock,
                                          onTap: () => widget.onChoice(
                                              group.id, choice.id),
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
                                          selected: widget.addonIds
                                              .contains(item.id),
                                          enabled: true,
                                          onTap: () => widget.onAddon(item.id),
                                        ),
                                    ],
                                  ),
                                const _ServiceBlock(),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.md)),
                                  onPressed: widget.onSupport,
                                  icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18),
                                  label: const Text(
                                      'Une question ? Écrivez-nous sur WhatsApp',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (product.description != null)
                                  _FoldSection(
                                      title: 'Description',
                                      initiallyOpen: true,
                                      child: _ExpandableText(
                                          product.description!)),
                                if (product.specifications.isNotEmpty)
                                  _FoldSection(
                                    title: 'Caractéristiques techniques',
                                    count: product.specifications.length,
                                    child: _SpecTable(product.specifications),
                                  ),
                                _FoldSection(
                                  key: _reviewsKey,
                                  title: 'Avis clients',
                                  count: product.reviews.isEmpty
                                      ? null
                                      : product.reviewCount ??
                                          product.reviews.length,
                                  initiallyOpen: product.reviews.isEmpty,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (product.reviews.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.only(
                                                bottom: AppSpacing.md),
                                            child: Text(
                                                'Aucun avis pour le moment. Soyez le premier à partager votre expérience.',
                                                style: AppText.bodyMuted),
                                          )
                                        else ...[
                                          _ReviewsTitle(
                                              count: product.reviewCount ??
                                                  product.reviews.length,
                                              onSeeAll: () =>
                                                  _showAllReviews(product)),
                                          for (final review
                                              in product.reviews.take(3))
                                            _ReviewCard(review: review),
                                          const SizedBox(
                                              height: AppSpacing.sm),
                                        ],
                                        SizedBox(
                                          width: double.infinity,
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primary,
                                                side: const BorderSide(
                                                    color: AppColors.primary),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            AppRadii.md))),
                                            onPressed: () =>
                                                _writeReview(product),
                                            icon: const Icon(
                                                Icons.rate_review_outlined,
                                                size: 18),
                                            label: const Text(
                                                'Donner mon avis',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                        ),
                                      ]),
                                ),
                              ]),
                        ),
                      ),
                    ),
                    if (similar.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      const _RailTitle(title: 'Vous aimerez aussi'),
                      ProductRail(products: similar),
                    ],
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _RailTitle(
                        title: 'Consultés récemment',
                        arrow: false,
                        action: (
                          'Effacer',
                          () => ref
                              .read(recentlyViewedProvider.notifier)
                              .state = [product.id],
                        ),
                      ),
                      ProductRail(products: recent),
                    ],
                  ]),
            ),
          ]),
    );
  }

  /// Review form; asks to sign in first, since reviews carry a name.
  Future<void> _writeReview(ProductDetail product) async {
    final user = ref.read(sessionUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Connectez-vous pour donner votre avis.'),
        action: SnackBarAction(
            label: 'Se connecter', onPressed: () => context.push('/connexion')),
      ));
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (_) => _WriteReviewSheet(
          productId: product.id, productName: product.name, author: user.name),
    );
    if (sent == true && mounted) {
      ref.invalidate(productProvider(product.id));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merci ! Votre avis est publié.')));
    }
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
      // Plain rows separated by hairlines.
      for (var i = 0; i < shown.length; i++)
        Container(
          decoration: i == 0
              ? null
              : const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border))),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(shown[i].key, style: AppText.bodyMuted)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(shown[i].value,
                  textAlign: TextAlign.right,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
            ),
          ]),
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

/// "Title ............ Action →" (`.section-head`).
class _SectionHead extends StatelessWidget {
  const _SectionHead(
      {required this.title, this.action, this.arrow = true});
  final String title;
  final (String, VoidCallback)? action;

  /// Arrow after the action label: only for links that open something.
  final bool arrow;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3))),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
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

/// Delivery first (the concrete promise), then warranty, returns and
/// payment as one quiet grey line each. Delays from the site's FAQ.
class _ServiceBlock extends StatelessWidget {
  const _ServiceBlock();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.local_shipping_outlined,
                  size: 20, color: AppColors.text),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Livré sous '),
                        TextSpan(
                            text: '24 h',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: ' à Dakar · 48 à 72 h ailleurs'),
                      ]),
                      style: AppText.body,
                    ),
                    Text('Retrait gratuit en showroom',
                        style: AppText.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text('Garantie 12 mois · Retour sous 7 jours',
              style: AppText.bodyMuted.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text('Wave · Orange Money · paiement à la livraison',
              style: AppText.bodyMuted.copyWith(fontSize: 13)),
        ]),
      );
}

/// Accordion section with a top rule: "Title (n) ............ ⌄".
class _FoldSection extends StatefulWidget {
  const _FoldSection(
      {super.key,
      required this.title,
      this.count,
      this.initiallyOpen = false,
      required this.child});
  final String title;
  final int? count;
  final bool initiallyOpen;
  final Widget child;
  @override
  State<_FoldSection> createState() => _FoldSectionState();
}

class _FoldSectionState extends State<_FoldSection> {
  late bool _open = widget.initiallyOpen;

  void open() {
    if (!_open) setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return DecoratedBox(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Text(
                      widget.count == null
                          ? widget.title
                          : '${widget.title} (${widget.count})',
                      style: AppText.subtitle),
                ),
                AnimatedRotation(
                  turns: _open ? .5 : 0,
                  duration: duration,
                  child: const Icon(Icons.expand_more,
                      color: AppColors.textSecondary),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: widget.child)
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

/// Average, stars and how the shown reviews spread across 1–5 stars,
/// computed from the real reviews only.
class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final reviews = product.reviews;
    final average = product.rating ??
        reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;
    final total = product.reviewCount ?? reviews.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        Column(children: [
          Text(average.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1)),
          const SizedBox(height: 4),
          _Stars(rating: average, size: 14),
          const SizedBox(height: 4),
          Text('$total avis', style: AppText.caption),
        ]),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(children: [
            for (var stars = 5; stars >= 1; stars--)
              _RatingBar(
                  stars: stars,
                  count:
                      reviews.where((r) => r.rating.round() == stars).length,
                  of: reviews.length),
          ]),
        ),
      ]),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.stars, required this.count, required this.of});
  final int stars;
  final int count;
  final int of;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
              width: 12,
              child: Text('$stars',
                  style: AppText.caption.copyWith(fontSize: 11))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: of == 0 ? 0 : count / of,
                minHeight: 5,
                backgroundColor: _reviewAvatarBg,
                color: _reviewStar,
              ),
            ),
          ),
          SizedBox(
              width: 22,
              child: Text('$count',
                  textAlign: TextAlign.right,
                  style: AppText.caption.copyWith(fontSize: 11))),
        ]),
      );
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});
  final num rating;
  final double size;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= rating.round() ? Icons.star : Icons.star_border,
              size: size, color: _reviewStar),
      ]);
}

/// Review colours taken from the reference design: red stars, purple-grey
/// secondary text, light grey avatar.
const _reviewStar = Color(0xFFF5414B);
const _reviewMuted = Color(0xFF9A98AA);
const _reviewAvatarBg = Color(0xFFE9E9F0);
const _reviewAvatarIcon = Color(0xFFB4B3C2);

/// "Avis 235 ............ Tout voir >"
class _ReviewsTitle extends StatelessWidget {
  const _ReviewsTitle({required this.count, this.onSeeAll});
  final int count;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              const TextSpan(
                  text: 'Avis ',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              TextSpan(
                  text: '$count',
                  style: const TextStyle(
                      color: _reviewMuted,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
            ])),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tout voir',
                      style: TextStyle(color: AppColors.text, fontSize: 16)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 22, color: _reviewMuted),
                ]),
              ),
            ),
        ]),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
                color: _reviewAvatarBg, shape: BoxShape.circle),
            child: const Icon(Icons.person, size: 24, color: _reviewAvatarIcon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.author,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                  child: Text(
                      review.verified ? 'Achat vérifié' : 'Client LO Multimédia',
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: _reviewMuted, fontSize: 14)),
                ),
                if (review.verified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle,
                      size: 15, color: AppColors.success),
                ],
              ]),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus d’options',
            icon: const Icon(Icons.more_vert, color: _reviewMuted),
            onSelected: (_) => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Merci, cet avis a été signalé.'))),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Signaler cet avis')),
            ],
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= review.rating.round() ? Icons.star : Icons.star_border,
                size: 20, color: _reviewStar),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(review.comment,
            style: const TextStyle(
                color: AppColors.text, fontSize: 15, height: 1.4)),
      ]),
    );
  }
}

/// How far the content sheet slides over the photo area.
const double _sheetOverlap = 24;

/// Public website, used in shared product links.
const shopUrl = 'https://lomultimedia.com';

/// WhatsApp number of the shop (same as the site's contact page).
const supportWhatsApp = '221779980404';

/// Sticky bottom bar. Before adding: price + "Ajouter au panier". Once in
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
      required this.onViewCart});

  /// Quantity in the cart, or null when not added yet.
  final int? inCartQuantity;
  final int maxQuantity;
  final int totalXof;
  final bool inStock;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback onAdd;
  final VoidCallback onViewCart;

  static const _label = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final added = inCartQuantity != null;
    final quantity = inCartQuantity ?? 0;
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md));
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
                    style: TextStyle(fontWeight: FontWeight.w600)),
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
                            fontSize: 16, fontWeight: FontWeight.w700)),
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
                      Text(added ? 'Total' : 'Prix', style: AppText.caption),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: added
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(formatXof(totalXof),
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 48,
              child: added
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(shape: buttonShape),
                          onPressed: onViewCart,
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const Text('Voir le panier', style: _label)),
                    )
                  : !inStock
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                              style:
                                  ElevatedButton.styleFrom(shape: buttonShape),
                              onPressed: null,
                              child: const Text('Rupture de stock',
                                  style: _label)),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                              key: buyBarAddKey,
                              style:
                                  ElevatedButton.styleFrom(shape: buttonShape),
                              onPressed: onAdd,
                              icon: const Icon(Icons.add_shopping_cart,
                                  size: 20),
                              label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Ajouter au panier',
                                      style: _label))),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Ajouter" button of the buy bar (product cards below also say "Ajouter").
const buyBarAddKey = Key('buy-bar-add');

/// Photo gallery on a grey band: swipe between photos, dots + counter,
/// heart on the photo, tap to open full screen with pinch-to-zoom.
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
    return Column(children: [
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
                          padding: const EdgeInsets.all(AppSpacing.xl),
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
          if (photos.length > 1)
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text('${_index + 1}/${photos.length}',
                    style: AppText.caption.copyWith(
                        color: AppColors.text, fontWeight: FontWeight.w600)),
              ),
            ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: FavoriteButton(productId: widget.productId, size: 22),
            ),
          ),
        ]),
      ),
      // Dots, plus bottom room for the sheet that overlaps this area.
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md + _sheetOverlap),
        child: photos.length > 1
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < photos.length; i++)
                  Semantics(
                    button: true,
                    selected: i == _index,
                    label: 'Afficher la photo ${i + 1}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _go(i),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: i == _index ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? AppColors.text
                                : AppColors.textSecondary
                                    .withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
              ])
            : const SizedBox.shrink(),
      ),
    ]);
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

/// "Donner mon avis": 1–5 stars and a comment.
class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet(
      {required this.productId,
      required this.productName,
      required this.author});
  final String productId;
  final String productName;
  final String author;
  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  static const _labels = ['Décevant', 'Moyen', 'Correct', 'Bien', 'Excellent'];
  static const _minLength = 10;
  final _comment = TextEditingController();
  int _rating = 0;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _valid => _rating > 0 && _comment.text.trim().length >= _minLength;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref.read(catalogRepositoryProvider).submitReview(widget.productId,
          author: widget.author,
          rating: _rating,
          comment: _comment.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Impossible d'envoyer votre avis. Réessayez.")));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Votre avis', style: AppText.title),
                const SizedBox(height: 2),
                Text(widget.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMuted),
                const SizedBox(height: AppSpacing.lg),
                Row(children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i étoile${i > 1 ? 's' : ''}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(i <= _rating ? Icons.star : Icons.star_border,
                          size: 34,
                          color: i <= _rating
                              ? _reviewStar
                              : AppColors.textSecondary),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  if (_rating > 0)
                    Text(_labels[_rating - 1], style: AppText.subtitle),
                ]),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _comment,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Votre commentaire',
                    hintText: 'Qualité, livraison, utilisation au quotidien…',
                    helperText: 'Au moins $_minLength caractères',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Publié sous le nom ${widget.author}',
                    style: AppText.caption),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md))),
                    onPressed: _valid && !_sending ? _send : null,
                    child: _sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Publier mon avis',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
        ),
      );
}
