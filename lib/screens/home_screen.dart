import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contracts/home.dart';
import '../features/home/home_providers.dart';
import '../theme/tokens.dart';
import '../utils/currency.dart';
import '../widgets/app_header.dart';
import '../widgets/card_faces.dart' show GiftCardFace;
import 'boutique_screen.dart' show CatalogSort, shopSortRequestProvider;
import '../features/catalog/shop_filters.dart';
import '../widgets/commerce/category_card.dart';
import '../widgets/commerce/product_rail.dart';
import '../widgets/commerce/promo_banner_carousel.dart';
import '../widgets/error_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/shimmer.dart';
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
        HomeBrands(fallback: [
          ...content.flashProducts,
          ...content.bestSellers,
          ...content.newArrivals,
          ...content.recommendedProducts,
        ]),
        const SizedBox(height: AppSpacing.lg),
        const _GiftCardPromo(),
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
class _GiftCardPromo extends StatefulWidget {
  const _GiftCardPromo();

  @override
  State<_GiftCardPromo> createState() => _GiftCardPromoState();
}

class _GiftCardPromoState extends State<_GiftCardPromo> {
  static const _amounts = [25000, 50000, 100000];
  int _amount = 50000;

  void _open([int? amount]) => context
      .push(amount == null ? '/carte-cadeau' : '/carte-cadeau?montant=$amount');

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
          title: 'Cartes cadeaux',
          actionLabel: 'Voir →',
          onActionPressed: _open),
      const Padding(
        padding:
            EdgeInsets.only(left: AppSpacing.lg, top: 2, bottom: AppSpacing.md),
        child: Text(
          'Offrez le choix, de 5 000 à 1 000 000 FCFA.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(children: [
          GestureDetector(
            onTap: () => _open(_amount),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              // Two thirds of the width (about a real card's size), at most
              // 300 so it stays a preview on tablets.
              child: GiftCardFace(
                  key: ValueKey(_amount),
                  amountXof: _amount,
                  maxWidth:
                      math.min(MediaQuery.sizeOf(context).width * 2 / 3, 300)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            for (final amount in _amounts) ...[
              Expanded(
                child: _AmountChoice(
                  label: _spacedXof(amount),
                  selected: amount == _amount,
                  onTap: () => setState(() => _amount = amount),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: _AmountChoice(
                  label: 'Autre', selected: false, onTap: () => _open()),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _open(_amount),
              child: Text('Offrir ${formatXof(_amount)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// "50 000" without the currency, to fit four choices on one row.
String _spacedXof(int amount) => formatXof(amount).replaceAll(' FCFA', '');

class _AmountChoice extends StatelessWidget {
  const _AmountChoice(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primarySoft : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: SizedBox(
              height: 44,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
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
