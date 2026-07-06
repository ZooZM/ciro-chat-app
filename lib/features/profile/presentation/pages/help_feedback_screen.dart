import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/routing/app_router.dart';

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isRtl = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile_help_feedback'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(isRtl ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        children: [
          _buildCard(
            context: context,
            icon: Icons.headset_mic_outlined,
            title: 'help_contact_us'.tr(),
            subtitle: 'help_contact_us_desc'.tr(),
            onTap: () => context.push(AppRouterName.contactUs),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context: context,
            icon: Icons.help_outline_rounded,
            title: 'help_faq'.tr(),
            subtitle: 'help_faq_desc'.tr(),
            onTap: () => context.push(AppRouterName.faq),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context: context,
            icon: Icons.warning_amber_rounded,
            title: 'help_report_problem'.tr(),
            subtitle: 'help_report_problem_desc'.tr(),
            iconColor: const Color(0xFFE53935),
            iconBackgroundColor: const Color(0xFFFFF0F0),
            onTap: () => context.push(AppRouterName.reportProblem),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context: context,
            icon: Icons.thumb_up_alt_outlined,
            title: 'help_send_feedback'.tr(),
            subtitle: 'help_send_feedback_desc'.tr(),
            onTap: () => context.push(AppRouterName.sendFeedback),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: 'help_privacy_policy'.tr(),
            onTap: () => context.push(AppRouterName.privacyPolicy),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context: context,
            icon: Icons.description_outlined,
            title: 'help_terms_service'.tr(),
            onTap: () => context.push(AppRouterName.termsService),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'help_app_info'.tr(),
            subtitle: '${'help_version'.tr()}\n${'help_last_updated'.tr()}',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? iconBackgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor ?? Colors.black54, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
