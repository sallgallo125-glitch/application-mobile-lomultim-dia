import 'dart:async';

import 'package:flutter/material.dart';

import '../../contracts/home.dart';
import '../../theme/tokens.dart';
import '../../utils/icon_mapper.dart';
import '../shimmer.dart' show Shimmer;

const _rotationInterval = Duration(seconds: 5);

/// Fixed banner height, identical on every device.
const double kPromoBannerHeight = 155;

/// Mirrors ../mobile-app/src/components/commerce/PromoBanner.tsx
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key, required this.banners, this.onPressed});

  final List<PromoBannerData> banners;
  final ValueChanged<PromoBannerData>? onPressed;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  /// Endless loop: the page view is virtually infinite and starts far from
  /// 0, so it always moves forward (last → first without going back).
  static const _loopStart = 60;

  /// Past this many pages the view is silently re-centred on the same
  /// banner (huge page numbers cause rounding errors).
  static const _recentreAfter = 120;
  late PageController _controller = _newController();
  int _page = _loopStart;
  Timer? _timer;

  PageController _newController() => PageController(
      viewportFraction: 1,
      // A single banner has one page only: no loop.
      initialPage: widget.banners.length < 2
          ? 0
          : _loopStart - _loopStart % widget.banners.length);

  int get _index => _page % widget.banners.length;

  @override
  void initState() {
    super.initState();
    // Starts on the first banner (a multiple of the banner count).
    _page = _controller.initialPage;
    _scheduleRotation();
  }

  @override
  void didUpdateWidget(covariant PromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _controller.dispose();
      _controller = _newController();
      _page = _controller.initialPage;
      _scheduleRotation();
    }
  }

  /// Slides to the next card every 5 s; restarted after a manual swipe.
  void _scheduleRotation() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(_rotationInterval, (_) {
      if (!_controller.hasClients) return;
      if (_page > _recentreAfter) {
        final same = _controller.initialPage + _index;
        _controller.jumpToPage(same);
        _page = same;
      }
      _controller.animateToPage(_page + 1,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic);
    });
  }

  /// Slides to banner [i] (from a dot) and restarts the 5 s rotation.
  void _goTo(int i) {
    if (!_controller.hasClients || i == _index) return;
    _controller.animateToPage(_page - _index + i,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic);
    _scheduleRotation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    final hasImages = widget.banners.every((b) => b.imageUrl != null);

    return Column(
      children: [
        LayoutBuilder(builder: (context, box) {
          final cardWidth = box.maxWidth - 2 * AppSpacing.sm;
          final height = hasImages
              ? cardWidth / _BannerFrame.imageAspectRatio +
                  _BannerFrame.extraHeight
              : kPromoBannerHeight;
          return SizedBox(
            height: height,
            // A finger on the carousel pauses the automatic rotation.
            child: Listener(
              onPointerDown: (_) => _timer?.cancel(),
              onPointerUp: (_) => _scheduleRotation(),
              onPointerCancel: (_) => _scheduleRotation(),
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                // No itemCount: endless, cards repeat in order.
                itemCount: widget.banners.length < 2 ? 1 : null,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  // One card at a time: 8 px margin on each side.
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: _card(widget.banners[i % widget.banners.length]),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.banners.length; i++)
                  // Tappable dot: slides to that card. The tap area is
                  // larger than the dot itself (easier to hit).
                  Semantics(
                    button: true,
                    selected: i == _index,
                    label: 'Afficher la bannière ${i + 1}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _goTo(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _index ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// One banner card (image only, or the text layout when no image).
  Widget _card(PromoBannerData banner) => MediaQuery.withNoTextScaling(
          child: Material(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(AppRadii.sm), // 9 px
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap:
              widget.onPressed == null ? null : () => widget.onPressed!(banner),
          child: Stack(fit: StackFit.expand, children: [
            if (banner.imageUrl != null)
              // The picture fills the whole card (zoomed, cropped on the
              // sides when the card is taller than the picture).
              _BannerImage(banner.imageUrl!),
            if (banner.imageUrl == null) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -6,
                      bottom: -12,
                      child: Icon(iconForKey(banner.icon),
                          size: 72,
                          color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    LayoutBuilder(
                      builder: (context, box) => SizedBox(
                        width: box.maxWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 2),
                              margin:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Text(
                                banner.badgeLabel,
                                style: const TextStyle(
                                    color: Color(0xFF3A2A00),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              banner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.15,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              banner.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12.5),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      banner.ctaLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(Icons.arrow_forward,
                                      size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ]),
        ),
      ));
}

/// Site banners are 1920×600 images with their own text: shown whole, at
/// their aspect ratio. Text-only banners keep the fixed height.
class _BannerFrame extends StatelessWidget {
  const _BannerFrame({required this.hasImage, required this.child});
  final bool hasImage;
  final Widget child;

  /// Mobile versions of the site banners (assets/banners): 1186 × 578, made
  /// from the 1920 × 600 site visuals by removing empty strips so the card
  /// can be taller without cutting their text.
  static const imageAspectRatio = 1186 / 578;

  /// Extra height on top of the image ratio (the picture is zoomed to fill
  /// it, so its sides are cropped).
  static const extraHeight = 0.0;

  @override
  Widget build(BuildContext context) => hasImage
      ? LayoutBuilder(
          builder: (context, box) => SizedBox(
                width: box.maxWidth,
                height: box.maxWidth / imageAspectRatio + extraHeight,
                child: child,
              ))
      : SizedBox(
          width: double.infinity, height: kPromoBannerHeight, child: child);
}

/// Banner picture from the web (http…) or the app assets; a shimmer while it
/// loads, the card colour if it fails.
class _BannerImage extends StatelessWidget {
  const _BannerImage(this.url);
  final String url;

  @override
  Widget build(BuildContext context) => url.startsWith('http')
      ? Image.network(url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Shimmer(
                  child: SizedBox.expand(
                      child: ColoredBox(color: Color(0xFFE6E8EF)))),
          errorBuilder: (_, __, ___) => const SizedBox.shrink())
      : Image.asset(url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
}
