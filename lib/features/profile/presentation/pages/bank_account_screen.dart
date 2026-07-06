import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  bool _isEditing = false; // Start in View Mode with pre-populated data

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _ibanController;
  String? _selectedBank;
  bool _isIbanValid = true;

  final List<String> _banks = [
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
    'Gulf International Bank (GIB)',
    'stc Bank',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with values from the mockup image
    _fullNameController = TextEditingController(text: 'Al Noor Trading Company');
    _ibanController = TextEditingController(text: 'SA1234567890123456781234');
    _selectedBank = 'Al Rajhi Bank';
    
    _ibanController.addListener(_validateIbanListener);
  }

  void _validateIbanListener() {
    final text = _ibanController.text.trim().replaceAll(' ', '');
    // Simple validation: starts with SA and is at least 15 chars (SA IBANs are 24 chars)
    setState(() {
      _isIbanValid = text.toUpperCase().startsWith('SA') && text.length >= 15;
    });
  }

  @override
  void dispose() {
    _ibanController.removeListener(_validateIbanListener);
    _fullNameController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  // Format IBAN for display (e.g. SA12 **** **** **** 1234)
  String _getMaskedIban(String rawIban) {
    final clean = rawIban.replaceAll(' ', '');
    if (clean.length < 8) return clean;
    final prefix = clean.substring(0, 4);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix **** **** **** $suffix';
  }

  // Format IBAN with spacing for editing (e.g. SA05 1234 5678 7910 1112 4073)
  String _formatIbanWithSpaces(String text) {
    final clean = text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      buffer.write(clean[i]);
      if ((i + 1) % 4 == 0 && (i + 1) != clean.length) {
        buffer.write(' ');
      }
    }
    return buffer.toString().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    context.locale; // subscribe to changes
    final isRtl = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile_bank_account'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(isRtl ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _isEditing ? _buildEditMode() : _buildViewMode(),
        ),
      ),
    );
  }

  // Edit Mode - Image 1, 2, 3
  Widget _buildEditMode() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Full Name Input
          _buildInputField(
            label: 'bank_full_name'.tr(),
            controller: _fullNameController,
          ),
          const SizedBox(height: 20),
          // IBAN Input
          _buildIbanField(),
          const SizedBox(height: 20),
          // Bank Dropdown
          _buildBankDropdownField(),
          const SizedBox(height: 80),
          // Save Button
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate() && _selectedBank != null) {
                setState(() {
                  _isEditing = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CA440),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'bank_save'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // View Mode - Image 4
  Widget _buildViewMode() {
    final isRtl = context.locale.languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 4,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Edit Button Top Right
          Align(
            alignment: isRtl ? Alignment.topLeft : Alignment.topRight,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'bank_edit'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Details Rows
          _buildDetailRow(
            label: 'bank_name_label'.tr(),
            value: _selectedBank ?? '-',
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'bank_holder_label'.tr(),
            value: _fullNameController.text,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'bank_iban'.tr(),
            value: _getMaskedIban(_ibanController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CA440), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CA440), width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2.0),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildIbanField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'bank_iban'.tr(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ibanController,
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          keyboardType: TextInputType.text,
          onChanged: (val) {
            final formatted = _formatIbanWithSpaces(val);
            if (formatted != val) {
              _ibanController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: _isIbanValid
                ? const Icon(Icons.check_circle, color: Color(0xFF4CA440), size: 22)
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CA440), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CA440), width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2.0),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            final clean = value.replaceAll(' ', '');
            if (!clean.toUpperCase().startsWith('SA')) {
              return 'IBAN must start with SA';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBankDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'bank_select'.tr(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBank,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CA440), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CA440), width: 2.0),
            ),
          ),
          hint: Text('bank_choose'.tr(), style: TextStyle(color: Colors.grey.shade400)),
          items: _banks.map((bank) {
            return DropdownMenuItem<String>(
              value: bank,
              child: Text(bank, style: const TextStyle(color: Colors.black87)),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedBank = val;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Please select your bank';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    final isRtl = context.locale.languageCode == 'ar';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: isRtl ? TextAlign.left : TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
