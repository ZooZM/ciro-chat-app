import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized typography definitions for the application.
/// Based on Figma typography styles using Google Fonts.
class AppTypography {
  AppTypography._();

  // --- Headlines ---

  /// Used for major screen titles (e.g., H1 in Figma)
  static TextStyle headline1 = GoogleFonts.poppins(
    fontSize: 32.0,
    fontWeight: FontWeight.w700, // Bold
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Used for modal titles or large sections
  static TextStyle headline2 = GoogleFonts.poppins(
    fontSize: 24.0,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // --- Subtitles ---

  /// Used for section headers or prominent list items
  static TextStyle subtitle1 = GoogleFonts.poppins(
    fontSize: 18.0,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Secondary subtitle, used below primary titles or list descriptions
  static TextStyle subtitle2 = GoogleFonts.poppins(
    fontSize: 16.0,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // --- Body Text ---

  /// Primary body text used for the majority of continuous reading
  static TextStyle body1 = GoogleFonts.poppins(
    fontSize: 16.0,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Secondary body text, often used for smaller descriptions or metadata
  static TextStyle body2 = GoogleFonts.poppins(
    fontSize: 14.0,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // --- Buttons & Labels ---

  /// Text style used inside primary buttons
  static TextStyle buttonText = GoogleFonts.poppins(
    fontSize: 16.0,
    fontWeight: FontWeight.w600, // SemiBold
    color: Colors.white, // Usually white or contrasting color
    letterSpacing: 0.5,
  );

  /// Small labels, tags, or captions
  static TextStyle caption = GoogleFonts.poppins(
    fontSize: 12.0,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textSecondary,
    height: 1.4,
  );
}
