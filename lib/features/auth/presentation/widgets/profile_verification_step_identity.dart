import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';

class ProfileVerificationStepIdentity extends StatelessWidget {
  final int subStep;
  
  const ProfileVerificationStepIdentity({
    super.key,
    required this.subStep,
  });

  Widget _buildUploadBox(String title) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.resW, vertical: 24.resH),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.resW),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.body1.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            Icons.file_upload_outlined,
            color: AppColors.primary,
            size: 28.resW,
          ),
        ],
      ),
    );
  }

  Widget _buildSubStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'verify_identity_title'.tr(), // Existing key
          style: AppTypography.headline1.copyWith(
            fontSize: 22.resSp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 32.resH),
        Text(
          'national_id_number'.tr(),
          style: AppTypography.body2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.resH),
        TextField(
          style: AppTypography.body1.copyWith(color: Colors.black),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.resW),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.resW),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.resW),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 16.resH),
          ),
        ),
      ],
    );
  }

  Widget _buildSubStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_verification_id_upload_title'.tr(),
          style: AppTypography.headline1.copyWith(
            fontSize: 22.resSp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12.resH),
        Text(
          'make_sure_image_clear'.tr(), // Existing key
          style: AppTypography.body2.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 32.resH),
        _buildUploadBox('front_id_upload'.tr()),
        SizedBox(height: 20.resH),
        _buildUploadBox('back_id_upload'.tr()),
      ],
    );
  }

  Widget _buildSubStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_verification_selfie_title'.tr(),
          style: AppTypography.headline1.copyWith(
            fontSize: 22.resSp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12.resH),
        Text(
          'take_clear_selfie'.tr(), // Existing key
          style: AppTypography.body2.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 48.resH),
        Center(
          child: Container(
            width: 220.resW,
            height: 220.resW,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.camera_alt_outlined,
              color: AppColors.primary,
              size: 48.resW,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (subStep == 0) return _buildSubStep0();
    if (subStep == 1) return _buildSubStep1();
    if (subStep == 2) return _buildSubStep2();
    return const SizedBox.shrink();
  }
}
