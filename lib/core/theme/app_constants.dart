import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_colors.dart';

/// Design-token constants for layout, spacing, radius, elevation, and button styles.
class AppConstants {
  AppConstants._();

  // ── Network ───────────────────────────────────────────────────────────────

  static String get apiBaseUrl =>
      dotenv.maybeGet('API_URL') ??
      const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://vella-niftier-gertrude.ngrok-free.dev',
      );

  // ── Spacing ───────────────────────────────────────────────────────────────

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  /// Default horizontal screen margin
  static const double defaultScreenPadding = spacingMd;

  /// Padding inside cards and list tiles
  static const double innerPadding = spacingSm;

  // ── Border Radius ─────────────────────────────────────────────────────────

  /// Input fields, small chips
  static const double radiusSm = 8.0;

  /// Buttons, cards, dialogs
  static const double radiusMd = 12.0;

  /// Large cards, bottom sheets
  static const double radiusLg = 20.0;

  /// Pill / fully-rounded elements (FAB, primary buttons)
  static const double radiusPill = 999.0;

  // Keep legacy aliases so existing code doesn't break
  static double get defaultBorderRadius => radiusMd;
  static double get largeBorderRadius => radiusLg;
  static double get circularBorderRadius => radiusPill;

  // ── BorderRadius helpers ──────────────────────────────────────────────────

  static const BorderRadius defaultRadius = BorderRadius.all(
    Radius.circular(radiusMd),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(radiusPill),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(radiusLg),
  );

  // ── Elevation ─────────────────────────────────────────────────────────────

  static const double elevationNone = 0;
  static const double elevationSm = 2;
  static const double elevationMd = 6;
  static const double elevationLg = 12;

  // ── Durations ─────────────────────────────────────────────────────────────

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ── Button Styles ─────────────────────────────────────────────────────────

  /// Primary pill-shaped green button with subtle shadow
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: const StadiumBorder(),
    elevation: elevationSm,
    shadowColor: AppColors.primary.withOpacity(0.4),
    padding: const EdgeInsets.symmetric(horizontal: spacingLg),
  );

  /// Secondary outlined green button
  static ButtonStyle get outlineButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: const Size.fromHeight(52),
    shape: const StadiumBorder(),
    side: const BorderSide(color: AppColors.primary, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: spacingLg),
  );

  /// Danger / destructive pill button
  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: const StadiumBorder(),
    elevation: elevationSm,
  );

  // ── Input Decoration ──────────────────────────────────────────────────────

  /// Shared green-outlined input decoration base
  static InputDecoration inputDecoration({
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: spacingMd,
      vertical: spacingMd,
    ),
    border: OutlineInputBorder(
      borderRadius: defaultRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: defaultRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: defaultRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: defaultRadius,
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );

  // ── Box Shadows ───────────────────────────────────────────────────────────

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.35),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
