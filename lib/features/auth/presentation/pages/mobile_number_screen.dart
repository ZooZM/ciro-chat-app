import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../widgets/primary_button.dart';
import '../widgets/phone_field_widget.dart';
import '../bloc/auth_cubit.dart';
import '../../../../core/helpers/permission_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_constants.dart';
import '../../../../core/theme/app_logo.dart';

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
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 48.resH), // Spacing from top
                          // Centered Logo
                          const AppLogoWidget(
                            size: 180,
                            showText: false, // Icon only on auth screen
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

                          // Phone Input (CiroPhoneField = full custom UI control)
                          CiroPhoneField(
                            onChanged: (fullNumber) {
                              _phoneNumber = fullNumber;
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 32.resH),
                        ],
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Container(
                        alignment: Alignment.bottomCenter,
                        padding: EdgeInsets.only(bottom: 16.resH),
                        child:
                            // Primary Button
                            PrimaryButton(
                              isLoading: isLoading,
                              onPressed: _onSendCode,
                              text: 'Send Code',
                            ),
                      ),
                    ),
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
