import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/helpers/responsive.dart';
import '../../domain/entities/call_history_record.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/call_action_card.dart';
import '../data/mock_call_data.dart';

class CallInformationScreen extends StatelessWidget {
  final CallHistoryRecord record;
  const CallInformationScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final callDetails = getMockCallDetails(record.contactUserId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'calls_info_title'.tr(),
          style: AppTypography.headline3.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 16.resH),
            // Header with Avatar and Name
            ContactAvatar(
              initials: record.initials,
              avatarUrl: record.avatarUrl,
              colorSeed: record.avatarColorSeed,
              radius: 60.resR,
              fontSize: 40.resSp,
            ),
            SizedBox(height: 16.resH),
            Text(
              record.contactName,
              style: AppTypography.headline2.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 24.resH),
            // Action Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.resW),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CallActionCard(
                    icon: Icons.chat_bubble_outline,
                    label: 'calls_info_messaging'.tr(),
                    onTap: () {},
                  ),
                  CallActionCard(
                    icon: Icons.videocam_outlined,
                    label: 'calls_info_video_call'.tr(),
                    onTap: () {},
                  ),
                  CallActionCard(
                    icon: Icons.call_outlined,
                    label: 'calls_info_voice_call'.tr(),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.resH),
            Divider(color: AppColors.divider, height: 1),
            // Call Log List
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 16.resH),
                    child: Text(
                      'calls_info_today'.tr(), // Hardcoded Today section header per spec
                      style: AppTypography.subtitle2.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...callDetails.map((detail) => ListTile(
                        leading: Icon(
                          Icons.call,
                          color: AppColors.primary,
                          size: 28.resW,
                        ),
                        title: Text(
                          detail.direction == CallDirection.outgoing 
                              ? 'calls_info_outgoing'.tr() 
                              : 'calls_info_incoming'.tr(),
                          style: AppTypography.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          detail.time,
                          style: AppTypography.body2,
                        ),
                        trailing: Text(
                          detail.status == 'Not answer'
                              ? 'calls_info_not_answer'.tr()
                              : detail.status == 'Answered'
                                  ? 'calls_info_answered'.tr()
                                  : detail.status, // pass through mock strings like "2 min"
                          style: AppTypography.body2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
