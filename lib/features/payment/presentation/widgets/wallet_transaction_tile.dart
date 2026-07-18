import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../entities/wallet_entities.dart';

class WalletTransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final VoidCallback? onTap;

  const WalletTransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive =
        transaction.direction == WalletTransactionDirection.incoming;
    final String amountPrefix = isPositive ? '+' : '';
    final Color amountColor = isPositive ? AppColors.primary : const Color(0xFF1A1A1A);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: transaction.avatarUrl == null
                  ? transaction.avatarColor.withOpacity(0.1)
                  : Colors.transparent,
              backgroundImage: transaction.avatarUrl != null
                  ? NetworkImage(transaction.avatarUrl!)
                  : null,
              child: transaction.avatarUrl == null
                  ? Text(
                      transaction.avatarInitials,
                      style: TextStyle(
                        color: transaction.avatarColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix${transaction.amount.abs().toStringAsFixed(2)} ${transaction.currency}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
