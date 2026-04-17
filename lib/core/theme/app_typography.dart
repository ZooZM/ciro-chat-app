import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Centralized typography definitions using Google Fonts and flutter_screenutil
class AppTypography {
  AppTypography._();

  // --- Headlines ---

  static TextStyle get headline1 => GoogleFonts.poppins(
    fontSize: 32.0.resSp,
    fontWeight: FontWeight.w700, 
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get headline2 => GoogleFonts.poppins(
    fontSize: 24.0.resSp,
    fontWeight: FontWeight.w600, 
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // --- Subtitles ---

  static TextStyle get subtitle1 => GoogleFonts.poppins(
    fontSize: 18.0.resSp,
    fontWeight: FontWeight.w600, 
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get subtitle2 => GoogleFonts.poppins(
    fontSize: 16.0.resSp,
    fontWeight: FontWeight.w500, 
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // --- Body Text ---

  static TextStyle get body1 => GoogleFonts.poppins(
    fontSize: 16.0.resSp,
    fontWeight: FontWeight.w400, 
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get body2 => GoogleFonts.poppins(
    fontSize: 14.0.resSp,
    fontWeight: FontWeight.w400, 
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // --- Buttons & Labels ---

  static TextStyle get buttonText => GoogleFonts.poppins(
    fontSize: 16.0.resSp,
    fontWeight: FontWeight.w600, 
    color: Colors.white, 
    letterSpacing: 0.5,
  );

  static TextStyle get caption => GoogleFonts.poppins(
    fontSize: 12.0.resSp,
    fontWeight: FontWeight.w400, 
    color: AppColors.textSecondary,
    height: 1.4,
  );
}
