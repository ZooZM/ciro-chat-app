import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:badges/badges.dart' as pk_badges;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/message.dart';

class ChatTileWidget extends StatelessWidget {
  final ChatSession chat;
  final VoidCallback onTap;
  final String currentUserId;
  final bool isTyping;

  const ChatTileWidget({
    Key? key,
    required this.chat,
    required this.onTap,
    required this.currentUserId,
    this.isTyping = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16.resW,
        vertical: 4.resH,
      ),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28.resR,
            backgroundColor: AppColors.divider,
            backgroundImage: chat.avatarUrl.isNotEmpty 
                ? CachedNetworkImageProvider(chat.avatarUrl) 
                : null,
            child: chat.avatarUrl.isEmpty
                ? Icon(
                    chat.type == ChatRoomType.GROUP ? Icons.group : Icons.person,
                    color: Colors.white,
                    size: 32.resR,
                  )
                : null,
          ),
          if (chat.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14.resW,
                height: 14.resW,
                decoration: BoxDecoration(
                  color: AppColors.info,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2.resW),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chat.name,
        style: AppTypography.subtitle1.copyWith(
          fontWeight: chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
          color: Colors.black, // Dark text from mockups
        ),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chat.lastMessageSenderId == currentUserId &&
              chat.lastMessageSenderId.isNotEmpty) ...[
            Icon(
              chat.lastMessageStatus == MessageStatus.pending
                  ? Icons.access_time
                  : chat.lastMessageStatus == MessageStatus.sent
                  ? Icons.check
                  : Icons.done_all,
              size: 16.resW,
              color: chat.lastMessageStatus == MessageStatus.read
                  ? AppColors.info
                  : AppColors.textSecondary,
            ),
            SizedBox(width: 4.resW),
          ],
          Expanded(
            child: Text(
              isTyping ? 'typing...' : chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body2.copyWith(
                color: isTyping 
                    ? AppColors.primary 
                    : (chat.unreadCount > 0
                        ? Colors.black87
                        : AppColors.textSecondary),
                fontStyle: isTyping ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('h:mm a').format(chat.timestamp),
            style: AppTypography.caption.copyWith(
              color: chat.unreadCount > 0
                  ? Colors.black
                  : AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 6.resH),
          if (chat.unreadCount > 0)
            pk_badges.Badge(
              badgeContent: Text(
                chat.unreadCount.toString(),
                style: TextStyle(color: Colors.white, fontSize: 10.resSp),
              ),
              badgeStyle: pk_badges.BadgeStyle(
                badgeColor: Colors.green, // Enforced WhatsApp aesthetic
                padding: EdgeInsets.all(5.resW),
              ),
            )
          else
            SizedBox(height: 16.resH),
        ],
      ),
    );
  }
}
