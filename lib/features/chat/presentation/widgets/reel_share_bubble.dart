import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/reels_feed_screen.dart';
import '../../domain/entities/message.dart';

/// Rich preview card for a `reelShare` message (FR-021c): thumbnail, creator
/// name, and a play badge. Tapping it opens the reel in-app (FR-042).
///
/// Uses a raw `Navigator.push` (not go_router's `context.push`) deliberately:
/// `ChatRoomScreen`'s route reconstructs itself from `state.extra` (a
/// `ChatSession`), and go_router's own router comment documents that "any
/// push missing extra" can cause it to rebuild without that payload —
/// showing a blank fallback screen when popping back. A raw Navigator push
/// never touches go_router's route stack/state machine, so it can't trigger
/// that rebuild; go_router and Flutter's Navigator are designed to compose
/// this way for exactly this kind of transient, modal-like navigation.
///
/// Unknown/older clients that don't understand `MessageType.reelShare` fall
/// back to rendering [message.text] (the deep link) as plain text — handled
/// by the caller's switch default, not this widget.
class ReelShareBubble extends StatelessWidget {
  const ReelShareBubble({super.key, required this.message, required this.isMine, required this.footer});

  final Message message;
  final bool isMine;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final reelId = meta['reelId'] as String? ?? '';
    final thumbnailUrl = meta['thumbnailUrl'] as String? ?? '';
    final creatorName = meta['creatorName'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: reelId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReelsFeedScreen(initialReelId: reelId),
                      ),
                    ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.resR),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160.resW,
                    height: 220.resH,
                    child: thumbnailUrl.isEmpty
                        ? Container(color: AppColors.background)
                        : CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: AppColors.background),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                    ),
                    width: 160.resW,
                    height: 220.resH,
                  ),
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 40.resW),
                  if (creatorName.isNotEmpty)
                    Positioned(
                      left: 8.resW,
                      right: 8.resW,
                      bottom: 8.resH,
                      child: Text(
                        creatorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          footer,
        ],
      ),
    );
  }
}
