import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class TermsServiceScreen extends StatelessWidget {
  const TermsServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.locale; // Subscribe to locale changes
    final isRtl = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'help_terms_service'.tr(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Last Updated
              Text(
                'terms_last_updated'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              // Intro
              Text(
                'terms_intro'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Section 1
              _buildSection(
                title: 'terms_sec1_title'.tr(),
                body: 'terms_sec1_body'.tr(),
              ),
              const SizedBox(height: 24),
              // Section 2
              _buildSection(
                title: 'terms_sec2_title'.tr(),
                body: 'terms_sec2_body'.tr(),
              ),
              const SizedBox(height: 24),
              // Section 3
              _buildSection(
                title: 'terms_sec3_title'.tr(),
                body: 'terms_sec3_body'.tr(),
              ),
              const SizedBox(height: 24),
              // Section 4
              _buildSection(
                title: 'terms_sec4_title'.tr(),
                body: 'terms_sec4_body'.tr(),
              ),
              const SizedBox(height: 24),
              // Section 5
              _buildSection(
                title: 'terms_sec5_title'.tr(),
                body: 'terms_sec5_body'.tr(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
