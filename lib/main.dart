import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/persistence.dart';
import 'navigation/app_router.dart';
import 'theme/tokens.dart';
import 'widgets/card_faces.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final persistence = await SqliteLocalPersistence.open();
  await persistence.migrateFrom(prefs);
  runApp(ProviderScope(
    overrides: [localPersistenceProvider.overrideWithValue(persistence)],
    child: const LoMultimediaApp(),
  ));
  // Warm Lottie's cache so the empty-cart animation shows at once.
  AssetLottie('assets/animations/empty_cart.json').load().ignore();
}

class LoMultimediaApp extends StatelessWidget {
  const LoMultimediaApp({super.key, this.useGoogleFonts = true});

  /// Tests pass false: they have no network to download the fonts.
  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context) {
    cardFacesUseGoogleFonts = useGoogleFonts;
    final textTheme = !useGoogleFonts ? null : TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(),
      displayMedium: GoogleFonts.playfairDisplay(),
      displaySmall: GoogleFonts.playfairDisplay(),
      headlineLarge: GoogleFonts.playfairDisplay(),
      headlineMedium: GoogleFonts.playfairDisplay(),
      headlineSmall: GoogleFonts.playfairDisplay(),
      titleLarge: GoogleFonts.playfairDisplay(),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
      titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.inter(),
      bodyMedium: GoogleFonts.inter(),
      bodySmall: GoogleFonts.inter(),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
      labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w700),
    );

    return MaterialApp.router(
      title: 'LO Multimédia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: textTheme,
        scaffoldBackgroundColor: AppColors.background,
        // Pin the key roles to the site's palette: fromSeed alone would
        // shift them to generated tones.
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.danger,
          onSecondary: AppColors.white,
          error: AppColors.danger,
          onError: AppColors.white,
          surface: AppColors.white,
          // Material 3 tints these bluish-grey from the seed: pure white
          // everywhere (dialogs, menus, sheets, navigation bar).
          surfaceContainerLowest: AppColors.white,
          surfaceContainerLow: AppColors.white,
          surfaceContainer: AppColors.white,
          surfaceContainerHigh: AppColors.white,
          surfaceContainerHighest: AppColors.white,
          surfaceTint: Colors.transparent,
          onSurface: AppColors.text,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.white,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textSecondary,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.text,
          contentTextStyle: TextStyle(color: AppColors.white),
        ),
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Keep accessibility scaling but cap it so fixed-height rows and
        // headers don't overflow on "huge text" settings.
        final textScaler = media.textScaler.clamp(maxScaleFactor: 1.3);
        return MediaQuery(
          data: media.copyWith(textScaler: textScaler),
          // On tablets / landscape / web, keep the phone-first layout at a
          // readable width instead of stretching it edge to edge.
          child: ColoredBox(
            color: AppColors.background,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
