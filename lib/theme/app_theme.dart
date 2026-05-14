import 'package:flutter/material.dart';

/// Design tokens for the FixMyStreet civic dashboard.
///
/// Aesthetic: calm, minimal, dark olive. No neon, no heavy glow.
/// Olive accents are reserved for active states, primary actions,
/// and key highlights only.
class AppColors {
  AppColors._();

  // Backgrounds — deep charcoal with a faint warm/olive undertone.
  static const Color bgBase = Color(0xFF0E100D);
  static const Color bgElevated = Color(0xFF121410);
  static const Color surface = Color(0xFF161814);
  static const Color surfaceHigh = Color(0xFF1C1F1A);
  static const Color surfaceOverlay = Color(0xFF22251F);

  // Olive accent — desaturated, restrained.
  static const Color olive = Color(0xFFA8B870);
  static const Color oliveSoft = Color(0xFF7A8553);
  static const Color oliveDim = Color(0xFF4D5535);
  static const Color oliveGhost = Color(0x1AA8B870);

  // Text — soft off-white and muted gray-green.
  static const Color textPrimary = Color(0xFFEBEAE3);
  static const Color textSecondary = Color(0xFF9DA193);
  static const Color textTertiary = Color(0xFF6B6F62);
  static const Color textDisabled = Color(0xFF4A4D45);

  // Functional / severity — all muted, earthy, not neon.
  static const Color critical = Color(0xFFB87060);
  static const Color moderate = Color(0xFFC9A06C);
  static const Color minor = Color(0xFF8FA365);
  static const Color success = Color(0xFF8FA365);
  static const Color danger = Color(0xFFB87060);

  // Lines and dividers.
  static const Color divider = Color(0x14FFFFFF);
  static const Color hairline = Color(0x0DFFFFFF);

  // Map sheet overlay
  static const Color mapSheetBg = Color(0xCC0E100D);
}

class AppRadius {
  AppRadius._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 40;
}

class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 250);
  static const Curve easeOut = Curves.easeOutCubic;
}

class AppText {
  AppText._();

  static const TextStyle display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.15,
  );

  static const TextStyle title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle heading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
  );

  static const TextStyle metadata = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle button = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}

ThemeData buildAppTheme() {
  const base = ColorScheme.dark(
    primary: AppColors.olive,
    onPrimary: Color(0xFF111310),
    secondary: AppColors.oliveSoft,
    onSecondary: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgBase,
    colorScheme: base,
    splashColor: AppColors.oliveGhost,
    highlightColor: AppColors.oliveGhost,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    ),
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    dividerColor: AppColors.divider,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
  );
}
