import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Design system constants for the application.
/// Refactored to use flutter_screenutil for responsiveness.
class AppConstants {
  AppConstants._();

  // --- Layout & Spacing ---
  
  static double get defaultScreenPadding => 16.0.resW;
  static double get innerPadding => 12.0.resW;
  static double get elementSpacing => 8.0.resH;

  // --- Border Radius ---
  
  static double get defaultBorderRadius => 12.0.resR;
  static double get largeBorderRadius => 24.0.resR;
  static double get circularBorderRadius => 999.0.resR;

  // --- Animation & Durations ---
  
  static const Duration animationDurationShort = Duration(milliseconds: 200);
  static const Duration animationDurationMedium = Duration(milliseconds: 400);

  // --- Helper Methods ---

  static BorderRadius get defaultRadius => BorderRadius.circular(defaultBorderRadius);
}
