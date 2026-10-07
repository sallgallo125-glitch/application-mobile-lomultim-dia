import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Animated shimmer sweep painted over its [child] skeleton shapes.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.0 + 3 * t - 1, -0.3),
            end: Alignment(1.0 + 3 * t - 1, 0.3),
            colors: const [
              Color(0xFFE6E8EF),
              Color(0xFFF6F7FA),
              Color(0xFFE6E8EF),
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A grey placeholder block; the surrounding [Shimmer] animates it.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox(
      {super.key, this.width, this.height = 14, this.radius = AppRadii.sm});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8EF),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Which page shape the loading skeleton should imitate.
enum SkeletonLayout { list, grid, home, product, account, form }

/// Product columns of the shop grid for a [width]: 2 on phones, 3 on small
/// tablets, 4 on large ones.
int shopGridColumnsFor(double width) => width >= 840
    ? 4
    : width >= 560
        ? 3
        : 2;

/// Full-page shimmer skeleton for [layout].
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.layout = SkeletonLayout.list});

  final SkeletonLayout layout;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: LayoutBuilder(builder: (context, constraints) {
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: switch (layout) {
            SkeletonLayout.list => _list(),
            SkeletonLayout.grid => _grid(constraints.maxWidth),
            SkeletonLayout.home => _home(constraints.maxWidth),
            SkeletonLayout.product => _product(constraints.maxWidth),
            SkeletonLayout.account => _account(),
            SkeletonLayout.form => _form(),
          },
        );
      }),
    );
  }

  static const _gap = SizedBox(height: AppSpacing.md);

  List<Widget> _list() => [
        for (var i = 0; i < 6; i++) ...[
          const _ListTileSkeleton(),
          const SizedBox(height: AppSpacing.sm),
        ]
      ];

  List<Widget> _grid(double width) {
    final columns = shopGridColumnsFor(width);
    return [
      for (var row = 0; row < 3; row++) ...[
        Row(children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            const Expanded(child: SkeletonBox(height: 250, radius: 13)),
          ]
        ]),
        const SizedBox(height: AppSpacing.sm),
      ]
    ];
  }

  List<Widget> _home(double width) {
    final columns = categoryColumnsFor(width);
    return [
      const SkeletonBox(height: 176, radius: AppRadii.xl),
      _gap,
      const SkeletonBox(width: 140, height: 18),
      _gap,
      Row(children: [
        for (var i = 0; i < columns; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          const Expanded(child: SkeletonBox(height: 72, radius: AppRadii.md)),
        ]
      ]),
      const SizedBox(height: AppSpacing.lg),
      const SkeletonBox(width: 160, height: 18),
      _gap,
      SizedBox(
        height: 230,
        child: Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            const Expanded(child: SkeletonBox(height: 230, radius: AppRadii.lg)),
          ]
        ]),
      ),
    ];
  }

  List<Widget> _product(double width) => [
        SkeletonBox(
            height: (width * 0.6).clamp(200, 360).toDouble(),
            radius: AppRadii.lg),
        _gap,
        const SkeletonBox(width: 90, height: 20),
        _gap,
        const SkeletonBox(height: 24),
        const SizedBox(height: AppSpacing.sm),
        const SkeletonBox(width: 180, height: 24),
        _gap,
        const SkeletonBox(width: 140, height: 28),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(height: 56, radius: AppRadii.md),
          const SizedBox(height: AppSpacing.sm),
        ],
        _gap,
        const SkeletonBox(height: 48, radius: AppRadii.md),
      ];

  List<Widget> _account() => [
        const Row(children: [
          SkeletonBox(width: 56, height: 56, radius: 28),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 160, height: 18),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 120),
            ]),
          ),
        ]),
        _gap,
        const SkeletonBox(height: 80, radius: AppRadii.md),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 5; i++) ...[
          const SkeletonBox(height: 52, radius: AppRadii.md),
          const SizedBox(height: AppSpacing.sm),
        ],
      ];

  List<Widget> _form() => [
        const SkeletonBox(width: 220, height: 22),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(height: 60, radius: AppRadii.md),
          const SizedBox(height: AppSpacing.sm),
        ],
        _gap,
        for (var i = 0; i < 2; i++) ...[
          const SkeletonBox(height: 52, radius: AppRadii.sm),
          const SizedBox(height: AppSpacing.md),
        ],
        const SkeletonBox(height: 120, radius: AppRadii.md),
      ];
}

class _ListTileSkeleton extends StatelessWidget {
  const _ListTileSkeleton();

  @override
  Widget build(BuildContext context) => const Row(children: [
        SkeletonBox(width: 86, height: 86, radius: AppRadii.md),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 70, height: 12),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 16),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 110, height: 16),
          ]),
        ),
      ]);
}

/// Number of category tiles per row for the available [width].
int categoryColumnsFor(double width) {
  if (width >= 900) return 8;
  if (width >= 600) return 6;
  if (width < 340) return 3;
  return 4;
}
