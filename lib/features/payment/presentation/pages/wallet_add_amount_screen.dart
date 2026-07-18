import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../wallet_mock_data.dart';
import '../entities/wallet_entities.dart';
import '../widgets/wallet_numpad.dart';

class WalletAddAmountScreen extends StatefulWidget {
  const WalletAddAmountScreen({super.key});

  @override
  State<WalletAddAmountScreen> createState() => _WalletAddAmountScreenState();
}

class _WalletAddAmountScreenState extends State<WalletAddAmountScreen> {
  String _amount = "0";
  String? _errorText;

  void _onDigitTap(String digit) {
    setState(() {
      _errorText = null;
      if (_amount == "0") {
        _amount = digit;
      } else {
        // Prevent amount from getting unreasonably long (e.g. max 6 digits)
        if (_amount.length < 6) {
          _amount += digit;
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _errorText = null;
      if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = "0";
      }
    });
  }

  void _onNext() {
    final double amount = double.tryParse(_amount) ?? 0.0;
    if (amount < 10) {
      setState(() {
        _errorText = 'wallet.addAmount.minimumHint'.tr();
      });
      return;
    }
    
    // Simulate passing data to PaymentStatusScreen
    final result = PaymentResult(
      status: PaymentResultStatus.success, // Mock success
      amount: amount,
      currency: 'SAR',
      recipientName: 'Wallet Top Up',
      referenceId: 'REF-84920184',
    );
    
    context.push(AppRouterName.walletPaymentStatus, extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final method = WalletMockData.defaultPaymentMethod;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'wallet.title'.tr(), // Ciro wallet header
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 56), // Balance the leading width
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'wallet.addAmount.title'.tr(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'wallet.addAmount.subtitle'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8A8A8A),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _amount,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'SAR',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'wallet.addAmount.minimumHint'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF8A8A8A),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // Fallback if logo is missing
                            child: method.logoAsset != null
                                ? Image.asset(method.logoAsset!, width: 24, height: 24)
                                : const Icon(Icons.account_balance_wallet, color: Color(0xFF1A1A1A), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'wallet.addAmount.paymentMethod'.tr(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A8A8A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  method.displayName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Change payment method tapped')),
                              );
                            },
                            child: Text(
                              'wallet.addAmount.change'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: WalletNumpad(
                onDigitTap: _onDigitTap,
                onBackspace: _onBackspace,
                onNext: _onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
