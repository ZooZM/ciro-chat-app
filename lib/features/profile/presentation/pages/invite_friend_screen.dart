import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/routing/app_router.dart';

class InviteFriendScreen extends StatelessWidget {
  const InviteFriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'invite_friend_title'.tr(),
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          children: [
            Text(
              'invite_friend_desc'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                context.push(AppRouterName.inviteLink);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CA440),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'invite_share_link'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                context.push(AppRouterName.inviteVia);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Color(0xFF4CA440), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'invite_share_via_ciro'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                context.push(AppRouterName.qrCode);
              },
              icon: const Icon(Icons.qr_code_scanner, color: Colors.black54),
              label: Text(
                'invite_display_qr'.tr(),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
