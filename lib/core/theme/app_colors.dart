import 'package:flutter/material.dart';

/// Centralized color palette for the application.
/// Update the hex values below with the exact colors from your Figma file.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // --- Brand Colors ---
  
  /// Primary Brand Color (Green from Figma)
  static const Color primary = Color(0xFF4CA02A); 

  /// Secondary Brand Color
  static const Color secondary = Color(0xFF4A90E2); 

  // --- Background Colors ---

  /// Main application background color
  static const Color background = Color(0xFFF8F9FA); 
  
  /// Surface color for cards, dialogs, and bottom sheets
  static const Color surface = Color(0xFFFFFFFF); 

  // --- Text Colors ---

  /// Primary Text Color - High emphasis, for headings and main body text
  static const Color textPrimary = Colors.black; 

  /// Secondary Text Color - Medium emphasis, for subtitles and helper text
  static const Color textSecondary = Color(0xFF757575); 

  // --- Status & Semantic Colors ---

  /// Error color for validation and warnings
  static const Color error = Color(0xFFD32F2F); 

  /// Success color for confirmations and positive actions
  static const Color success = Color(0xFF388E3C);

  /// Warning color for alerts
  static const Color warning = Color(0xFFF57C00);

  // --- Dividers & Borders ---
  
  /// Default color for dividers, borders, and subtle lines
  static const Color divider = Color(0xFFE0E0E0);
}
