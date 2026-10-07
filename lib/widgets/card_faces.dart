import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/currency.dart';

/// Card faces reproduced from the website, same layout and assets:
/// DevA -final/src/domains/loyalty/components/LoyaltyCardFace.tsx,
/// DevA -final/src/domains/giftcard/components/GiftCardFace.tsx and their
/// styles in DevA -final/src/lo/pages/lo-plus.css (.lc-*, .gc-*).
///
/// The CSS sizes everything in % of the card and `cqw` (1 % of its width);
/// [_CardFrame] hands the width to the builders so the faces scale the same
/// way on every screen.

/// Card aspect ratio from the site's mock-ups (1540 × 960).
const double _cardAspect = 1540 / 960;

/// The site uses Lato 300. Tests turn Google Fonts off (no network).
bool cardFacesUseGoogleFonts = true;

TextStyle _lato(double size,
    {FontWeight weight = FontWeight.w300, double letterSpacing = 0}) {
  final base = TextStyle(
      // Used as-is when Google Fonts is off; falls back to the default font
      // if no 'Lato' is installed.
      fontFamily: 'Lato',
      decoration: TextDecoration.none,
      color: Colors.white,
      fontSize: size,
      fontWeight: weight,
      height: 1,
      letterSpacing: letterSpacing * size,
      fontFeatures: const [FontFeature.liningFigures()]);
  return cardFacesUseGoogleFonts ? GoogleFonts.lato(textStyle: base) : base;
}

String _spaced(int n) => formatXof(n).replaceAll(' FCFA', '');

/// Shared frame: aspect ratio, 4cqw corners, the site's shadow, no text
/// scaling (the card is an image, it must not reflow).
class _CardFrame extends StatelessWidget {
  const _CardFrame(
      {required this.semanticsLabel,
      required this.decoration,
      required this.builder,
      this.maxWidth = 440});
  final String semanticsLabel;
  final BoxDecoration decoration;
  final List<Widget> Function(double w, double h, double cqw) builder;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: ExcludeSemantics(
        child: MediaQuery.withNoTextScaling(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: AspectRatio(
              aspectRatio: _cardAspect,
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;
                final cqw = w / 100;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4 * cqw),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0x470F173C),
                          offset: Offset(0, 1.2 * cqw),
                          blurRadius: 3 * cqw),
                      BoxShadow(
                          color: const Color(0x400F173C),
                          offset: Offset(0, 0.2 * cqw),
                          blurRadius: 0.6 * cqw),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4 * cqw),
                    // Transparent Material: plain text styling even when
                    // the card is shown outside a Scaffold (dialogs…).
                    child: Material(
                      type: MaterialType.transparency,
                      child: DecoratedBox(
                        decoration: decoration,
                        child: Stack(children: builder(w, h, cqw)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- LO+ card

const _tierPills = {
  'BLEU': ('assets/lo-plus/palier-bleu.png', 'Bleu'),
  'SILVER': ('assets/lo-plus/palier-silver.png', 'Silver'),
  'GOLD': ('assets/lo-plus/palier-gold.png', 'Gold'),
  'PLATINUM': ('assets/lo-plus/palier-platinium.png', 'Platinium'),
};

/// LO+ loyalty card (site: LoyaltyCardFace).
class LoyaltyCardFace extends StatelessWidget {
  const LoyaltyCardFace({
    super.key,
    required this.cardNumber,
    required this.memberName,
    required this.points,
    required this.tierCode,
    this.blocked = false,
    this.maxWidth = 440,
  });

  final String cardNumber;
  final String memberName;
  final int? points;
  final String tierCode;
  final bool blocked;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final pill = _tierPills[tierCode] ?? _tierPills['BLEU']!;
    Widget face = _CardFrame(
      maxWidth: maxWidth,
      semanticsLabel:
          'Carte de fidélité LO+ ${pill.$2} n° $cardNumber, $memberName${points == null ? '' : ', ${_spaced(points!)} points'}',
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/lo-plus/fond-carte-fidelite.jpg'),
            fit: BoxFit.cover),
      ),
      builder: (w, h, cqw) => [
        Positioned(
            left: .042 * w,
            top: .05 * h,
            width: .247 * w,
            child: Image.asset('assets/lo-plus/logo-lo-plus.png')),
        Positioned(
            left: .786 * w,
            top: .052 * h,
            width: .192 * w,
            child: Image.asset(pill.$1)),
        Positioned(
            left: .042 * w,
            top: .275 * h,
            child: Text('CARTE DE FIDÉLITÉ',
                style: _lato(5.4 * cqw, letterSpacing: .02))),
        Positioned(
            left: .042 * w,
            top: .465 * h,
            child: Text(cardNumber, style: _lato(7.7 * cqw, letterSpacing: .03))),
        Positioned(
            left: .042 * w,
            top: .816 * h,
            child: Text('MEMBRE :', style: _lato(2.7 * cqw, letterSpacing: .03))),
        Positioned(
            left: .042 * w,
            top: .872 * h,
            right: .2 * w,
            child: Text(memberName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _lato(4 * cqw))),
        Positioned(
            left: .864 * w,
            top: .828 * h,
            child: Text('POINTS :', style: _lato(2.7 * cqw, letterSpacing: .03))),
        Positioned(
            left: .864 * w,
            top: .888 * h,
            child: Text(points == null ? '—' : _spaced(points!),
                style: _lato(4 * cqw))),
        if (blocked)
          Center(
            child: Transform.rotate(
              angle: -12 * 3.1415926 / 180,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 3 * cqw, vertical: 1.2 * cqw),
                decoration: BoxDecoration(
                  color: const Color(0xB8A0141E),
                  border: Border.all(color: const Color(0xE6FFFFFF), width: .6 * cqw),
                  borderRadius: BorderRadius.circular(1.2 * cqw),
                ),
                child: Text('CARTE BLOQUÉE',
                    style: _lato(5 * cqw,
                        weight: FontWeight.w700, letterSpacing: .08)),
              ),
            ),
          ),
      ],
    );
    if (blocked) {
      // .lc-off: grayscale(0.85) brightness(0.85)
      face = ColorFiltered(colorFilter: _grayscale(.85, .85), child: face);
    }
    return face;
  }
}

