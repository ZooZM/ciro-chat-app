import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';

class AddGooglePayScreen extends StatelessWidget {
  const AddGooglePayScreen({super.key});

  void _showAccountBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGPayLogo(fontSize: 18),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'choose_account'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'to_continue_to'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    'YourApp',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4CA440),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildAccountItem(
                context,
                name: 'Ahmed Hassan',
                email: 'Ahmed@gmai.com',
                isSelected: true,
                onTap: () {
                  context.pop();
                  context.push(AppRouterName.googlePaySuccess);
                },
              ),
              const SizedBox(height: 12),
              _buildAccountItem(
                context,
                name: 'Mohamed ali',
                email: 'Mohamed@gmai.com',
                isSelected: false,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Color(0xFF4CA440)),
                      const SizedBox(width: 12),
                      Text(
                        'add_another_account'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF4CA440),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

  Widget _buildAccountItem(
    BuildContext context, {
    required String name,
    required String email,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FFF0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_outline, color: Color(0xFF4CA440), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGPayLogo({double fontSize = 64}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: 'G', style: TextStyle(color: Colors.blue, fontSize: fontSize, fontWeight: FontWeight.bold)),
              // The exact multi-color G is a bit complex in plain text, but this simulates it reasonably.
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Pay',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEBEBEB),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'add_google_pay'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(child: _buildGPayLogo(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              'add_google_pay_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _showAccountBottomSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CA440),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'done'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
