import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String _lastSeenValue = 'privacy_my_contacts';
  String _profilePhotoValue = 'privacy_everyone';
  String _aboutValue = 'privacy_my_contacts';
  String _statusValue = 'privacy_my_contacts';

  void _showPrivacyPopup(String title, String currentValue, ValueChanged<String> onSelected) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _buildPopupOption('privacy_everyone', currentValue, onSelected),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                _buildPopupOption('privacy_my_contacts', currentValue, onSelected),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                _buildPopupOption('privacy_no_one', currentValue, onSelected),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupOption(String valueKey, String currentValue, ValueChanged<String> onSelected) {
    final bool isSelected = valueKey == currentValue;
    return InkWell(
      onTap: () {
        onSelected(valueKey);
        context.pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              valueKey.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF4CA440), size: 24)
            else
              const Icon(Icons.circle_outlined, color: Colors.grey, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'privacy_main_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(context.locale.languageCode == 'ar' ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [
          _buildPrivacyOption(
            'privacy_last_seen'.tr(),
            _lastSeenValue,
            () => _showPrivacyPopup(
              'privacy_last_seen'.tr(),
              _lastSeenValue,
              (val) => setState(() => _lastSeenValue = val),
            ),
          ),
          _buildPrivacyOption(
            'privacy_profile_photo'.tr(),
            _profilePhotoValue,
            () => _showPrivacyPopup(
              'privacy_profile_photo'.tr(),
              _profilePhotoValue,
              (val) => setState(() => _profilePhotoValue = val),
            ),
          ),
          _buildPrivacyOption(
            'privacy_about'.tr(),
            _aboutValue,
            () => _showPrivacyPopup(
              'privacy_about'.tr(),
              _aboutValue,
              (val) => setState(() => _aboutValue = val),
            ),
          ),
          _buildPrivacyOption(
            'privacy_status'.tr(),
            _statusValue,
            () => _showPrivacyPopup(
              'privacy_status'.tr(),
              _statusValue,
              (val) => setState(() => _statusValue = val),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'privacy_change_desc'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(String title, String valueKey, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.black87),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueKey.tr(),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.black54, size: 24),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
