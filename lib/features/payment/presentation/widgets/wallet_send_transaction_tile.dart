import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../entities/wallet_entities.dart';

class WalletSendTransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final VoidCallback onTap;

  const WalletSendTransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: transaction.avatarUrl == null
                  ? transaction.avatarColor
                  : Colors.transparent,
              backgroundImage: transaction.avatarUrl != null
                  ? NetworkImage(transaction.avatarUrl!)
                  : null,
              child: transaction.avatarUrl == null
                  ? Text(
                      transaction.avatarInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4A4A4A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.typeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA0A0A0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFA0A0A0),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF4A4A4A),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
