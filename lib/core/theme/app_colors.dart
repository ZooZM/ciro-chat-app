import 'package:flutter/material.dart';

/// Centralized color palette — sourced directly from the Ciro Connect logo.
///
/// Brand colors extracted from the reference image:
///   Green  #4CA02A  — left speech bubble, primary CTA color
///   Blue   #5B9BD5  — right speech bubble, secondary accent
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────

  /// Primary green — left bubble, buttons, highlights
  static const Color primary = Color(0xFF4CA02A);

  /// Darker green for active / pressed states
  static const Color primaryDark = Color(0xFF397820);

  /// Light green tint — backgrounds, chips, badges
  static const Color primaryLight = Color(0xFFE8F5E3);

  /// Secondary blue — right bubble, secondary actions
  static const Color secondary = Color(0xFF5B9BD5);

  /// Darker blue for active / pressed states
  static const Color secondaryDark = Color(0xFF3A7BB5);

  /// Light blue tint
  static const Color secondaryLight = Color(0xFFE3EFF9);

  // ── Backgrounds ───────────────────────────────────────────────────────────

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);

  // ── Text ──────────────────────────────────────────────────────────────────

  /// High-emphasis text — headings, titles
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Medium-emphasis — subtitles, helper text
  static const Color textSecondary = Color(0xFF757575);

  /// Low-emphasis — placeholders, disabled
  static const Color textHint = Color(0xFFBDBDBD);

  // ── Semantic ──────────────────────────────────────────────────────────────

  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  // ── UI Chrome ─────────────────────────────────────────────────────────────

  /// Dividers, border strokes
  static const Color divider = Color(0xFFE0E0E0);

  /// Input field borders in rest state
  static const Color border = Color(0xFFCCCCCC);

  // ── Chat bubbles ──────────────────────────────────────────────────────────

  /// Outgoing message bubble
  static const Color bubbleOut = Color(0xFFDFFAC4);

  /// Incoming message bubble
  static const Color bubbleIn = Color(0xFFFFFFFF);
}
