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
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingLg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isColorPaletteOpen &&
                  (activeMode == StatusContentType.text ||
                      activeMode == StatusContentType.voice)) ...[
                _buildToolbarButton(icon: Icons.palette, onTap: onPaletteTap),
                const SizedBox(width: AppConstants.spacingSm),
              ],
              if (activeMode == StatusContentType.text) ...[
                _buildToolbarButton(text: 'Aa', onTap: onFontTap),
                const SizedBox(width: AppConstants.spacingSm),
              ],
              if (!isColorPaletteOpen &&
                  activeMode == StatusContentType.text) ...[
                PopupMenuButton<StatusPrivacy>(
                  onSelected: (privacy) {
                    if (privacy == StatusPrivacy.private) {
                      onSelectContacts();
                    }
                    onPrivacyChanged(privacy);
                  },
                  color: Colors.black54, // Matches the translucent grey look
                  elevation: 0,
                  offset: const Offset(
                    0,
                    48,
                  ), // Opens below the button, shifted right
                  constraints: const BoxConstraints(
                    maxWidth: 220,
                  ), // Reduce width
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: StatusPrivacy.public,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Public ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: '(All contacts)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: StatusPrivacy.private,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Private ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: '(Select contacts)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuItem(
                      value: StatusPrivacy.showOnMap,
                      height: 36,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Show on Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusPill,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getPrivacyLabel(currentPrivacy),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isColorPaletteOpen)
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            _buildToolbarButton(icon: Icons.close, onTap: onClose),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    IconData? icon,
    String? text,
    required VoidCallback onTap,
  }) {
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
              : Text(
                  text!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  String _getPrivacyLabel(StatusPrivacy privacy) {
    switch (privacy) {
      case StatusPrivacy.public:
        return 'Public';
      case StatusPrivacy.private:
        return 'Private';
      case StatusPrivacy.showOnMap:
        return 'Map';
    }
  }
}
