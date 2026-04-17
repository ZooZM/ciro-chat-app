import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_constants.dart';
import '../widgets/primary_button.dart';
import '../bloc/auth_cubit.dart';
import '../../../../core/helpers/permission_service.dart';

class MobileNumberScreen extends StatefulWidget {
  const MobileNumberScreen({super.key});

  @override
  State<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends State<MobileNumberScreen>
    with PermissionHandlerMixin {
  String _phoneNumber = '';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Request all required app permissions at the first screen the user sees
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestAppPermissions();
    });
  }

  void _onSendCode() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_phoneNumber.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid phone number')),
         );
         return;
      }
      context.read<AuthCubit>().submitPhoneNumber(_phoneNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (state is Unauthenticated && _phoneNumber.isNotEmpty) {
          // Send OTP was successful natively. 
          context.push('/auth/verify', extra: _phoneNumber);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppConstants.defaultScreenPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 48.resH), // Spacing from top
                    
                    // Centered Logo
                    SvgPicture.asset(
                      'assets/icons/logo.svg',
                      width: 80.resW,
                      height: 80.resW,
                      placeholderBuilder: (context) => Container(
                        width: 80.resW,
                        height: 80.resW,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chat_bubble, color: Colors.white, size: 40.resW),
                      ),
                    ),

                    SizedBox(height: 32.resH),

                    // Instruction Text
                    Text(
                      'Enter your mobile number to\ncontinue',
                      textAlign: TextAlign.center,
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    SizedBox(height: 48.resH),

                    // Mobile Number Label
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mobile Number',
                        style: AppTypography.subtitle1.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Phone Input Field
                    IntlPhoneField(
                      decoration: InputDecoration(
                        hintText: '123 456 890',
                        hintStyle: AppTypography.body1.copyWith(color: AppColors.divider),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 16.resH),
                      ),
                      initialCountryCode: 'EG',
                      dropdownIcon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary),
                      dropdownIconPosition: IconPosition.trailing,
                      showCountryFlag: true,
                      flagsButtonPadding: const EdgeInsets.only(left: 12),
                      style: AppTypography.body1,
                      cursorColor: AppColors.primary,
                      onChanged: (phone) {
                        _phoneNumber = phone.completeNumber;
                      },
                      validator: (phone) {
                        if (phone == null || phone.number.isEmpty) {
                          return 'Please enter a valid phone number';
                        }
                        return null; // IntlPhoneField generally handles basic validation internally too
                      },
                    ),

                    const Spacer(),

                    // Primary Button
                    PrimaryButton(
                      isLoading: isLoading,
                      onPressed: _onSendCode,
                      text: 'Send Code',
                    ),
                    
                    SizedBox(height: 16.resH),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
