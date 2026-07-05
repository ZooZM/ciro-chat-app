import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [
          _buildPrivacyOption('privacy_last_seen'.tr(), 'privacy_my_contacts'.tr()),
          _buildPrivacyOption('privacy_profile_photo'.tr(), 'privacy_everyone'.tr()),
          _buildPrivacyOption('privacy_about'.tr(), 'privacy_my_contacts'.tr()),
          _buildPrivacyOption('privacy_status'.tr(), 'privacy_my_contacts'.tr()),
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

  Widget _buildPrivacyOption(String title, String trailingText) {
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
                trailingText,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.black54, size: 24),
            ],
          ),
          onTap: () {},
        ),
      ),
    );
  }
}
