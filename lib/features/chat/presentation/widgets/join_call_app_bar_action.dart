import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';

/// FR-038: Pill button shown in group chat AppBar only when a call is active.
/// Hidden when no call is in progress for [roomId].
/// [onJoin] receives the `isVideo` flag of the active call so the caller can
/// join the correct call type without guessing.
class JoinCallAppBarAction extends StatelessWidget {
  const JoinCallAppBarAction({
    super.key,
    required this.roomId,
    required this.onJoin,
  });

  final String roomId;
  final void Function(bool isVideo) onJoin;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatCubit>();
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: cubit.activeCallRoomIds,
      builder: (context, activeRooms, _) {
        final isVideo = activeRooms[roomId];
        if (isVideo == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: ElevatedButton.icon(
            onPressed: () => onJoin(isVideo),
            icon: Icon(isVideo ? Icons.video_call : Icons.phone, size: 18),
            label: const Text('Join'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
