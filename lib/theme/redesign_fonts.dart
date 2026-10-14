import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/card_faces.dart' show cardFacesUseGoogleFonts;

/// Fonts of the redesign mockup, used on the Compte and LO+ pages only:
/// Onest for text, Bricolage Grotesque for big figures and titles.
/// Tests run without network, so they keep the default font
/// (same switch as the card faces, set in main.dart).

/// Bricolage Grotesque on top of [style].
TextStyle displayFont(TextStyle style) => cardFacesUseGoogleFonts
    ? GoogleFonts.bricolageGrotesque(textStyle: style)
    : style;

/// Puts Onest under [child]: plain texts and the theme's buttons alike.
class RedesignFonts extends StatelessWidget {
  const RedesignFonts({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!cardFacesUseGoogleFonts) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
          textTheme: GoogleFonts.onestTextTheme(theme.textTheme)),
      child: DefaultTextStyle.merge(
        style: GoogleFonts.onest(),
        child: child,
      ),
    );
  }
}
