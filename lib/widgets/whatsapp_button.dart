import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// LO Multimédia customer service on WhatsApp.
const whatsAppSupportNumber = '221779980404';

/// Dark WhatsApp green (#128C7E) for the floating button.
const whatsAppDarkGreen = Color(0xFF128C7E);

/// Round floating button with the WhatsApp logo: opens a chat with the shop.
class WhatsAppFab extends StatelessWidget {
  const WhatsAppFab(
      {super.key,
      this.message = 'Bonjour LO Multimédia, j’ai une question.'});
  final String message;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
        heroTag: 'whatsapp',
        tooltip: 'Nous écrire sur WhatsApp',
        backgroundColor: whatsAppDarkGreen,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => launchUrl(
            Uri.parse(
                'https://wa.me/$whatsAppSupportNumber?text=${Uri.encodeComponent(message)}'),
            mode: LaunchMode.externalApplication),
        child: const WhatsAppLogo(size: 32),
      );
}

/// WhatsApp glyph: speech bubble outline with a tail and a phone handset.
class WhatsAppLogo extends StatelessWidget {
  const WhatsAppLogo({super.key, this.size = 28, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BubblePainter(color),
          child: Center(
            child: Transform.rotate(
              angle: -math.pi / 12,
              child: Icon(Icons.phone, size: size * .46, color: color),
            ),
          ),
        ),
      );
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * .085;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final c = Offset(s / 2, s / 2);
    final r = s / 2 - stroke;
    // Circle open at the bottom-left, where the tail starts.
    const gapStart = math.pi * .62, gap = math.pi * .2;
    final path = Path()
      ..addArc(Rect.fromCircle(center: c, radius: r), gapStart + gap,
          2 * math.pi - gap);
    final a = c + Offset(math.cos(gapStart), math.sin(gapStart)) * r;
    final b = c + Offset(math.cos(gapStart + gap), math.sin(gapStart + gap)) * r;
    final tip = Offset(stroke * .9, s - stroke * .9);
    path
      ..moveTo(a.dx, a.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}
