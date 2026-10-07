import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One-shot confetti burst over [child] (order confirmation). Plays once,
/// never blocks taps, and is skipped when the system asks for reduced motion.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay(
      {super.key,
      required this.child,
      this.duration = const Duration(milliseconds: 3200),
      this.count = 140});
  final Widget child;
  final Duration duration;
  final int count;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final List<_Piece> _pieces;

  static const _colors = [
    AppColors.primary,
    AppColors.danger,
    AppColors.gold,
    AppColors.success,
    Color(0xFF38BDF8),
    Color(0xFFF472B6),
  ];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _pieces = List.generate(widget.count, (i) {
      // Two cannons (left and right top corners) shooting up and inward.
      final fromLeft = i.isEven;
      final angle = (fromLeft ? -math.pi / 3 : -2 * math.pi / 3) +
          (rnd.nextDouble() - .5) * .9;
      final speed = .9 + rnd.nextDouble() * .9;
      return _Piece(
        x0: fromLeft ? -.02 : 1.02,
        y0: .32 + rnd.nextDouble() * .08,
        vx: math.cos(angle) * speed * .55,
        vy: math.sin(angle) * speed,
        color: _colors[rnd.nextInt(_colors.length)],
        size: 6 + rnd.nextDouble() * 6,
        spin: (rnd.nextDouble() - .5) * 18,
        wobble: rnd.nextDouble() * math.pi * 2,
        round: rnd.nextDouble() < .3,
        delay: rnd.nextDouble() * .12,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduce && !_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _controller.isCompleted ||
                        _controller.value == 0
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        painter: _ConfettiPainter(_pieces, _controller.value)),
              ),
            ),
          ),
        ),
      ]);
}

class _Piece {
  _Piece({
    required this.x0,
    required this.y0,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.wobble,
    required this.round,
    required this.delay,
  });
  final double x0, y0, vx, vy, size, spin, wobble, delay;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final time = local * 2.2; // "seconds" of simulated flight
      // Launch, then gravity and air drag; a little sideways flutter.
      final x = p.x0 +
          p.vx * time * (1 - local * .35) +
          math.sin(p.wobble + time * 6) * .015;
      final y = p.y0 + p.vy * time * .45 + .55 * time * time * .35;
      final dx = x * size.width, dy = y * size.height;
      if (dy > size.height + 20) continue;
      final fade = local > .75 ? (1 - local) / .25 : 1.0;
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * time);
      // Flip effect: the piece narrows as it turns.
      final flip = math.cos(p.wobble + time * 9).abs() * .8 + .2;
      if (p.round) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * flip),
            paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero,
                    width: p.size * 1.4,
                    height: p.size * .7 * flip),
                const Radius.circular(1.5)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
