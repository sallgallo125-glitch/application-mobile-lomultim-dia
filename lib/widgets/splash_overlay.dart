import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Animated launch screen played over the app at start-up ("Orbite"):
/// on the brand blue the logo's red ring bursts out, a white circle opens,
/// the LM emblem spins in with a haptic tick and a golden burst, the
/// wordmark rises, then everything fades onto the home page.
///
/// The native splash (Android / iOS) is the same blue, so the hand-over
/// has no white flash. With "reduce motion" on, it is a plain fade.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _full = Duration(milliseconds: 1800);
  static const _reduced = Duration(milliseconds: 900);

  /// Point of the timeline where the emblem lands (haptic + burst).
  static const _impact = 0.45;

  late final AnimationController _c = AnimationController(vsync: this);
  bool _reduceMotion = false;
  bool _started = false;
  bool _buzzed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _c.duration = _reduceMotion ? _reduced : _full;
    _c.addListener(_onTick);
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  void _onTick() {
    if (!_buzzed && !_reduceMotion && _c.value >= _impact) {
      _buzzed = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// [curve] applied over the [begin]–[end] slice of the timeline.
  double _t(double begin, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((_c.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          _reduceMotion ? _buildReduced() : _buildFull(context),
    );
  }

  Widget _buildReduced() {
    final fadeIn = _t(0, 0.3);
    final fadeOut = 1 - _t(0.7, 1);
    return Opacity(
      opacity: fadeOut,
      child: ColoredBox(
        color: AppColors.white,
        child: Center(
          child: Opacity(opacity: fadeIn, child: const _Logo(wordmark: 1)),
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ringIn = _t(0.04, 0.36, Curves.easeOutBack);
    final ringOut = _t(0.40, 0.52, Curves.easeIn);
    final reveal = _t(0.23, 0.45, Curves.easeInCubic);
    final emblem = _t(0.25, _impact, Curves.easeOutBack);
    final burst = _t(_impact, 0.80, Curves.easeOutCubic);
    final wordmark = _t(0.50, 0.68, Curves.easeOutCubic);
    final fadeOut = 1 - _t(0.86, 1);
    final maxRadius = math.sqrt(
        size.width * size.width + size.height * size.height);

    return IgnorePointer(
      ignoring: _c.value > 0.86,
      child: Opacity(
        opacity: fadeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.primary),
            ClipPath(
              clipper: _CircleReveal(reveal * maxRadius / 2),
              child: const ColoredBox(color: AppColors.white),
            ),
            Center(
              child: Opacity(
                opacity: 1 - ringOut,
                child: Transform.rotate(
                  angle: -20 * math.pi / 180,
                  child: Transform.scale(
                    scale: ringIn * 1.15 + ringOut * 0.3,
                    child: Container(
                      width: 210,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius:
                            const BorderRadius.all(Radius.elliptical(105, 55)),
                        border: Border.all(color: AppColors.danger, width: 6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (burst > 0 && burst < 1)
              CustomPaint(painter: _BurstPainter(burst)),
            Center(
              child: _Logo(
                emblemScale: 0.2 + 0.8 * emblem,
                emblemAngle: (1 - emblem) * -25 * math.pi / 180,
                emblemOpacity: _t(0.25, 0.32),
                wordmark: wordmark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({
    this.emblemScale = 1,
    this.emblemAngle = 0,
    this.emblemOpacity = 1,
    required this.wordmark,
  });

  final double emblemScale;
  final double emblemAngle;
  final double emblemOpacity;

  /// 0 → hidden 24 px lower, 1 → in place.
  final double wordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: emblemOpacity,
          child: Transform.rotate(
            angle: emblemAngle,
            child: Transform.scale(
              scale: emblemScale,
              child: Image.asset('assets/splash/emblem.png', width: 200),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: wordmark,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - wordmark)),
            child: Image.asset('assets/splash/wordmark.png', width: 200),
          ),
        ),
      ],
    );
  }
}

class _CircleReveal extends CustomClipper<Path> {
  const _CircleReveal(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addOval(Rect.fromCircle(
        center: size.center(Offset.zero), radius: radius));

  @override
  bool shouldReclip(_CircleReveal old) => old.radius != radius;
}

/// Sparks flying out from the emblem's centre when it lands.
class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.t);

  final double t;

  static const _count = 14;
  static const _colors = [AppColors.gold, AppColors.danger, AppColors.primary];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(const Offset(0, -18));
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final angle = i / _count * 2 * math.pi;
      final distance = (110 + (i % 3) * 35) * t;
      paint.color = _colors[i % _colors.length].withValues(alpha: 1 - t);
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * distance,
        5 * (1 - t * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
