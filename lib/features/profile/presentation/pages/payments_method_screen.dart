import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';

class PaymentsMethodScreen extends StatelessWidget {
  const PaymentsMethodScreen({super.key});

  void _showAddPaymentBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text(
                    'add_payment_method'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildBottomSheetItem(
                      context,
                      icon: Icons.credit_card,
                      title: 'add_new_crd'.tr(),
                      subtitle: 'supported_cards'.tr(),
                      onTap: () {
                        context.pop();
                        context.push(AppRouterName.addNewCard);
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                    _buildBottomSheetItem(
                      context,
                      icon: Icons.apple,
                      title: 'Apple Pay',
                      onTap: () {
                        context.pop();
                        context.push(AppRouterName.addApplePay);
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                    _buildBottomSheetItem(
                      context,
                      icon: Icons.payment,
                      title: 'Google Pay',
                      onTap: () {
                        context.pop();
                        context.push(AppRouterName.addGooglePay);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile_payments_method'.tr(),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'saved_method'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildSavedMethodItem(
                    title: 'Apple Pay',
                    subtitle: 'connected'.tr(),
                    icon: Icons.apple,
                    trailingIcon: Icons.check_circle_outline,
                    trailingColor: const Color(0xFF4CA440),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _buildSavedMethodItem(
                    title: 'Google Pay',
                    subtitle: 'connected_lower'.tr(),
                    icon: Icons.payment,
                    trailingIcon: Icons.check_circle_outline,
                    trailingColor: const Color(0xFF4CA440),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _buildSavedMethodItem(
                    title: 'mada ****4242',
                    subtitle: '${'expires'.tr()} 11/25',
                    isMada: true,
                    trailingIcon: Icons.more_horiz,
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _buildSavedMethodItem(
                    title: 'Mastercard ****4242',
                    subtitle: '${'expires'.tr()} 07/27',
                    isMastercard: true,
                    trailingIcon: Icons.more_horiz,
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _buildSavedMethodItem(
                    title: 'Visa ****4242',
                    subtitle: '${'expires_s'.tr()} 04/26',
                    isVisa: true,
                    trailingIcon: Icons.more_horiz,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => _showAddPaymentBottomSheet(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: Color(0xFF4CA440)),
                    const SizedBox(width: 8),
                    Text(
                      'add_new_crd'.tr(),
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
    );
  }

  Widget _buildSavedMethodItem({
    required String title,
    required String subtitle,
    IconData? icon,
    bool isMada = false,
    bool isMastercard = false,
    bool isVisa = false,
    required IconData trailingIcon,
    Color trailingColor = Colors.grey,
  }) {
    Widget leadingWidget;
    if (isMada) {
      leadingWidget = Container(
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 8, height: 8, color: Colors.blue),
            const SizedBox(width: 2),
            Container(width: 8, height: 8, color: const Color(0xFF4CA440)),
          ],
        ),
      );
    } else if (isMastercard) {
      leadingWidget = SizedBox(
        width: 40,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 6,
              child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ),
            Positioned(
              right: 6,
              child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.orange.withAlpha(200), shape: BoxShape.circle)),
            ),
          ],
        ),
      );
    } else if (isVisa) {
      leadingWidget = SizedBox(
        width: 40,
        child: const Text(
          'VISA',
          style: TextStyle(
            color: Colors.indigo,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
        ),
      );
    } else {
      leadingWidget = SizedBox(
        width: 40,
        child: Icon(icon, color: Colors.black, size: 28),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          leadingWidget,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Icon(trailingIcon, color: trailingColor, size: 20),
        ],
      ),
    );
  }
}
