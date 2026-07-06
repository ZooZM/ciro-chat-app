import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/routing/app_router.dart';
import '../data/mock_profile_data.dart';
import '../widgets/wallet_card.dart';
import '../widgets/profile_completion_bar.dart';

class ProfileMainScreen extends StatelessWidget {
  const ProfileMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Explicitly subscribe to locale changes so the screen rebuilds immediately
    context.locale;

    final user = MockProfileData.currentUser;
    final wallet = MockProfileData.currentWallet;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'profile_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 28,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: Colors.black87, size: 32),
            onPressed: () {
              context.push(AppRouterName.qrCode);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Section
            Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.bio,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'profile_ciro_id'.tr(),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            user.ciroId,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_outlined, size: 14, color: Colors.grey[600]),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit Icon
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.black87, size: 28),
                  onPressed: () {
                    context.push(AppRouterName.profileInfo);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Wallet Card
            WalletCard(wallet: wallet),
            const SizedBox(height: 16),

            // Profile Completion Bar
            ProfileCompletionBar(percentage: user.completionPercentage),
            const SizedBox(height: 16),

            // Settings List
            _buildSettingsItem(
              icon: Icons.palette_outlined,
              title: 'profile_appearance'.tr(),
              subtitle: 'profile_appearance_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.appearance),
            ),
            _buildSettingsItem(
              icon: Icons.person_add_outlined,
              title: 'profile_invite_friend'.tr(),
              subtitle: 'profile_invite_friend_subtitle'.tr(),
              onTap: () {
                context.push(AppRouterName.inviteFriend);
              },
            ),
            _buildSettingsItem(
              icon: Icons.language,
              title: 'profile_language'.tr(),
              subtitle: 'profile_language_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.language),
            ),
            _buildSettingsItem(
              icon: Icons.receipt_long_outlined,
              title: 'profile_billing_info'.tr(),
              subtitle: 'profile_billing_info_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.billingInfo),
            ),
            _buildSettingsItem(
              icon: Icons.account_balance_outlined,
              title: 'profile_bank_account'.tr(),
              subtitle: 'profile_bank_account_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.bankAccount),
            ),
            _buildSettingsItem(
              icon: Icons.badge_outlined,
              title: 'profile_identity_verification'.tr(),
              subtitle: 'profile_identity_verification_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.identityVerification),
            ),
            _buildSettingsItem(
              icon: Icons.credit_card_outlined,
              title: 'profile_payments_method'.tr(),
              subtitle: 'profile_payments_method_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.paymentsMethod),
            ),
            _buildSettingsItem(
              icon: Icons.payments_outlined,
              title: 'profile_payments_history'.tr(),
              subtitle: 'profile_payments_history_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.paymentsHistory),
            ),
            _buildSettingsItem(
              icon: Icons.lock_outline,
              title: 'profile_privacy'.tr(),
              subtitle: 'profile_privacy_subtitle'.tr(),
              onTap: () {
                context.push(AppRouterName.privacy);
              },
            ),
            _buildSettingsItem(
              icon: Icons.notifications_none_outlined,
              title: 'profile_notifications'.tr(),
              subtitle: 'profile_notifications_subtitle'.tr(),
              onTap: () {
                context.push(AppRouterName.notifications);
              },
            ),
            _buildSettingsItem(
              icon: Icons.settings_phone_outlined,
              title: 'profile_change_phone'.tr(),
              onTap: () {
                context.push(AppRouterName.changePhone);
              },
            ),
            _buildSettingsItem(
              icon: Icons.help_outline,
              title: 'profile_help_feedback'.tr(),
              subtitle: 'profile_help_feedback_subtitle'.tr(),
              onTap: () => context.push(AppRouterName.helpFeedback),
            ),
            _buildSettingsItem(
              icon: Icons.logout,
              title: 'profile_logout'.tr(),
              iconColor: Colors.red,
              titleColor: Colors.red,
              iconBackgroundColor: const Color(0xFFFFF0F0),
              showTrailing: false,
              onTap: () {
                context.push(AppRouterName.logout);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );

  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    Color? iconBackgroundColor,
    bool showTrailing = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withAlpha(51), width: 1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor ?? Colors.black87, size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: titleColor ?? Colors.black87),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                )
              : null,
          trailing: showTrailing ? const Icon(Icons.chevron_right, color: Colors.grey, size: 24) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
