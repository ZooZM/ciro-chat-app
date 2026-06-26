import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/privacy_dropdown.dart';
import 'package:flutter/material.dart';

class StatusToolbar extends StatelessWidget {
  final StatusContentType activeMode;
  final bool isColorPaletteOpen;
  final VoidCallback onClose;
  final VoidCallback onPaletteTap;
  final VoidCallback onFontTap;
  final StatusPrivacy currentPrivacy;
  final ValueChanged<StatusPrivacy> onPrivacyChanged;
  final VoidCallback onSelectContacts;

  const StatusToolbar({
    super.key,
    required this.activeMode,
    this.isColorPaletteOpen = false,
    required this.onClose,
    required this.onPaletteTap,
    required this.onFontTap,
    required this.currentPrivacy,
    required this.onPrivacyChanged,
    required this.onSelectContacts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isColorPaletteOpen && (activeMode == StatusContentType.text || activeMode == StatusContentType.voice)) ...[
                _buildToolbarButton(
                  icon: Icons.palette,
                  onTap: onPaletteTap,
                ),
                const SizedBox(width: AppConstants.spacingSm),
              ],
              if (activeMode == StatusContentType.text) ...[
                _buildToolbarButton(
                  text: 'Aa',
                  onTap: onFontTap,
                ),
                const SizedBox(width: AppConstants.spacingSm),
              ],
              if (!isColorPaletteOpen && activeMode == StatusContentType.text) ...[
                _buildToolbarButton(
                  text: '@',
                  onTap: () {}, // TODO: Mention functionality
                ),
                const SizedBox(width: AppConstants.spacingSm),
              ],
              if (!isColorPaletteOpen)
                PrivacyDropdown(
                  currentPrivacy: currentPrivacy,
                  onPrivacyChanged: onPrivacyChanged,
                  onSelectContacts: onSelectContacts,
                ),
            ],
          ),
          if (isColorPaletteOpen)
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          else
            _buildToolbarButton(
              icon: Icons.close,
              onTap: onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({IconData? icon, String? text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 20)
              : Text(text!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}
