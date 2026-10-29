import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../features/digital/digital_catalog.dart';
import '../digital/digital_product_card.dart';
import '../shimmer.dart' show Shimmer;

/// Placeholder icon per category, used when a product has no photo yet.
const _categoryIcons = {
  'c-informatique': Icons.laptop_outlined,
  'c-smartphones': Icons.smartphone_outlined,
  'c-multimedia': Icons.movie_outlined,
  'c-reseau': Icons.wifi,
  'c-securite': Icons.shield_outlined,
  'c-electromenager': Icons.ac_unit_outlined,
  'c-papeterie': Icons.menu_book_outlined,
  'c-jeux': Icons.sports_esports_outlined,
};

/// Product photo: a network URL (ERP / CDN) or a bundled `assets/` path.
/// Shows a shimmer while loading and a category icon when there is no photo
/// or it fails to load, so the layout never jumps or shows a broken image.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.url,
    this.categoryId,
    this.iconSize = 32,
    this.fit = BoxFit.cover,
    this.heroTag,
  });

  final String? url;
  final String? categoryId;
  final double iconSize;
  final BoxFit fit;
  final String? heroTag;

  Widget _placeholder() => Container(
        color: AppColors.primarySoft,
        alignment: Alignment.center,
        child: Icon(_categoryIcons[categoryId] ?? Icons.image_outlined,
            size: iconSize, color: AppColors.primary.withValues(alpha: .55)),
      );

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) return _placeholder();
    // Licence / game code: the brand card stands in for the photo.
    final digital = digitalSpecFromImage(src);
    if (digital != null) {
      return Container(
        color: AppColors.white,
        padding: const EdgeInsets.all(AppSpacing.sm),
        alignment: Alignment.center,
        child: digital.imageAsset != null
            ? Image.asset(digital.imageAsset!, fit: BoxFit.contain)
            : FittedBox(
                child: SizedBox(
                    width: 320,
                    child: DigitalProductCard(
                        code: digital.preview(src), compact: true)),
              ),
      );
    }
    Widget image = src.startsWith('assets/')
        ? Image.asset(
            src,
            fit: fit,
            errorBuilder: (_, __, ___) => _placeholder(),
          )
        : Image.network(
            src,
            fit: fit,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Shimmer(
                    child: SizedBox.expand(
                        child: ColoredBox(color: Color(0xFFE6E8EF)))),
            errorBuilder: (_, __, ___) => _placeholder(),
          );

    if (heroTag != null) {
      image = Hero(
        tag: heroTag!,
        child: image,
      );
    }
    // White behind photos: product shots are usually on white.
    return ColoredBox(color: AppColors.white, child: image);
  }
}
