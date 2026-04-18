import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/message.dart';

class MessageBubbleWidget extends StatelessWidget {
  final Message message;
  final String currentUserId;

  const MessageBubbleWidget({
    Key? key,
    required this.message,
    required this.currentUserId,
  }) : super(key: key);

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.pending:
        return Icon(Icons.access_time, size: 14.resW, color: AppColors.textSecondary);
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14.resW, color: AppColors.textSecondary);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14.resW, color: AppColors.textSecondary);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14.resW, color: Colors.blue);
      default:
        return SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine right-align vs left-align logic
    final isMine = message.senderId == currentUserId;
    
    // Bubble colors based on mockup
    final bgColor = isMine ? AppColors.surface : const Color(0xFFDFFAC4); // Light green for incoming
    final radius = Radius.circular(16.resR);

    // Format HH:mm from DateTime
    final formattedTime = "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}";

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 4.resH),
        padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: isMine ? radius : Radius.zero, // Sharp incoming
            topRight: radius,
            bottomLeft: radius,
            bottomRight: isMine ? Radius.zero : radius, // Sharp outgoing
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2.resR,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTypography.body1.copyWith(color: Colors.black),
            ),
            SizedBox(height: 4.resH),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedTime,
                  style: AppTypography.caption.copyWith(fontSize: 10.resSp, color: AppColors.textSecondary),
                ),
                if (isMine) ...[
                  SizedBox(width: 4.resW),
                  _buildStatusIcon(),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}
