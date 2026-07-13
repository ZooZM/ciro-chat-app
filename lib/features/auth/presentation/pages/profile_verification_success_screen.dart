import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import '../widgets/primary_button.dart';

class ProfileVerificationSuccessScreen extends StatelessWidget {
  const ProfileVerificationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.resW),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              
              // Success Image
              Center(
                child: Image.asset(
                  'assets/right_check.png',
                  width: 220.resW,
                  height: 220.resW,
                  fit: BoxFit.contain,
                ),
              ),
              
              SizedBox(height: 32.resH),
              
              // Title
              Text(
                'profile_verification_success_title'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.headline1.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 24.resSp,
                  color: Colors.black,
                ),
              ),
              
              SizedBox(height: 12.resH),
              
              // Subtitle
              Text(
                'profile_verification_success_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body1.copyWith(
                  fontSize: 15.resSp,
                  color: AppColors.textSecondary,
                ),
              ),
              
              const Spacer(flex: 4),
              
              // Finish Button
              PrimaryButton(
                onPressed: () {
                  context.go(AppRouterName.home);
                },
                text: 'profile_verification_finish'.tr(),
              ),
              
              SizedBox(height: 32.resH),
            ],
          ),
        ),
      ),
    );
  }
}