// --------------------------------------------------------------- Gift card

/// Card colour by amount, like the site (colorFor): the four mock-up values
/// have their colour; any other amount takes its bracket's.
(Color, Color) giftCardGradient(int amountXof) {
  if (amountXof < 50000) return (const Color(0xFF122572), const Color(0xFF1A379D));
  if (amountXof < 100000) return (const Color(0xFF9CA3AF), const Color(0xFFB8C4CC));
  if (amountXof < 500000) return (const Color(0xFFC7862A), const Color(0xFFE4A852));
  return (const Color(0xFF8B8F98), const Color(0xFFA8ADB8));
}

/// Gift card front (site: GiftCardFace).
class GiftCardFace extends StatelessWidget {
  const GiftCardFace({
    super.key,
    required this.amountXof,
    this.dimmed = false,
    this.stateLabel,
    this.maxWidth = 440,
  });

  final int amountXof;
  final bool dimmed;
  final String? stateLabel;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final (g1, g2) = giftCardGradient(amountXof);
    Widget face = _CardFrame(
      maxWidth: maxWidth,
      semanticsLabel:
          'Carte cadeau LO Multimédia de ${_spaced(amountXof)} FCFA${stateLabel == null ? '' : ', $stateLabel'}',
      decoration: BoxDecoration(
        // CSS 135deg: top-left to bottom-right.
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [g1, g2]),
      ),
      builder: (w, h, cqw) => [
        Positioned.fill(
            child: Opacity(
                opacity: .16, child: CustomPaint(painter: _SwooshPainter()))),
        Positioned(
            left: .818 * w,
            top: .086 * h,
            width: .127 * w,
            child: Image.asset('assets/lo-plus/logo-lo-multimedia.png')),
        Positioned(
            left: .042 * w,
            top: .105 * h,
            child: Text('CARTE CADEAU', style: _lato(7.7 * cqw, letterSpacing: .01))),
        Positioned(
          left: .044 * w,
          top: .40 * h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_spaced(amountXof),
                  style: _lato(13.6 * cqw, letterSpacing: -.01)),
              SizedBox(width: 1.2 * cqw),
              Padding(
                padding: EdgeInsets.only(top: .6 * cqw),
                child: Text('FCFA', style: _lato(7.7 * cqw, letterSpacing: .01)),
              ),
            ],
          ),
        ),
        Positioned(
            left: .042 * w,
            top: .806 * h,
            child: Text('LE CADEAU QUI FAIT TOUJOURS PLAISIR !',
                style: _lato(3.4 * cqw, letterSpacing: .005))),
        Positioned(
            left: .748 * w,
            top: .63 * h,
            width: .21 * w,
            child: AspectRatio(
                aspectRatio: 120 / 130,
                child: CustomPaint(painter: _GiftIconPainter()))),
        if (stateLabel != null)
          Positioned(
            right: .03 * w,
            top: .03 * h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2 * cqw, vertical: .7 * cqw),
              decoration: BoxDecoration(
                  color: const Color(0xEBFFFFFF),
                  borderRadius: BorderRadius.circular(99)),
              child: Text(stateLabel!,
                  style: _lato(2.4 * cqw, weight: FontWeight.w700, letterSpacing: .06)
                      .copyWith(color: const Color(0xFF333333))),
            ),
          ),
      ],
    );
    if (dimmed) {
      // .gc-dim: grayscale(0.7) brightness(0.8)
      face = ColorFiltered(colorFilter: _grayscale(.7, .8), child: face);
    }
    return face;
  }
}

