import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';

class ProfileVerificationStepBank extends StatefulWidget {
  const ProfileVerificationStepBank({super.key});

  @override
  State<ProfileVerificationStepBank> createState() =>
      _ProfileVerificationStepBankState();
}

class _ProfileVerificationStepBankState
    extends State<ProfileVerificationStepBank> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  String? _selectedBank;
  bool _isIbanValid = false;

  final List<String> _bankOptions = [
    'Saudi National Bank (SNB)',
    'Al Rajhi Bank',
    'Riyad Bank',
    'Saudi Awwal Bank (SAB)',
    'Saudi Fransi Bank',
    'Arab National Bank (ANB)',
    'Alinma Bank',
    'Bank Albilad',
    'Bank AlJazira',
    'Saudi Investment Bank (SAIB)',
  ];

  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _ibanController.addListener(_validateIban);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  void _validateIban() {
    final text = _ibanController.text.replaceAll(' ', '');
    // Typical SA IBAN length is 24
    final isValid = text.length >= 24;
    if (_isIbanValid != isValid) {
      setState(() {
        _isIbanValid = isValid;
      });
    }
  }

  Widget _buildTextField(
    String label, {
    required TextEditingController controller,
    bool isIban = false,
  }) {
    final hasCheck = isIban && _isIbanValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body2.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.resH),
        TextField(
          controller: controller,
          style: AppTypography.body1.copyWith(color: Colors.black),
          decoration: InputDecoration(
            hintText: isIban ? 'SA00 0000 0000 0000 0000 0000' : '',
            hintStyle: AppTypography.body2.copyWith(
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.resW),
              borderSide: BorderSide(
                color: hasCheck ? AppColors.primary : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.resW),
              borderSide: BorderSide(
                color: hasCheck ? AppColors.primary : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.resW),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 16.resH,
            ),
            suffixIcon: hasCheck
                ? Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 20.resW,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBankDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your bank',
          style: AppTypography.body2.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.resH),

        // Custom Dropdown Header
        GestureDetector(
          onTap: () {
            setState(() {
              _isDropdownOpen = !_isDropdownOpen;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 16.resH,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: AppColors.primary,
              ), // Always green in screenshot
              borderRadius: _isDropdownOpen
                  ? BorderRadius.vertical(top: Radius.circular(16.resW))
                  : BorderRadius.circular(16.resW),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedBank ?? 'Riyad Bank', // Fallback to match screenshot
                  style: AppTypography.body1.copyWith(color: Colors.black),
                ),
                Icon(
                  _isDropdownOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),

        // Custom Dropdown List
        if (_isDropdownOpen)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: AppColors.primary),
                right: BorderSide(color: AppColors.primary),
                bottom: BorderSide(color: AppColors.primary),
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(16.resW),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250.resH),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: _bankOptions.map((bank) {
                    final isSelected =
                        _selectedBank == bank ||
                        (_selectedBank == null && bank == 'Riyad Bank');
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedBank = bank;
                          _isDropdownOpen = false;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        color: isSelected
                            ? const Color(0xFFF5F5F5)
                            : Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.resW,
                          vertical: 14.resH,
                        ),
                        child: Text(
                          bank,
                          style: AppTypography.body2.copyWith(
                            color: const Color(0xFF616161),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
          'Bank Account Verification',
          style: AppTypography.headline1.copyWith(
            fontSize: 22.resSp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 32.resH),

        _buildTextField(
          'Full Name',
          controller: _fullNameController,
          isIban: false,
        ),
        SizedBox(height: 24.resH),

        _buildTextField('IBAN', controller: _ibanController, isIban: true),
        SizedBox(height: 24.resH),

        _buildBankDropdown(),
      ],
    );
  }
}
