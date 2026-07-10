import 'package:flutter/material.dart';
import 'app_typography.dart';
import 'app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP LOGO CONFIGURATION & WIDGET
// Uses a static image asset for the logo mark (speech bubbles)
// and dynamic text for the "CIRO / CONNECT" wording.
// ─────────────────────────────────────────────────────────────────────────────

class AppLogo {
  AppLogo._(); // Private constructor to prevent instantiation

  /// The exact path to the logo asset in the project.
  /// Ensure you have added this to your pubspec.yaml file under the `assets:` section.
  static const String assetPath = 'assets/logo.png';
}

class AppLogoWidget extends StatelessWidget {
  /// Controls the width of the main image asset.
  /// The text will scale relative to this size.
  final double size;

  /// Set to false to hide the "CIRO / CONNECT" text (shows image only).
  final bool showText;

  const AppLogoWidget({super.key, this.size = 120.0, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Logo Image Asset (Overlapping Bubbles) ──────────────────────────
        Image.asset(
          AppLogo.assetPath,
          width: size,
          // Use a BoxFit that ensures it maintains its aspect ratio
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback while the image asset isn't added to the filesystem yet
            return Container(
              width: size,
              height: size * 0.75, // approximate ratio
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: Text(
                'Missing\nassets/logo.png',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: size * 0.1, color: Colors.grey[600]),
              ),
            );
          },
        ),

        if (showText) ...[
          Transform.translate(
            offset: Offset(0, -size * 0.08), // Pull text closer to the image
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── "CIRO" wordmark (Bold, Dark Grey/Black) ───────────────────────
                Text(
                  'ciro',
                  style: AppTypography.logoMark.copyWith(
                    fontSize: size * 0.27,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: const Color(
                      0xFF111111,
                    ), // Dark grey/black matching design
                  ),
                ),

                SizedBox(height: size * 0.01),

                // ── "CONNECT" tagline (Smaller, Primary Green) ────────────────────
                Text(
                  'CONNECT',
                  style: AppTypography.logoTagline.copyWith(
                    fontSize: size * 0.10,
                    letterSpacing: 3.5,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
