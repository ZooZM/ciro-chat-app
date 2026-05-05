import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
import '../bloc/chat_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TypingIndicatorWidget
//
// A self-contained widget that rebuilds ONLY when a [TypingUpdate] is emitted
// for the current room. It is intentionally decoupled from the message list
// so that typing events never cause the heavy [ListView.builder] to rebuild.
//
// Usage: drop inside the AppBar subtitle column of [ChatRoomScreen] /
// [GroupChatScreen] instead of a raw [StreamBuilder].
// ─────────────────────────────────────────────────────────────────────────────

class TypingIndicatorWidget extends StatelessWidget {
  /// The room this widget is monitoring.
  final String roomId;

  /// Whether this is a group room (shows "X is typing…" with name prefix).
  final ChatRoomType roomType;

  /// Subtitle to show when nobody is typing (e.g. "online" / "3 participants").
  final String idleSubtitle;

  const TypingIndicatorWidget({
    super.key,
    required this.roomId,
    required this.roomType,
    required this.idleSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      // Only rebuild when a TypingUpdate arrives for this specific room.
      buildWhen: (prev, curr) => curr is TypingUpdate && curr.roomId == roomId,
      builder: (context, state) {
        // Read the current typing set from the cubit's internal map so the
        // first build (before any TypingUpdate is emitted) shows the correct
        // idle subtitle rather than an empty string.
        final cubit = context.read<ChatCubit>();
        final typingUsers = state is TypingUpdate && state.roomId == roomId
            ? state.typingUsers
            : cubit.typingUsersForRoom(roomId);

        if (typingUsers.isNotEmpty) {
          final label = roomType == ChatRoomType.GROUP
              ? '${typingUsers.first} is typing…'
              : 'typing…';
          return Text(
            label,
            style: AppTypography.body2.copyWith(
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return Text(
          idleSubtitle,
          style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
