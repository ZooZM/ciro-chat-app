import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PrivacyDropdown extends StatelessWidget {
  final StatusPrivacy currentPrivacy;
  final ValueChanged<StatusPrivacy> onPrivacyChanged;
  final VoidCallback onSelectContacts; // For Private mode

  const PrivacyDropdown({
    super.key,
    required this.currentPrivacy,
    required this.onPrivacyChanged,
    required this.onSelectContacts,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<StatusPrivacy>(
      onSelected: (privacy) {
        if (privacy == StatusPrivacy.private) {
          onSelectContacts();
        }
        onPrivacyChanged(privacy);
      },
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: StatusPrivacy.public,
          child: ListTile(
            leading: const Icon(Icons.public, color: Colors.white),
            title: Text('status.public'.tr(), style: const TextStyle(color: Colors.white)),
            subtitle: Text('status.public_desc'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
        PopupMenuItem(
          value: StatusPrivacy.private,
          child: ListTile(
            leading: const Icon(Icons.lock, color: Colors.white),
            title: Text('status.private'.tr(), style: const TextStyle(color: Colors.white)),
            subtitle: Text('status.private_desc'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
        PopupMenuItem(
          value: StatusPrivacy.showOnMap,
          child: ListTile(
            leading: const Icon(Icons.location_on, color: Colors.white),
            title: Text('status.show_on_map'.tr(), style: const TextStyle(color: Colors.white)),
            subtitle: const Text('', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingSm, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getPrivacyIcon(currentPrivacy),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _getPrivacyLabel(currentPrivacy),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  IconData _getPrivacyIcon(StatusPrivacy privacy) {
    switch (privacy) {
      case StatusPrivacy.public:
        return Icons.public;
      case StatusPrivacy.private:
        return Icons.lock;
      case StatusPrivacy.showOnMap:
        return Icons.location_on;
    }
  }

  String _getPrivacyLabel(StatusPrivacy privacy) {
    switch (privacy) {
      case StatusPrivacy.public:
        return 'status.public'.tr();
      case StatusPrivacy.private:
        return 'status.private'.tr();
      case StatusPrivacy.showOnMap:
        return 'status.show_on_map'.tr();
    }
  }
}
