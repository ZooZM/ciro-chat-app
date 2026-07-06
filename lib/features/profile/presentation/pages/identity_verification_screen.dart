import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';

class IdentityVerificationScreen extends StatelessWidget {
  const IdentityVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'profile_identity_verification'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(
            context.locale.languageCode == 'ar'
                ? Icons.arrow_forward
                : Icons.arrow_back,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 80,
              color: Color(0xFF4CA440),
            ),
            const SizedBox(height: 24),
            Text(
              'verify_identity_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'verify_identity_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Document Selection
            _buildOptionCard(
              icon: Icons.credit_card_outlined,
              title: 'national_id_card'.tr(),
              subtitle: 'scan_national_id'.tr(),
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              icon: Icons.badge_outlined,
              title: 'passport'.tr(),
              subtitle: 'scan_passport'.tr(),
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              icon: Icons.drive_eta_outlined,
              title: 'drivers_license'.tr(),
              subtitle: 'scan_drivers_license'.tr(),
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.push(AppRouterName.identityVerificationStepper),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CA440),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'btn_continue'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF0),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF4CA440), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
