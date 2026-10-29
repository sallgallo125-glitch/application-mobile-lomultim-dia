import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../contracts/product.dart';
import '../features/catalog/catalog_providers.dart';
import '../features/catalog/shop_filters.dart';
import '../features/customer/customer_providers.dart';
import '../features/digital/digital_catalog.dart';
import '../theme/tokens.dart';
import 'commerce/product_rail.dart';
import 'section_header.dart';

/// Opens the shop with [update] applied to its filters.
void _openShop(BuildContext context, WidgetRef ref,
    ShopFilterState Function(ShopFilterState) update) {
  ref.read(shopFiltersProvider.notifier).state =
      update(const ShopFilterState());
  context.go('/boutique');
}

/// Official brand logos (copied from the site's public/logos).
const _brandLogoFiles = [
  'adlink.svg',
  'apc.svg',
  'apple.svg',
  'asus.svg',
  'belkin.svg',
  'bose.svg',
  'brother.svg',
  'canon.svg',
  'cisco.svg',
  'crucial.png',
  'dji.svg',
  'endan.svg',
  'epson.svg',
  'hiksemi.svg',
  'hikvision.svg',
  'hisense.svg',
  'hp.svg',
  'ingelec.png',
  'insta360.svg',
  'jabra.svg',
  'jbl.svg',
  'kaspersky.svg',
  'legrand.svg',
  'lenovo.svg',
  'logitech.svg',
  'mikrotik.svg',
  'mpower.svg',
  'nexans.svg',
  'qnap.svg',
  'samsung.svg',
  'sony.svg',
  'starlink.svg',
  'synology.svg',
  'tecno.svg',
  'tenda.svg',
  'tplink.svg',
  'ubiquiti.svg',
  'xiaomi.svg'
];

/// Logo asset for [brand] ("TP-Link" → assets/brands/tplink.svg), if any.
String? _brandLogo(String brand) {
  final key = brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  for (final file in _brandLogoFiles) {
    if (file.substring(0, file.lastIndexOf('.')) == key) {
      return 'assets/brands/$file';
    }
  }
  return null;
}

/// Brands of the catalogue as logo tiles; a tap filters the shop.
class HomeBrands extends ConsumerWidget {
  const HomeBrands({super.key, required this.fallback});

  /// Products used when the full catalogue is not loaded yet.
  final List<ProductSummary> fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? fallback;
    // Most represented brands first.
    final counts = <String, int>{};
    for (final p in products) {
      final b = p.brand.trim();
      if (b.isNotEmpty) counts[b] = (counts[b] ?? 0) + 1;
    }
    // Brands with an official logo first, then the most represented.
    final brands = counts.keys.toList()
      ..sort((a, b) {
        final logo =
            (_brandLogo(b) != null ? 1 : 0) - (_brandLogo(a) != null ? 1 : 0);
        return logo != 0 ? logo : counts[b]!.compareTo(counts[a]!);
      });
    if (brands.length < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Nos marques'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: brands.take(12).length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => Material(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () => _openShop(
                    context, ref, (f) => f.copyWith(brands: {brands[i]})),
                child: Container(
                  width: 104,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  alignment: Alignment.center,
                  child: _BrandMark(brands[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The brand's official logo, or its name when there is none.
class _BrandMark extends StatelessWidget {
  const _BrandMark(this.brand);
  final String brand;

  @override
  Widget build(BuildContext context) {
    final text = Text(brand,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: .3));
    final asset = _brandLogo(brand);
    if (asset == null) return text;
    return Semantics(
      label: brand,
      child: asset.endsWith('.svg')
          ? SvgPicture.asset(asset,
              fit: BoxFit.contain, placeholderBuilder: (_) => text)
          : Image.asset(asset,
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => text),
    );
  }
}

/// "Vus récemment": the products the customer last opened.
class HomeRecentlyViewed extends ConsumerWidget {
  const HomeRecentlyViewed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(recentlyViewedProvider);
    if (ids.isEmpty) return const SizedBox.shrink();
    final all = ref.watch(productsProvider).value ?? const <ProductSummary>[];
    final recent = [
      for (final id in ids) ...all.where((p) => p.id == id),
    ];
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Vus récemment'),
        const SizedBox(height: AppSpacing.sm),
        ProductRail(products: recent),
      ],
    );
  }
}

/// Licences Windows and game codes: the code is delivered in the app right
/// after payment (Compte › Mes codes), no trip to the shop.
class HomeDigitalCodes extends ConsumerWidget {
  const HomeDigitalCodes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ProductSummary> products = [
      for (final p in ref.watch(productsProvider).value ?? const [])
        if (digitalCatalog.containsKey(p.id)) p
    ];
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: 'Licences & jeux',
            actionLabel: 'Mes codes →',
            onActionPressed: () => context.push('/mes-codes')),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 2, AppSpacing.lg, AppSpacing.sm),
          child: Row(children: [
            const Icon(Icons.bolt_rounded, size: 16, color: AppColors.success),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                  'Code reçu dans l’app dès le paiement, sans déplacement.',
                  style: AppText.caption.copyWith(fontSize: 13)),
            ),
          ]),
        ),
        ProductRail(products: products),
      ],
    );
  }
}

/// "Pourquoi LO Multimédia": four reasons to trust the shop.
class HomeWhyUs extends StatelessWidget {
  const HomeWhyUs({super.key});

  static const _reasons = [
    (
      Icons.verified_outlined,
      'Produits originaux',
      'Garantie constructeur et facture'
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Paiement facile',
      'Wave, Orange Money ou à la livraison'
    ),
    (
      Icons.local_shipping_outlined,
      'Livraison à Dakar',
      'En 24 – 48 h, ou retrait en showroom'
    ),
    (
      Icons.storefront_outlined,
      'Depuis 2011',
      '2 showrooms : Sandaga & Médina'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Pourquoi LO Multimédia'),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (icon, title, detail) in _reasons)
                  Container(
                    width: width,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(AppRadii.sm)),
                          child: Icon(icon, size: 19, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(title,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(detail, style: AppText.caption),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
