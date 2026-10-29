import 'package:flutter/material.dart';

import '../../contracts/digital_code.dart';
import '../../theme/tokens.dart';

/// Official look of each platform's card (brand colours, wordmark), the way
/// resellers like Startselect show the bought card with its code.
class PlatformBrand {
  const PlatformBrand({
    required this.name,
    required this.colors,
    required this.accent,
    required this.redeemLabel,
    required this.redeemUrl,
    required this.steps,
  });

  final String name;
  final List<Color> colors;
  final Color accent;
  final String redeemLabel;
  final String redeemUrl;
  final List<String> steps;

  static PlatformBrand of(DigitalCode code) => switch (code.platform) {
        DigitalPlatform.windows => PlatformBrand(
            name: 'Microsoft',
            colors: code.productName.contains('10')
                ? const [Color(0xFF0078D7), Color(0xFF004E8C)]
                : const [
                    Color(0xFF1E90FF),
                    Color(0xFF0067C0),
                    Color(0xFF003E92)
                  ],
            accent: const Color(0xFF60CDFF),
            redeemLabel: 'Activer Windows',
            redeemUrl: 'ms-settings:activation',
            steps: const [
              'Ouvrez Paramètres › Système › Activation.',
              'Appuyez sur « Modifier la clé de produit ».',
              'Saisissez la clé à 25 caractères ci-dessus.',
              'Validez : Windows s’active en quelques secondes (connexion Internet requise).',
            ],
          ),
        DigitalPlatform.playstation => const PlatformBrand(
            name: 'PlayStation',
            colors: [Color(0xFF0070D1), Color(0xFF003791)],
            accent: Color(0xFF00A3FF),
            redeemLabel: 'Utiliser sur PlayStation Store',
            redeemUrl: 'https://store.playstation.com/redeem',
            steps: [
              'Sur la console, ouvrez PlayStation Store.',
              'Touchez « … » puis « Utiliser un code ».',
              'Saisissez le code à 12 caractères.',
              'Le jeu apparaît dans votre bibliothèque, prêt à télécharger.',
            ],
          ),
        DigitalPlatform.xbox => const PlatformBrand(
            name: 'XBOX',
            colors: [Color(0xFF1E9A1E), Color(0xFF107C10), Color(0xFF0B5A0B)],
            accent: Color(0xFF9BF00B),
            redeemLabel: 'Utiliser sur redeem.microsoft.com',
            redeemUrl: 'https://redeem.microsoft.com',
            steps: [
              'Connectez-vous à votre compte Microsoft.',
              'Allez sur redeem.microsoft.com ou Store › Utiliser un code.',
              'Saisissez le code à 25 caractères.',
              'Lancez le téléchargement depuis « Mes jeux et applications ».',
            ],
          ),
        DigitalPlatform.nintendo => const PlatformBrand(
            name: 'Nintendo',
            colors: [Color(0xFFFF2A35), Color(0xFFE60012), Color(0xFFB0000E)],
            accent: Color(0xFFFFFFFF),
            redeemLabel: 'Utiliser sur Nintendo eShop',
            redeemUrl: 'https://ec.nintendo.com/redeem',
            steps: [
              'Ouvrez le Nintendo eShop sur la console.',
              'Sélectionnez votre profil puis « Saisir un code ».',
              'Saisissez le code à 16 caractères.',
              'Le téléchargement démarre automatiquement.',
            ],
          ),
        DigitalPlatform.steam => const PlatformBrand(
            name: 'STEAM',
            colors: [Color(0xFF2A475E), Color(0xFF1B2838), Color(0xFF171A21)],
            accent: Color(0xFF66C0F4),
            redeemLabel: 'Activer sur Steam',
            redeemUrl: 'https://store.steampowered.com/account/registerkey',
            steps: [
              'Ouvrez Steam et connectez-vous.',
              'Menu « Jeux » › « Activer un produit sur Steam ».',
              'Saisissez la clé et acceptez l’accord.',
              'Le jeu s’ajoute à votre bibliothèque.',
            ],
          ),
      };
}

/// The bought card itself: brand header, cover, product, then the code zone
/// (hidden like a scratch area until [revealed]).
class DigitalProductCard extends StatelessWidget {
  const DigitalProductCard(
      {super.key,
      required this.code,
      this.revealed = false,
      this.compact = false});

  final DigitalCode code;
  final bool revealed;

