import 'package:flutter/material.dart';

/// Design system constants for the application.
/// Values here are derived from the Figma design specifications.
class AppConstants {
  AppConstants._();

  // --- Layout & Spacing ---
  
  /// Default padding for main screens (e.g., left/right edges)
  static const double defaultScreenPadding = 16.0;

  /// Default padding within cards, dialogues, or panels
  static const double innerPadding = 12.0;

  /// Spacing between elements in a column/row
  static const double elementSpacing = 8.0;

  // --- Border Radius ---
  
  /// Standard border radius for TextFields, Buttons, and smaller Cards
  static const double defaultBorderRadius = 12.0;
  
  /// Large border radius for bottom sheets or large dialogs
  static const double largeBorderRadius = 24.0;
  
  /// Circular border radius for avatars or pill-shaped badges
  static const double circularBorderRadius = 999.0;

  // --- Animation & Durations ---
  
  /// Default duration for micro-animations (e.g., button press)
  static const Duration animationDurationShort = Duration(milliseconds: 200);

  /// Default duration for screen transitions or complex animations
  static const Duration animationDurationMedium = Duration(milliseconds: 400);

  // --- Helper Methods ---

  /// Helper to get a BorderRadius object for standard radius
  static BorderRadius defaultRadius = BorderRadius.circular(defaultBorderRadius);
}
