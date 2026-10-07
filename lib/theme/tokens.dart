import 'package:flutter/material.dart';

/// Widest the app content grows on tablets, landscape and desktop.
const double kMaxContentWidth = 900;

/// The website's palette — DevA -final/src/styles.css (:root). Keep in sync:
/// the site's CSS variable is noted on each colour.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF4754A4); // --bleu
  static const primaryDark = Color(0xFF3F478D); // --bleu-fonce
  static const primaryLight = Color(0xFF5965B0); // --bleu-clair
  static const primarySoft = Color(0xFFEEF2FB); // --bleu-pale
  static const danger = Color(0xFFDE2E26); // --rouge
  static const dangerDark = Color(0xFFC92720); // --rouge-fonce
  static const dangerSoft = Color(0xFFFDF0F2); // --rouge-pale
  static const gold = Color(0xFFF59E0B); // --or

  /// Lighter gold for text on the blue cards: --or on --bleu is too faint
  /// to read (contrast below 3:1).
  static const goldOnDark = Color(0xFFFCD34D);
  static const success = Color(0xFF16A34A); // --vert
  static const text = Color(0xFF1A1D24); // --noir
  static const textSecondary = Color(0xFF64748B); // --gris
  static const border = Color(0xFFE2E8F0); // --bordure
  // Gris perle légèrement bleuté : les cartes blanches s'en détachent mieux.
  static const background = Color(0xFFFFFFFF);
  static const white = Colors.white; // --blanc
}

class AppRadii {
  AppRadii._();

  static const double sm = 9;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 18;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
