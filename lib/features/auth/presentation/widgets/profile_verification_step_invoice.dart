import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';

class ProfileVerificationStepInvoice extends StatelessWidget {
  const ProfileVerificationStepInvoice({super.key});

  Widget _buildTextField(String label, {String? suffixText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.body2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (suffixText != null) ...[
              SizedBox(width: 4.resW),
              Text(
                suffixText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 16.resH,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_verification_invoice_title'.tr(),
          style: AppTypography.headline1.copyWith(
            fontSize: 22.resSp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 32.resH),

        // Logo Upload Placeholder
        Center(
          child: Container(
            width: 150.resW,
            height: 150.resW,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file,
                  color: AppColors.primary,
                  size: 32.resW,
                ),
                SizedBox(height: 8.resH),
                Text(
                  'profile_verification_company_logo'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 40.resH),

        // Form Fields
        _buildTextField('profile_verification_business_name'.tr()),
        SizedBox(height: 20.resH),

        _buildTextField('profile_verification_cr_number'.tr()),
        SizedBox(height: 20.resH),

        _buildTextField(
          'profile_verification_tax_number'.tr(),
          suffixText: 'profile_verification_tax_optional'.tr(),
        ),
        SizedBox(height: 20.resH),

        _buildTextField('profile_verification_address'.tr()),
      ],
    );
  }
}
