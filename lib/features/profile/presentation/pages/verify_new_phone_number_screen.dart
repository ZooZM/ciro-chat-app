import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_constants.dart';
import '../../../auth/presentation/widgets/primary_button.dart';

class VerifyNewPhoneNumberScreen extends StatefulWidget {
  final String phoneNumber;

  const VerifyNewPhoneNumberScreen({super.key, required this.phoneNumber});

  @override
  State<VerifyNewPhoneNumberScreen> createState() => _VerifyNewPhoneNumberScreenState();
}

class _VerifyNewPhoneNumberScreenState extends State<VerifyNewPhoneNumberScreen> {
  String _pin = '';

  void _onVerify() {
    if (_pin.length == 6) {
      // Logic would go here. For now just pop back to profile with a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_verify_phone_success'.tr())),
      );
      context.pop();
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_verify_phone_error'.tr())),
      );
    }
  }

  void _onResend() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('profile_verify_phone_resent'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50.resW, // Fit 6 digits
      height: 56.resH, 
      textStyle: AppTypography.headline2,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2.0),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile_verify_phone_title'.tr(),
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
              SizedBox(height: 32.resH),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTypography.body1.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  children: [
                    TextSpan(
                      text: 'profile_verify_phone_subtitle_1'.tr(),
                    ),
                    TextSpan(
                      text: 'profile_verify_phone_subtitle_2'.tr(),
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: AppTypography.body1.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 48.resH),

              Pinput(
                length: 6, // Updated to 6 slots
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: defaultPinTheme,
                onChanged: (val) {
                  setState(() {
                    _pin = val;
                  });
                },
                onCompleted: (val) {
                  _pin = val;
                  _onVerify();
                },
                cursor: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: 16.resH),
                      width: 22.resW,
                      height: 2.resH,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 48.resH),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'profile_verify_phone_no_code'.tr(),
                    style: AppTypography.body1.copyWith(
                      color: AppColors.primary, // Based on image it's green
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: _onResend,
                    child: Text(
                      'profile_verify_phone_resend'.tr(),
                      style: AppTypography.body1.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              PrimaryButton(
                onPressed: _onVerify,
                text: 'profile_verify_phone_btn'.tr(),
              ),

              SizedBox(height: 16.resH),
            ],
          ),
        ),
      ),
    );
  }
}
