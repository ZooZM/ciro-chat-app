import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class BillingInfoScreen extends StatefulWidget {
  const BillingInfoScreen({super.key});

  @override
  State<BillingInfoScreen> createState() => _BillingInfoScreenState();
}

class _BillingInfoScreenState extends State<BillingInfoScreen> {
  bool _isEditing = false; // Start in View Mode with pre-populated data

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _businessNameController;
  late TextEditingController _crController;
  late TextEditingController _taxController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    // Pre-populate with values from the mockup image
    _businessNameController = TextEditingController(text: 'Al Noor Trading Company');
    _crController = TextEditingController(text: '1010234567');
    _taxController = TextEditingController(text: '300123456700003');
    _addressController = TextEditingController(text: 'Riyadh, Al Olaya, Kingdom of Saudi Arabia');
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _crController.dispose();
    _taxController.dispose();
    _addressController.dispose();
    super.dispose();
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
          'profile_billing_info'.tr(),
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

  // IMAGE 1 - Edit Mode
  Widget _buildEditMode() {
    final isRtl = context.locale.languageCode == 'ar';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Upload Logo Circle
          Center(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_outlined, color: Colors.grey.shade400, size: 36),
                  const SizedBox(height: 4),
                  Text(
                    'billing_company_logo'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Fields
          _buildInputField(
            label: 'billing_business_name'.tr(),
            controller: _businessNameController,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'billing_commercial_registration'.tr(),
            controller: _crController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: '${'billing_tax_number'.tr()} ${'billing_optional'.tr()}',
            controller: _taxController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'billing_address'.tr(),
            controller: _addressController,
          ),
          const SizedBox(height: 48),
          // Save Button
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
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
              'billing_save_info'.tr(),
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

  // IMAGE 2 - View Mode
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
                    'billing_edit'.tr(),
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
          const SizedBox(height: 8),
          // Logo Circle with slanting bars
          Center(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
              child: CustomPaint(
                painter: CompanyLogoPainter(),
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Details Card Fields
          _buildDetailRow(
            label: 'billing_business_name'.tr(),
            value: _businessNameController.text,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'billing_commercial_registration_no'.tr(),
            value: _crController.text,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'billing_tax_number'.tr(),
            value: _taxController.text.isNotEmpty ? _taxController.text : '-',
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            label: 'billing_address'.tr(),
            value: _addressController.text,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
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
            if (!label.contains('Optional') && !label.contains('اختياري') && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
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

class CompanyLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF005F66) // Dark cyan/teal color matching the logo in the mockup image
      ..style = PaintingStyle.fill;

    // Left pillar
    final path1 = Path()
      ..moveTo(size.width * 0.35, size.height * 0.75)
      ..lineTo(size.width * 0.35, size.height * 0.44)
      ..lineTo(size.width * 0.44, size.height * 0.34)
      ..lineTo(size.width * 0.44, size.height * 0.75)
      ..close();
    canvas.drawPath(path1, paint);

    // Middle pillar
    final path2 = Path()
      ..moveTo(size.width * 0.49, size.height * 0.75)
      ..lineTo(size.width * 0.49, size.height * 0.28)
      ..lineTo(size.width * 0.58, size.height * 0.18)
      ..lineTo(size.width * 0.58, size.height * 0.75)
      ..close();
    canvas.drawPath(path2, paint);

    // Right pillar
    final path3 = Path()
      ..moveTo(size.width * 0.63, size.height * 0.75)
      ..lineTo(size.width * 0.63, size.height * 0.52)
      ..lineTo(size.width * 0.72, size.height * 0.42)
      ..lineTo(size.width * 0.72, size.height * 0.75)
      ..close();
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CompanyLogoPainter oldDelegate) => false;
}
