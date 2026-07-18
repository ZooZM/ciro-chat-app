import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../wallet_mock_data.dart';
import '../widgets/wallet_profile_info_card.dart';
import '../widgets/wallet_barcode_action_card.dart';
import '../widgets/wallet_settings_tile.dart';

class WalletProfileScreen extends StatelessWidget {
  const WalletProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = WalletMockData.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 96,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
              onPressed: () => context.pop(),
            ),
          ],
        ),
        title: Text(
          'wallet.profile.title'.tr(),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF1A1A1A)),
            onPressed: () {
              // Show confirmation dialog placeholder
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete account tapped')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A1A1A)),
            onPressed: () {
              // Edit profile placeholder
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile tapped')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.displayName.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 32,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.phoneNumber,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8A8A8A),
              ),
            ),
            const SizedBox(height: 24),
            WalletProfileInfoCard(user: user),
            const SizedBox(height: 24),
            Row(
              children: [
                WalletBarcodeActionCard(
                  title: 'wallet.profile.shareBarcode'.tr(),
                  description: 'wallet.profile.shareBarcodeDesc'.tr(),
                  icon: Icons.share_outlined,
                  onTap: () {
                    Share.share('Check out my Ciro Wallet ID: ${user.ciroId}');
                  },
                ),
                const SizedBox(width: 16),
                WalletBarcodeActionCard(
                  title: 'wallet.profile.viewBarcode'.tr(),
                  description: 'wallet.profile.viewBarcodeDesc'.tr(),
                  icon: Icons.qr_code_2,
                  onTap: () {
                    context.push(AppRouterName.walletReceive);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'wallet.profile.settings'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  WalletSettingsTile(
                    title: 'wallet.profile.accountInfo'.tr(),
                    icon: Icons.person_outline,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account Info tapped')),
                      );
                    },
                  ),
                  WalletSettingsTile(
                    title: 'wallet.profile.verificationSecurity'.tr(),
                    icon: Icons.security,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Security tapped')),
                      );
                    },
                  ),
                  WalletSettingsTile(
                    title: 'wallet.profile.paymentMethod'.tr(),
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment Method tapped')),
                      );
                    },
                  ),
                  WalletSettingsTile(
                    title: 'wallet.profile.notification'.tr(),
                    icon: Icons.notifications_none,
                    onTap: () {
                      context.push(AppRouterName.walletNotifications);
                    },
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
