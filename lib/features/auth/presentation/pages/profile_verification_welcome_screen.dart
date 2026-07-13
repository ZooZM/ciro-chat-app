import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../widgets/primary_button.dart';
import '../widgets/profile_verification_stepper.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';

class ProfileVerificationWelcomeScreen extends StatelessWidget {
  const ProfileVerificationWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> stepLabels = [
      'profile_verification_step_invoice'.tr(),
      'profile_verification_step_identify'.tr(),
      'profile_verification_step_bank'.tr(),
      'profile_verification_step_review'.tr(),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.resW),
              child: ProfileVerificationStepper(
                currentStep: -1,
                stepLabels: stepLabels,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.resW),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    
                    // Invoice Image
                    Center(
                      child: Image.asset(
                        'assets/invoice.png',
                        width: 180.resW,
                        height: 180.resW,
                        fit: BoxFit.contain,
                      ),
                    ),
              
              SizedBox(height: 32.resH),
              
              // Title
              Text(
                'profile_verification_welcome_title'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.headline1.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 28.resSp,
                  color: Colors.black,
                ),
              ),
              
              SizedBox(height: 16.resH),
              
              // Subtitle
              Text(
                'profile_verification_welcome_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body1.copyWith(
                  fontSize: 15.resSp,
                  color: AppColors.textSecondary,
                ),
              ),
              
              const Spacer(flex: 3),
              
              // Bottom Actions
              PrimaryButton(
                onPressed: () {
                  context.push(AppRouterName.profileVerificationFlow);
                },
                text: 'profile_verification_get_started'.tr(),
              ),
              
              SizedBox(height: 16.resH),
              
              TextButton(
                onPressed: () {
                  context.go(AppRouterName.home);
                },
                style: TextButton.styleFrom(
                  minimumSize: Size(double.infinity, 56.resH),
                ),
                child: Text(
                  'profile_verification_skip'.tr(),
                  style: AppTypography.body1.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              SizedBox(height: 32.resH),
            ],
          ),
        ),
      ),
    ],
  ),
),
    );
  }
}
