import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../entities/wallet_entities.dart';
import '../widgets/wallet_payment_status_icon.dart';
import '../widgets/wallet_reference_id_card.dart';

class WalletPaymentStatusScreen extends StatelessWidget {
  final PaymentResult result;

  const WalletPaymentStatusScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = result.status == PaymentResultStatus.success;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              WalletPaymentStatusIcon(isSuccess: isSuccess),
              const SizedBox(height: 24),
              Text(
                isSuccess
                    ? 'wallet.payment.success.title'.tr()
                    : 'wallet.payment.failed.title'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (isSuccess)
                Text(
                  'wallet.payment.success.subtitle'.tr(
                    namedArgs: {
                      'amount': '${result.amount.toStringAsFixed(2)} ${result.currency}',
                      'recipient': result.recipientName,
                    },
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8A8A8A),
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  result.failureReason ?? 'wallet.payment.failed.subtitle'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFE53935),
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              WalletReferenceIdCard(referenceId: result.referenceId),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop back to the main wallet screen, removing intermediate screens
                    while (context.canPop()) {
                      context.pop();
                    }
                    context.replace(AppRouterName.wallet);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'wallet.payment.done'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
