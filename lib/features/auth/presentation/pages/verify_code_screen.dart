import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_constants.dart';
import '../widgets/primary_button.dart';
import '../bloc/auth_cubit.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String phoneNumber;

  const VerifyCodeScreen({super.key, required this.phoneNumber});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  String _pin = '';

  void _onVerify() {
    if (_pin.length == 6) {
      context.read<AuthCubit>().submitOtp(widget.phoneNumber, _pin);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
    }
  }

  void _onResend() {
    context.read<AuthCubit>().submitPhoneNumber(widget.phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50.resW, // Resized to scale responsively
      height: 56.resH, // Resized to scale responsively
      textStyle: AppTypography.headline2,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2.0),
    );

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (state is Authenticated) {
          // Success! The updated Auth state automatically triggers GoRouter's
          // refreshListenable, ripping this screen away natively.
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppConstants.defaultScreenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 64.resH), // Spacing from top
                  // Header Title
                  Text(
                    'Verify code',
                    textAlign: TextAlign.center,
                    style: AppTypography.headline1.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),

                  SizedBox(height: 12.resH),

                  // Subtitle Text Block
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Please enter the code we just send to\n',
                        ),
                        TextSpan(
                          text: 'Phone number ',
                          style: AppTypography.body1.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: widget.phoneNumber,
                          style: AppTypography.headline2.copyWith(
                            fontSize: AppTypography.body1.fontSize,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 48.resH),

                  // OTP Entry Field
                  Pinput(
                    length: 6,
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
                      _onVerify(); // Auto-verify
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

                  // Resend Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Didn’t receive code? ',
                        style: AppTypography.body1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: isLoading ? null : _onResend,
                        child: Text(
                          'Resend code',
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

                  // Primary Button
                  PrimaryButton(
                    isLoading: isLoading,
                    onPressed: _onVerify,
                    text: 'Verify',
                  ),

                  SizedBox(height: 16.resH),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
