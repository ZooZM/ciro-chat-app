import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:country_picker/country_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../auth/presentation/widgets/phone_field_widget.dart';

class NewContactScreen extends StatefulWidget {
  const NewContactScreen({super.key});

  @override
  State<NewContactScreen> createState() => _NewContactScreenState();
}

class _NewContactScreenState extends State<NewContactScreen> {
  late Country _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = CountryService().findByCode('SA') ?? CountryService().getAll().first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'calls_new_contact_title'.tr(),
          style: AppTypography.headline3.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.resW, vertical: 24.resH),
                child: Column(
                  children: [
                    // First Name Row
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 28.resW, color: Colors.grey[700]),
                        SizedBox(width: 16.resW),
                        Expanded(
                          child: _buildTextField('calls_new_contact_first_name'.tr()),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.resH),
                    // Last Name Row
                    Row(
                      children: [
                        SizedBox(width: 28.resW + 16.resW), // Offset for icon
                        Expanded(
                          child: _buildTextField('calls_new_contact_last_name'.tr()),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.resH),
                    // Phone Number Row
                    Row(
                      children: [
                        Icon(Icons.call_outlined, size: 28.resW, color: Colors.grey[700]),
                        SizedBox(width: 16.resW),
                        // Country Code Picker
                        GestureDetector(
                          onTap: () {
                            showCiroCountryPicker(
                              context: context,
                              selected: _selectedCountry,
                              onSelect: (Country country) {
                                setState(() {
                                  _selectedCountry = country;
                                });
                              },
                            );
                          },
                          child: Container(
                            height: 48.resH,
                            padding: EdgeInsets.symmetric(horizontal: 12.resW),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12.resR),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_selectedCountry.flagEmoji, style: TextStyle(fontSize: 20.resSp)),
                                SizedBox(width: 8.resW),
                                Text('+${_selectedCountry.phoneCode}', style: AppTypography.body1),
                                SizedBox(width: 4.resW),
                                const Icon(Icons.arrow_drop_down, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.resW),
                        Expanded(
                          child: _buildTextField('calls_new_contact_phone'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Save Button
            Padding(
              padding: EdgeInsets.all(24.resW),
              child: SizedBox(
                width: double.infinity,
                height: 52.resH,
                child: ElevatedButton(
                  onPressed: () {
                    // Just pop for now (mock save)
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.resR),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'calls_new_contact_save'.tr(),
                    style: AppTypography.buttonText.copyWith(
                      color: Colors.white,
                      fontSize: 16.resSp,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return SizedBox(
      height: 48.resH,
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.resSp),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.resW),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.resR),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.resR),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
          ),
        ),
      ),
    );
  }
}
