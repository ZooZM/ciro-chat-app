import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class IdentityVerificationSuccessScreen extends StatelessWidget {
  const IdentityVerificationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'verify_identity_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(context.locale.languageCode == 'ar' ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('edit'.tr(), style: const TextStyle(color: Colors.black54)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade600),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/fef62f309a322c6bc2c6cc8d7cd250914c058627.jpg',
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildInfoRow('id_number'.tr(), '1234567890'),
                const SizedBox(height: 16),
                _buildStatusRow('status'.tr(), 'verified'.tr()),
                const SizedBox(height: 16),
                _buildStatusRow('face_match'.tr(), 'matched'.tr()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 16,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FFF0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4CA440).withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF4CA440), size: 16),
              const SizedBox(width: 4),
              Text(
                status,
                style: const TextStyle(
                  color: Color(0xFF4CA440),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
