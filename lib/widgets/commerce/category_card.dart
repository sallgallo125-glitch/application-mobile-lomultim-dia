import 'package:flutter/material.dart';

import '../../contracts/category.dart';
import '../../theme/tokens.dart';
import '../../utils/icon_mapper.dart';

/// Mirrors ../mobile-app/src/components/commerce/CategoryCard.tsx
class CategoryCardWidget extends StatelessWidget {
  const CategoryCardWidget({super.key, required this.category, this.onPressed});

  final Category category;
  final ValueChanged<Category>? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onPressed == null ? null : () => onPressed!(category),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(iconForKey(category.icon),
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                category.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home "Nos rayons" item: round picture on light grey, name underneath
/// (two lines at most, centred, never split inside a word).
class CategoryCircle extends StatelessWidget {
  const CategoryCircle(
      {super.key, required this.category, required this.onPressed});
  final Category category;
  final VoidCallback onPressed;

  static const double diameter = 80;

  static const _labelStyle = TextStyle(
      color: AppColors.text,
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Rayon ${category.name}',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 90,
            child: Column(children: [
              const SizedBox(height: 4),
              Container(
                width: diameter,
                height: diameter,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF1F3F7),
                ),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    // Transparent cut-out drawn straight on the circle (no
                    // white photo box); category icon when missing.
                    child: category.imageUrl == null
                        ? Icon(iconForKey(category.icon),
                            size: 30, color: AppColors.primary)
                        : Image.asset(category.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                                iconForKey(category.icon),
                                size: 30,
                                color: AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                // A single long word ("Électroménager") shrinks a little
                // instead of being cut in two; several words wrap on 2 lines.
                child: category.name.contains(' ')
                    ? Text(category.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(category.name,
                            maxLines: 1, style: _labelStyle)),
              ),
            ]),
          ),
        ),
      );
}
