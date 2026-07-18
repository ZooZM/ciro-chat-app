import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class WalletPaymentStatusIcon extends StatelessWidget {
  final bool isSuccess;

  const WalletPaymentStatusIcon({super.key, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Center(
        child: Image.asset(
          isSuccess ? 'assets/right_check.png' : 'assets/failed.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
