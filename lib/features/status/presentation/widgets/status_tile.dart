import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_avatar_preview.dart';
import 'package:flutter/material.dart';

class StatusTile extends StatelessWidget {
  final StatusEntity status;
  final VoidCallback onTap;

  const StatusTile({
    Key? key,
    required this.status,
    required this.onTap,
  }) : super(key: key);

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (now.day == timestamp.day && now.month == timestamp.month && now.year == timestamp.year) {
      final hour = timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final amPm = timestamp.hour >= 12 ? 'PM' : 'AM';
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute $amPm';
    } else {
      return 'Yesterday';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 4.resH),
      leading: Container(
        width: 56.resW,
        height: 56.resW,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: status.isViewed ? Colors.grey : AppColors.primary,
            width: 2.resW,
          ),
        ),
        padding: EdgeInsets.all(2.resW),
        child: StatusAvatarPreview(status: status, size: 52.resW),
      ),
      title: Text(
        status.authorName,
        style: AppTypography.subtitle1.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _formatTimestamp(status.timestamp),
        style: AppTypography.body2.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
