import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/home.dart';
import '../features/home/home_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../widgets/home_trending.dart';
import '../widgets/app_header.dart';
import '../widgets/card_faces.dart' show GiftCardFace;
import 'boutique_screen.dart' show CatalogSort, shopSortRequestProvider;
import '../features/catalog/shop_filters.dart';
import '../widgets/commerce/category_card.dart';
import '../widgets/commerce/product_rail.dart';
import '../widgets/commerce/promo_banner_carousel.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import '../widgets/header_actions.dart';
import '../widgets/whatsapp_button.dart';
import '../widgets/home_extras.dart';
import 'photo_search_screen.dart' show startPhotoSearch;
import '../widgets/nav_clearance.dart';

typedef _ServiceLink = ({
  IconData icon,
  String label,
  String hint,
  String title,
  String subtitle,
  String? route
});

const List<_ServiceLink> _services = [
  (
    icon: Icons.build_outlined,
    label: 'Atelier SAV',
    hint: "Diagnostic 24 h",
    title: 'Atelier SAV agréé',
    subtitle: 'Diagnostic gratuit 24 h',
    route: '/sav'
  ),
  (
    icon: Icons.diamond_outlined,
    label: 'Fidélité Lo+',
    hint: "Jusqu'à –12 %",
    title: 'Fidélité Lo+',
    subtitle: "Jusqu'à –12 % de remise",
    route: '/lo'
  ),
  (
    icon: Icons.location_on_outlined,
    label: 'Showrooms',
    hint: "Sandaga, Médina",
    title: 'Nos 2 showrooms',
    subtitle: 'Sandaga & Médina, Dakar',
    route: '/showrooms'
  ),
  (
    icon: Icons.chat_bubble_outline,
    label: 'Arame IA',
    hint: "Réponse 24/7",
    title: 'Arame, assistante IA',
    subtitle: 'Réponse immédiate 24/7',
    route: '/chat',
  ),
];

