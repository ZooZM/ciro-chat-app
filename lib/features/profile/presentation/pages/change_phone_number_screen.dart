import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_constants.dart';
import '../../../auth/presentation/widgets/phone_field_widget.dart';
import '../../../auth/presentation/widgets/primary_button.dart';
import '../../../../core/routing/app_router.dart';

class ChangePhoneNumberScreen extends StatefulWidget {
  const ChangePhoneNumberScreen({super.key});

  @override
  State<ChangePhoneNumberScreen> createState() => _ChangePhoneNumberScreenState();
}

class _ChangePhoneNumberScreenState extends State<ChangePhoneNumberScreen> {
  String _phoneNumber = '';
  bool _isValid = false;

  void _onSendCode() {
    if (_isValid && _phoneNumber.isNotEmpty) {
      context.push('${AppRouterName.changePhone}/${AppRouterName.verifyNewPhone}', extra: _phoneNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile_change_phone_title'.tr(),
          style: AppTypography.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.defaultScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 48.resH),

              Text(
                'profile_change_phone_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body1.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 48.resH),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'profile_change_phone_label'.tr(),
                  style: AppTypography.subtitle1.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              CiroPhoneField(
                onChanged: (fullNumber, isValid) {
                  setState(() {
                    _phoneNumber = fullNumber;
                    _isValid = isValid;
                  });
                },
              ),

              const Spacer(),

              PrimaryButton(
                text: 'profile_change_phone_btn'.tr(),
                onPressed: _isValid ? _onSendCode : null,
              ),
              
              SizedBox(height: 16.resH),
            ],
          ),
        ),
      ),
    );
  }
}
