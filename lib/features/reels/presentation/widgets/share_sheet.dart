import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/reels_constants.dart';

/// Custom two-row in-app share sheet (FR-021): a horizontally scrollable
/// row of recent chats that sends the reel as a rich-preview chat message,
/// and a bottom row with Copy Link + "Share via…" (native OS sheet). Renders
/// instantly over the still-playing video (FR-021b) — no network calls block
/// the first frame; the recent-chats row streams in from local data.
Future<void> showReelShareSheet(BuildContext context, Reel reel) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ReelShareSheet(reel: reel),
  );
}

class ReelShareSheet extends StatelessWidget {
  const ReelShareSheet({super.key, required this.reel});

  final Reel reel;

  void _onShared() {
    getIt<ReelsInteractionCubit>().recordShare(reel.id);
  }

  Future<void> _sendToChat(BuildContext context, ChatSession room) async {
    await context.read<ChatCubit>().sendReelShare(
          room,
          reelId: reel.id,
          thumbnailUrl: reel.thumbnailUrl,
          creatorName: reel.creator.name,
          deepLink: reel.deepLinkUrl,
        );
    _onShared();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reels.share_sent'.tr())),
      );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: reel.deepLinkUrl));
    _onShared();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reels.share_link_copied'.tr())),
      );
    }
  }

  Future<void> _shareVia(BuildContext context) async {
    // iPadOS anchors the native share sheet as a popover and crashes with a
    // PlatformException if sharePositionOrigin isn't a real (non-zero) rect
    // — capture the tapped button's on-screen position before it unmounts.
    final renderBox = context.findRenderObject() as RenderBox?;
    final origin = renderBox != null && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;

    // Untracked (FR-021a) — dismiss the sheet first so the native sheet
    // isn't stacked on top of ours.
    Navigator.of(context).pop();
    await SharePlus.instance.share(
      ShareParams(uri: Uri.parse(reel.deepLinkUrl), sharePositionOrigin: origin),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('reels.share_title'.tr(), style: AppTypography.subtitle1),
              const SizedBox(height: 12),
              Text(
                'reels.share_recent_chats'.tr(),
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 88,
                child: StreamBuilder<List<ChatSession>>(
                  stream: context.read<ChatCubit>().recentChatsStream,
                  builder: (context, snapshot) {
                    final chats = (snapshot.data ?? const [])
                        .take(ReelsConstants.recentChatsLimit)
                        .toList();
                    if (chats.isEmpty) {
                      return Center(
                        child: Text(
                          'reels.share_no_chats'.tr(),
                          style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final room = chats[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GestureDetector(
                            onTap: () => _sendToChat(context, room),
                            child: SizedBox(
                              width: 64,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppColors.surfaceVariant,
                                    backgroundImage: room.avatarUrl.isEmpty
                                        ? null
                                        : CachedNetworkImageProvider(room.avatarUrl),
                                    child: room.avatarUrl.isEmpty
                                        ? const Icon(Icons.person, color: AppColors.textSecondary)
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    room.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 24, color: AppColors.divider),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ShareAction(
                    icon: Icons.link,
                    label: 'reels.share_copy_link'.tr(),
                    onTap: () => _copyLink(context),
                  ),
                  const SizedBox(width: 24),
                  _ShareAction(
                    icon: Icons.ios_share,
                    label: 'reels.share_via'.tr(),
                    onTap: () => _shareVia(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryLight,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