  /// List thumbnail: no code zone.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = PlatformBrand.of(code);
    return AspectRatio(
      aspectRatio: compact ? 1.586 : 0.86,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: brand.colors),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _ShinePainter(code))),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrandHeader(code: code, brand: brand),
                // Title takes the free height and shrinks if it lacks room
                // (small screens, large text).
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      width: 288,
                      child: code.isWindows
                          ? _WindowsTitle(code: code)
                          : _GameTitle(code: code, brand: brand),
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _CodeZone(code: code, revealed: revealed),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.code, required this.brand});
  final DigitalCode code;
  final PlatformBrand brand;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (code.isWindows) ...[
        const WindowsLogo(size: 18),
        const SizedBox(width: AppSpacing.sm),
      ],
      Flexible(
          child: Text(brand.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: code.isWindows ? 15 : 17,
                  fontWeight:
                      code.isWindows ? FontWeight.w600 : FontWeight.w900,
                  letterSpacing: code.isWindows ? 0 : 0.6,
                  fontStyle: code.platform == DigitalPlatform.playstation
                      ? FontStyle.italic
                      : FontStyle.normal))),
      const SizedBox(width: AppSpacing.sm),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
        child: Text(code.isWindows ? 'LICENCE NUMÉRIQUE' : 'CODE DE JEU',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      ),
    ]);
  }
}

class _WindowsTitle extends StatelessWidget {
  const _WindowsTitle({required this.code});
  final DigitalCode code;

  @override
  Widget build(BuildContext context) {
    final version = code.productName.contains('10') ? '10' : '11';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const WindowsLogo(size: 44),
      const SizedBox(height: AppSpacing.md),
      Text('Windows $version',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1)),
      const SizedBox(height: 4),
      Text(code.edition ?? '',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 20,
              fontWeight: FontWeight.w300)),
      const SizedBox(height: AppSpacing.sm),
      _Facts([
        if (code.licenseType != null) code.licenseType!,
        if (code.devices != null) '${code.devices} PC',
        '32/64 bits',
        if (code.regionCode != null) code.regionCode!,
      ]),
    ]);
  }
}

class _GameTitle extends StatelessWidget {
  const _GameTitle({required this.code, required this.brand});
  final DigitalCode code;
  final PlatformBrand brand;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 34, height: 4, color: brand.accent),
      const SizedBox(height: AppSpacing.sm),
      Text(code.productName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.4)),
      const SizedBox(height: AppSpacing.sm),
      _Facts([
        if (code.edition != null) code.edition!,
        if (code.regionCode != null) 'Région ${code.regionCode}',
      ]),
    ]);
  }
}

class _Facts extends StatelessWidget {
  const _Facts(this.facts);
  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    return Text(facts.join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w600));
  }
}

/// White strip at the bottom of the card, like the code area on a physical
/// card: hidden pattern until revealed.
class _CodeZone extends StatelessWidget {
  const _CodeZone({required this.code, required this.revealed});
  final DigitalCode code;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final label = code.isWindows ? 'CLÉ DE PRODUIT' : 'CODE D’ACTIVATION';
    final Widget value;
    if (code.status == DigitalCodeStatus.pending) {
      value = const Row(children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: AppSpacing.sm),
        Text('Code en cours de livraison…',
            style:
                TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
      ]);
    } else if (!code.hasCode) {
      value = const Text('Code indisponible',
          style:
              TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger));
    } else {
      final shown = revealed
          ? code.code!
          : code.code!.replaceAll(RegExp(r'[A-Za-z0-9]'), '•');
      value = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(shown,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.text)),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.label.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        value,
      ]),
    );
  }
}

/// The four-pane Windows 11 mark, drawn (no image asset).
class WindowsLogo extends StatelessWidget {
  const WindowsLogo({super.key, this.size = 24, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pane = size * 0.47;
    Widget p() => Container(width: pane, height: pane, color: color);
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [p(), p()]),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [p(), p()]),
        ],
      ),
    );
  }
}

/// Soft light shapes behind the content: Windows "bloom" or platform waves.
class _ShinePainter extends CustomPainter {
  _ShinePainter(this.code);
  final DigitalCode code;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    if (code.isWindows) {
      canvas.drawCircle(Offset(size.width * 1.05, size.height * 0.08),
          size.width * 0.55, paint);
      canvas.drawCircle(
          Offset(size.width * 0.95, size.height * 0.2),
          size.width * 0.32,
          Paint()..color = Colors.white.withValues(alpha: 0.08));
    } else {
      final path = Path()
        ..moveTo(size.width * 0.35, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * 0.62)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.code.id != code.id;
}