/// Mirrors ../mobile-app/app/(tabs)/index.tsx
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeContent = ref.watch(homeContentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const WhatsAppFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              showLogo: true,
              title: 'LO Multimédia',
              subtitle: "L'innovation, notre passion !",
              searchField: SearchField(
                controller: _searchController,
                placeholder: 'Rechercher un produit, une marque…',
                // Opens the full-screen search page over the home.
                readOnly: true,
                onTap: () => context.push('/recherche'),
                onCamera: () => startPhotoSearch(context),
              ),
              actions: [
                notificationsHeaderAction(context, ref),
                cartHeaderAction(context, ref),
              ],
            ),
            homeContent.when(
              loading: () => const LoadingState(
                  layout: SkeletonLayout.home,
                  label: "Chargement de l'accueil…"),
              error: (error, stackTrace) => ErrorState(
                message: 'Impossible de charger l\'accueil pour le moment.',
                onRetry: () => ref.invalidate(homeContentProvider),
              ),
              data: (content) =>
                  Expanded(child: _HomeContentView(content: content)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContentView extends ConsumerWidget {
  const _HomeContentView({required this.content});

  final HomeContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xxl + navBarClearance(context)),
      children: [
        PromoBannerCarousel(
            banners: content.banners,
            onPressed: (_) => context.go('/boutique')),
        if (content.categories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(
              title: 'Nos rayons',
              actionLabel: 'Tout voir →',
              onActionPressed: () => context.go('/boutique')),
          const SizedBox(height: AppSpacing.sm),
          // Round pictures scrolling sideways; a tap opens the shop on
          // that department.
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: content.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final category = content.categories[index];
                return CategoryCircle(
                  category: category,
                  onPressed: () {
                    // Fresh filters: an old brand or price filter would
                    // otherwise hide the whole department.
                    ref.read(shopFiltersProvider.notifier).state =
                        ShopFilterState(categoryIds: {category.id});
                    context.go('/boutique');
                  },
                );
              },
            ),
          ),
        ],
        if (content.flashProducts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
              title: 'Ventes flash',
              actionLabel: 'Voir →',
              onActionPressed: () => context.go('/boutique')),
          const Padding(
            padding: EdgeInsets.only(
                left: AppSpacing.lg, top: 2, bottom: AppSpacing.sm),
            child: Text(
              'Promotions du moment, stock limité.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          ProductRail(products: content.flashProducts),
        ],
        const SizedBox(height: AppSpacing.lg),
        const HomeDigitalCodes(),
        if (content.bestSellers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
              title: 'Les plus vendus',
              actionLabel: 'Voir →',
              onActionPressed: () {
                ref.read(shopSortRequestProvider.notifier).state =
                    CatalogSort.rating;
                context.go('/boutique');
              }),
          const Padding(
            padding: EdgeInsets.only(
                left: AppSpacing.lg, top: 2, bottom: AppSpacing.sm),
            child: Text(
              'Les produits préférés de nos clients.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          ProductRail(products: content.bestSellers),
        ],
        const SizedBox(height: AppSpacing.lg),
        HomeTrending(
          products: HomeTrending.pick([
            ...content.bestSellers,
            ...content.flashProducts,
            ...content.newArrivals,
            ...content.recommendedProducts,
          ]),
          onSeeAll: () {
            ref.read(shopSortRequestProvider.notifier).state =
                CatalogSort.rating;
            context.go('/boutique');
          },
        ),
        if (content.newArrivals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
              title: 'Nouveautés',
              actionLabel: 'Voir →',
              onActionPressed: () => context.go('/boutique')),
          const Padding(
            padding: EdgeInsets.only(
                left: AppSpacing.lg, top: 2, bottom: AppSpacing.sm),
            child: Text(
              'Découvrez nos derniers arrivages.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          ProductRail(products: content.newArrivals),
        ],
        if (content.recommendedProducts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
              title: 'Recommandé pour vous',
              actionLabel: 'Voir →',
              onActionPressed: () => context.go('/boutique')),
          const Padding(
            padding: EdgeInsets.only(
                left: AppSpacing.lg, top: 2, bottom: AppSpacing.sm),
            child: Text(
              'Basé sur vos préférences.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          ProductRail(products: content.recommendedProducts),
        ],
        const SizedBox(height: AppSpacing.lg),
        HomeBrands(fallback: [
          ...content.flashProducts,
          ...content.bestSellers,
          ...content.newArrivals,
          ...content.recommendedProducts,
        ]),
        const SizedBox(height: AppSpacing.lg),
        const _GiftCardPromo(),
        const SizedBox(height: AppSpacing.lg),
        const HomeWhyUs(),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Services'),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          // Four shortcuts on one row, icon above a short label (like
          // banking / Wave apps), in one outlined block lifted by a soft
          // shadow so it reads as tappable.
          child: Material(
            color: AppColors.white,
            elevation: 3,
            shadowColor: const Color(0x400F173C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(children: [
                for (var i = 0; i < _services.length; i++) ...[
                  if (i > 0)
                    const VerticalDivider(
                        width: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                        color: AppColors.border),
                  Expanded(
                    child: _ServiceShortcut(
                      service: _services[i],
                      onTap: _services[i].route == null
                          ? null
                          : () => context.go(_services[i].route!),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'LO Multimédia SARL · NINEA 0043755741A1 · Dakar depuis 2011',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Home entry point to buy a gift card: same header rhythm as the other
/// sections, a straight card preview and amounts to pick directly.
/// "Cartes cadeaux" (home): violet panel, laid out like
/// "Produits tendances" (uppercase title, subtitle, round arrow) over a sideways row of the
/// gift cards as they look today ([GiftCardFace]), one per amount, each
/// with "Offrir" under it, then an "Autre montant" tile.
class _GiftCardPromo extends StatefulWidget {
  const _GiftCardPromo();

  static const _amounts = [5000, 10000, 25000, 50000, 100000];
  static const _cardWidth = 230.0;
  static const _cardHeight = _cardWidth * 960 / 1540;

  /// Bright violet panel: every card colour (blue, red, turquoise,
  /// orange) stands out from it, and white text reads at 4.6:1.
  static const violet = Color(0xFF7F4CEF);

  @override
  State<_GiftCardPromo> createState() => _GiftCardPromoState();
}

/// Endless carousel: slides one card forward every 3 s, last → first
/// without going back; a finger on it pauses the rotation.
class _GiftCardPromoState extends State<_GiftCardPromo> {
  static const _amounts = _GiftCardPromo._amounts;
  static const _cardWidth = _GiftCardPromo._cardWidth;
  static const _cardHeight = _GiftCardPromo._cardHeight;
  static const violet = _GiftCardPromo.violet;
  static const _interval = Duration(seconds: 3);
  static const _tileCount = 6; // 5 amounts + "Autre montant"

  /// Starts far from 0 so it can always move forward; re-centred on the
  /// same card past [_recentreAfter].
  static const _loopStart = _tileCount * 10;
  static const _recentreAfter = _tileCount * 30;

  PageController? _controller;
  double _viewport = 0;
  int _page = _loopStart;
  Timer? _timer;

  /// One page = left margin + card + gap, so the next card peeks in.
  PageController _controllerFor(double width) {
    if (_controller != null && _viewport == width) return _controller!;
    _controller?.dispose();
    _viewport = width;
    return _controller = PageController(
        initialPage: _page,
        viewportFraction: ((16 + _cardWidth) / width).clamp(.2, 1.0));
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      final c = _controller;
      if (c == null || !c.hasClients) return;
      if (_page > _recentreAfter) {
        _page = _loopStart + _page % _tileCount;
        c.jumpToPage(_page);
      }
      c.animateToPage(_page + 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void open([int? amount]) => context.push(
        amount == null ? '/carte-cadeau' : '/carte-cadeau?montant=$amount');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: violet,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CARTES CADEAUX',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2)),
                        SizedBox(height: 4),
                        Text('OFFREZ LE CHOIX, DE 5 000 À 1 000 000 FCFA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    button: true,
                    label: 'Voir les cartes cadeaux',
                    child: Material(
                      color: AppColors.white,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: open,
                        child: const SizedBox(
                          width: 64,
                          height: 36,
                          child: Icon(Icons.arrow_forward_rounded,
                              color: violet, size: 24),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: _cardHeight,
                child: LayoutBuilder(
                  builder: (context, box) => Listener(
                    // A finger on the carousel pauses the rotation.
                    onPointerDown: (_) => _timer?.cancel(),
                    onPointerUp: (_) => _schedule(),
                    onPointerCancel: (_) => _schedule(),
                    child: PageView.builder(
                      controller: _controllerFor(box.maxWidth),
                      padEnds: false,
                      // No itemCount: endless, the tiles repeat in order.
                      onPageChanged: (i) => _page = i,
                      itemBuilder: (context, i) {
                        final k = i % _tileCount;
                        return Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: k < _amounts.length
                                ? _GiftTile(
                                    amount: _amounts[k],
                                    width: _cardWidth,
                                    onTap: () => open(_amounts[k]))
                                : _OtherAmountTile(
                                    width: _cardWidth,
                                    height: _cardHeight,
                                    onTap: open),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One gift card (unchanged face); a tap opens it for that amount.
class _GiftTile extends StatelessWidget {
  const _GiftTile(
      {required this.amount, required this.width, required this.onTap});
  final int amount;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Offrir une carte cadeau de ${formatXof(amount)}',
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GiftCardFace(amountXof: amount, maxWidth: width),
              ],
            ),
          ),
        ),
      );
}

/// Last tile: same size as a card, outlined, opens the free amount form.
class _OtherAmountTile extends StatelessWidget {
  const _OtherAmountTile(
      {required this.width, required this.height, required this.onTap});
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Choisir un autre montant',
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: AppColors.white.withValues(alpha: .14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  side: BorderSide(
                      color: AppColors.white.withValues(alpha: .75),
                      width: 1.5),
                ),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 36, color: AppColors.white),
                        SizedBox(height: 8),
                        Text('Autre montant',
                            style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// One "Services" shortcut: navy icon above a short label. The full title
/// and detail are read out by screen readers.
class _ServiceShortcut extends StatelessWidget {
  const _ServiceShortcut({required this.service, this.onTap});

  final _ServiceLink service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${service.title}, ${service.subtitle}',
        excludeSemantics: true,
        child: InkWell(
            onTap: onTap,
            highlightColor: AppColors.primarySoft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: AppSpacing.md),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(service.icon, size: 26, color: AppColors.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(service.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(service.hint,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.2)),
              ]),
            ),
        ),
      );
}
