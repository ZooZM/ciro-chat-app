import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized typography — Montserrat via google_fonts.
///
/// Scale follows the Material Type System adapted for Ciro's compact UI:
///   headline1  32sp  W800  — splash / hero titles
///   headline2  24sp  W700  — screen titles
///   headline3  20sp  W700  — section headers
///   subtitle1  18sp  W600  — card titles, field labels
///   subtitle2  16sp  W500  — secondary labels
///   body1      16sp  W400  — primary reading text
///   body2      14sp  W400  — secondary reading text
///   buttonText 16sp  W700  — CTA buttons (all-caps ready)
///   caption    12sp  W400  — timestamps, meta text
///   overline   11sp  W600  — badge labels, step counters
class AppTypography {
  AppTypography._();

  // ── Headlines ─────────────────────────────────────────────────────────────

  static TextStyle get headline1 => GoogleFonts.montserrat(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get headline2 => GoogleFonts.montserrat(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
        letterSpacing: -0.2,
      );

  static TextStyle get headline3 => GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  // ── Subtitles ─────────────────────────────────────────────────────────────

  static TextStyle get subtitle1 => GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get subtitle2 => GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // ── Body ──────────────────────────────────────────────────────────────────

  static TextStyle get body1 => GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get body2 => GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  // ── Action & Labels ───────────────────────────────────────────────────────

  static TextStyle get buttonText => GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.8,
      );

  static TextStyle get caption => GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get overline => GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      );

  // ── App-specific convenience styles ──────────────────────────────────────

  /// "CIRO" logo wordmark
  static TextStyle get logoMark => GoogleFonts.montserrat(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF333333),
        letterSpacing: 6,
      );

  /// "CONNECT" tagline below logo
  static TextStyle get logoTagline => GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        letterSpacing: 5,
      );

  /// Message bubble text
  static TextStyle get messageText => GoogleFonts.montserrat(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  /// Timestamp / tick row in chat bubbles
  static TextStyle get messageTime => GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );
}
