import 'package:flutter/material.dart';

/// Mirrors ../mobile-app/src/components/ui/Rating.tsx
class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.value, this.reviewCount, this.size = 12});

  final double value;
  final int? reviewCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: size, color: const Color(0xFF8A6100)),
        const SizedBox(width: 2),
        Text(
          '${value.toStringAsFixed(1)}${reviewCount != null ? ' ($reviewCount)' : ''}',
          style: TextStyle(color: const Color(0xFF8A6100), fontWeight: FontWeight.w700, fontSize: size - 1),
        ),
      ],
    );
  }
}
