import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class InviteViaScreen extends StatelessWidget {
  const InviteViaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'invite_via_title'.tr(),
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
          _buildInviteOption(Icons.chat_bubble, 'invite_via_messenger'.tr(), Colors.blue),
          _buildInviteOption(Icons.chat, 'invite_via_whatsapp'.tr(), Colors.green),
          _buildInviteOption(Icons.facebook, 'invite_via_facebook'.tr(), Colors.blueAccent),
          _buildInviteOption(Icons.camera_alt, 'invite_via_instagram'.tr(), Colors.orange),
          _buildInviteOption(Icons.link, 'invite_via_copy'.tr(), Colors.grey),
          _buildInviteOption(Icons.more_horiz, 'invite_via_more'.tr(), Colors.grey),
        ],
      ),
    );
  }

  Widget _buildInviteOption(IconData icon, String title, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black87),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          onTap: () {},
        ),
      ),
    );
  }
}
