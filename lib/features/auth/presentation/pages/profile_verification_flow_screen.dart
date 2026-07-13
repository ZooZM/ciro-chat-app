import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../widgets/primary_button.dart';
import '../widgets/profile_verification_stepper.dart';
import '../widgets/profile_verification_step_invoice.dart';
import '../widgets/profile_verification_step_identity.dart';
import '../widgets/profile_verification_step_bank.dart';
import '../widgets/profile_verification_step_review.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';

class ProfileVerificationFlowScreen extends StatefulWidget {
  const ProfileVerificationFlowScreen({super.key});

  @override
  State<ProfileVerificationFlowScreen> createState() => _ProfileVerificationFlowScreenState();
}

class _ProfileVerificationFlowScreenState extends State<ProfileVerificationFlowScreen> {
  int _currentStep = 0;
  int _identitySubStep = 0;

  void _onNext() {
    if (_currentStep == 1) {
      if (_identitySubStep < 2) {
        setState(() => _identitySubStep++);
      } else {
        setState(() => _currentStep++);
      }
    } else if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      // Done - navigate to home
      context.go(AppRouterName.home);
    }
  }

  void _onBack() {
    if (_currentStep == 1 && _identitySubStep > 0) {
      setState(() => _identitySubStep--);
    } else if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      // Go back to welcome screen
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouterName.profileVerificationWelcome);
      }
    }
  }

  String _getButtonLabel() {
    if (_currentStep == 0) return 'profile_verification_continue'.tr();
    if (_currentStep == 1) {
      return _identitySubStep < 2 ? 'next'.tr() : 'save'.tr();
    }
    if (_currentStep == 2) return 'bank_save'.tr();
    return 'profile_verification_activate'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> stepLabels = [
      'profile_verification_step_invoice'.tr(),
      'profile_verification_step_identify'.tr(),
      'profile_verification_step_bank'.tr(),
      'profile_verification_step_review'.tr(),
    ];

    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
            color: Colors.black,
            size: 20.resW,
          ),
          onPressed: _onBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.resW),
              child: ProfileVerificationStepper(
                currentStep: _currentStep,
                stepLabels: stepLabels,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.resW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_currentStep == 0) const ProfileVerificationStepInvoice(),
                      if (_currentStep == 1) ProfileVerificationStepIdentity(subStep: _identitySubStep),
                      if (_currentStep == 2) const ProfileVerificationStepBank(),
                      if (_currentStep == 3) const ProfileVerificationStepReview(),
                      
                      SizedBox(height: 32.resH),
                      
                      if (_currentStep != 3) // Review step has its own activate button inline
                        PrimaryButton(
                          onPressed: _onNext,
                          text: _getButtonLabel(),
                        ),
                      
                      SizedBox(height: 32.resH),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
