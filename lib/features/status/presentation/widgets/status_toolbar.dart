import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/privacy_dropdown.dart';
import 'package:flutter/material.dart';

class StatusToolbar extends StatelessWidget {
  final StatusContentType activeMode;
  final VoidCallback onClose;
  final VoidCallback onPaletteTap;
  final VoidCallback onFontTap;
  final StatusPrivacy currentPrivacy;
  final ValueChanged<StatusPrivacy> onPrivacyChanged;
  final VoidCallback onSelectContacts;

  const StatusToolbar({
    super.key,
    required this.activeMode,
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
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: AppConstants.toolbarIconSize),
            onPressed: onClose,
          ),
          Row(
            children: [
              PrivacyDropdown(
                currentPrivacy: currentPrivacy,
                onPrivacyChanged: onPrivacyChanged,
                onSelectContacts: onSelectContacts,
              ),
              const SizedBox(width: AppConstants.spacingMd),
              if (activeMode == StatusContentType.text)
                IconButton(
                  icon: const Icon(Icons.text_format, color: Colors.white, size: AppConstants.toolbarIconSize),
                  onPressed: onFontTap,
                ),
              if (activeMode == StatusContentType.text || activeMode == StatusContentType.voice)
                IconButton(
                  icon: const Icon(Icons.palette, color: Colors.white, size: AppConstants.toolbarIconSize),
                  onPressed: onPaletteTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
