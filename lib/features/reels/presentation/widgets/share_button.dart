import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

/// Selects exactly one map entry (`shareCounts[reelId]`) — recording a share
/// updates only this counter, never the playing video (FR-014, FR-021a).
class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.reelId, required this.onTap});

  final String reelId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ReelsInteractionCubit, ReelsInteractionState, int>(
      bloc: getIt<ReelsInteractionCubit>(),
      selector: (state) => state.shareCounts[reelId] ?? 0,
      builder: (context, count) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onTap,
              child: const Icon(
                CupertinoIcons.paperplane,
                color: Colors.white,
                size: 30,
                shadows: [Shadow(color: Colors.white, blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormat.compact().format(count),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }
}