/// The four thin lines of the site's swoosh (viewBox 160×100, stretched).
class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 160, sy = size.height / 100;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = .35 * (sx + sy) / 2;
    void curve(List<double> p) => canvas.drawPath(
        Path()
          ..moveTo(p[0] * sx, p[1] * sy)
          ..cubicTo(p[2] * sx, p[3] * sy, p[4] * sx, p[5] * sy, p[6] * sx, p[7] * sy),
        paint);
    curve([60, 100, 90, 70, 130, 40, 160, 10]);
    curve([85, 100, 110, 75, 140, 60, 160, 50]);
    curve([0, 100, 40, 92, 100, 70, 160, 45]);
    curve([110, 100, 120, 80, 140, 40, 152, 0]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The site's gift icon (viewBox 120×130, stroke 6, round caps).
class _GiftIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.scale(s);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(6, 38, 108, 26),
            const Radius.circular(8)),
        paint);
    canvas.drawLine(const Offset(14, 64), const Offset(14, 126), paint);
    canvas.drawLine(const Offset(106, 64), const Offset(106, 126), paint);
    canvas.drawLine(const Offset(60, 38), const Offset(60, 126), paint);
    // Bow: M60 38C44 36 34 26 40 16s22-2 20 22z and its mirror.
    canvas.drawPath(
        Path()
          ..moveTo(60, 38)
          ..cubicTo(44, 36, 34, 26, 40, 16)
          ..cubicTo(46, 6, 62, 14, 60, 38)
          ..close(),
        paint);
    canvas.drawPath(
        Path()
          ..moveTo(60, 38)
          ..cubicTo(76, 36, 86, 26, 80, 16)
          ..cubicTo(74, 6, 58, 14, 60, 38)
          ..close(),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CSS `grayscale(g) brightness(b)` as a colour matrix.
ColorFilter _grayscale(double g, double b) {
  const r = .2126, gr = .7152, bl = .0722;
  List<double> row(double a, double c, double d) => [a * b, c * b, d * b, 0, 0];
  return ColorFilter.matrix([
    ...row(r + (1 - r) * (1 - g), gr - gr * (1 - g), bl - bl * (1 - g)),
    ...row(r - r * (1 - g), gr + (1 - gr) * (1 - g), bl - bl * (1 - g)),
    ...row(r - r * (1 - g), gr - gr * (1 - g), bl + (1 - bl) * (1 - g)),
    0, 0, 0, 1, 0,
  ]);
}
