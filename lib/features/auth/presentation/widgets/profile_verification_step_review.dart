import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'primary_button.dart';

class ProfileVerificationStepReview extends StatelessWidget {
  const ProfileVerificationStepReview({super.key});

  Widget _buildCardHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.headline1.copyWith(
            fontSize: 18.resSp,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Row(
          children: [
            Text(
              'profile_verification_edit'.tr(),
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.resW),
            Icon(Icons.edit_outlined, size: 18.resW, color: AppColors.textSecondary),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyValueRow(String key, String value, {Widget? valueWidget}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.resH),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              key,
              style: AppTypography.caption.copyWith(
                color: const Color(0xFF9E9E9E), // Light grey
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8.resW),
          Expanded(
            flex: 3,
            child: valueWidget ?? Text(
              value,
              style: AppTypography.body2.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.resW, vertical: 4.resH),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Light green background
        borderRadius: BorderRadius.circular(6.resW),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: const Color(0xFF4CAF50), size: 16.resW),
          SizedBox(width: 6.resW),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF4CAF50),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            'Review Your Information',
            style: AppTypography.headline1.copyWith(
              fontSize: 24.resSp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(height: 12.resH),
        Center(
          child: Text(
            'Please review your information before confirming\nand activating your account',
            textAlign: TextAlign.center,
            style: AppTypography.body1.copyWith(
              fontSize: 14.resSp,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        SizedBox(height: 32.resH),
        
        // Card 1: Business Information (Invoice)
        Container(
          padding: EdgeInsets.all(16.resW),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.resW),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildCardHeader('Business Information'),
              SizedBox(height: 16.resH),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70.resW,
                    height: 70.resW,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Icon(Icons.bar_chart, color: const Color(0xFF00796B), size: 40.resW),
                    ),
                  ),
                  SizedBox(width: 16.resW),
                  Expanded(
                    child: Column(
                      children: [
                        _buildKeyValueRow('Business Name', 'Al Noor Trading Company'),
                        _buildKeyValueRow('Commercial Registration No.', '1010234567'),
                        _buildKeyValueRow('Tax Number', '300123456700003'),
                        _buildKeyValueRow('Business Address', 'Riyadh, Al Olaya, Kingdom of Saudi Arabia'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16.resH),
        
        // Card 2: Identity Verification
        Container(
          padding: EdgeInsets.all(16.resW),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.resW),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildCardHeader('Identity Verification'),
              SizedBox(height: 16.resH),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 90.resW,
                    height: 60.resH,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8.resW),
                      image: const DecorationImage(
                        image: AssetImage('assets/fef62f309a322c6bc2c6cc8d7cd250914c058627.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.resW),
                  Expanded(
                    child: Column(
                      children: [
                        _buildKeyValueRow('ID Number', '1234567890'),
                        _buildKeyValueRow('Status', '', valueWidget: _buildBadge('Verified')),
                        _buildKeyValueRow('Face Match', '', valueWidget: _buildBadge('Matched')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16.resH),
        
        // Card 3: Business Information (Bank)
        Container(
          padding: EdgeInsets.all(16.resW),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.resW),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildCardHeader('Business Information'),
              SizedBox(height: 16.resH),
              _buildKeyValueRow('Bank Name', 'Al Rajhi Bank'),
              _buildKeyValueRow('Account Holder Name', 'Al Noor Trading Company'),
              _buildKeyValueRow('IBAN', 'SA12 **** **** **** 1234'),
            ],
          ),
        ),
        
        SizedBox(height: 16.resH),
        
        // Warning Banner
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 12.resH),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8.resW),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.black54, size: 20.resW),
              SizedBox(width: 12.resW),
              Expanded(
                child: Text(
                  'Please make sure all information is correct before proceeding',
                  style: AppTypography.caption.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 32.resH),
        
        PrimaryButton(
          onPressed: () {
            // Activate account and go to success screen
            context.go(AppRouterName.profileVerificationSuccess);
          },
          text: 'Activate Account',
        ),
      ],
    );
  }
}
