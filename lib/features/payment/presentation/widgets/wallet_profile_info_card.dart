import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../entities/wallet_entities.dart';

class WalletProfileInfoCard extends StatelessWidget {
  final WalletUser user;

  const WalletProfileInfoCard({super.key, required this.user});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRow(
            context,
            label: 'Ciro ID', // This should use .tr() in a real app, assuming context provides it
            value: user.ciroId,
            trailingWidget: IconButton(
              icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
              onPressed: () => _copyToClipboard(context, user.ciroId, 'Ciro ID'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildRow(
            context,
            label: 'Status',
            value: user.status == WalletUserStatus.verified ? 'Verified' : 'Pending',
            valueColor: user.status == WalletUserStatus.verified
                ? AppColors.primary
                : const Color(0xFFF57C00),
            trailingWidget: user.status == WalletUserStatus.verified
                ? const Icon(Icons.verified, color: AppColors.primary, size: 20)
                : null,
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildRow(context, label: 'Registration Date', value: user.registrationDate),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildRow(context, label: 'Last Seen', value: user.lastSeen),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildRow(
            context,
            label: 'Country',
            value: user.country,
            // Assuming asset exists, otherwise use a placeholder widget
            trailingWidget: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.asset(
                user.countryFlagAsset,
                width: 32,
                height: 20,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 20,
                  color: Colors.grey[300],
                ),
              ),
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildRow(
            context,
            label: 'Associated Bank',
            value: user.associatedBank,
            trailingWidget: IconButton(
              icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
              onPressed: () => _copyToClipboard(context, user.associatedBank, 'Bank Name'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required String value,
    Color valueColor = const Color(0xFF1A1A1A),
    Widget? trailingWidget,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Color(0xFF8A8A8A),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: 8),
              trailingWidget,
            ],
          ],
        ),
      ],
    );
  }
}
