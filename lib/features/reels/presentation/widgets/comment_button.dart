import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

/// Selects exactly one map entry (`commentCounts[reelId]`) — a new comment
/// updates only this counter, never the playing video (FR-014, FR-020).
class CommentButton extends StatelessWidget {
  const CommentButton({super.key, required this.reelId, required this.onTap});

  final String reelId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ReelsInteractionCubit, ReelsInteractionState, int>(
      bloc: getIt<ReelsInteractionCubit>(),
      selector: (state) => state.commentCounts[reelId] ?? 0,
      builder: (context, count) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onTap,
              child: SvgPicture.asset(
                'assets/icons/reels/comment.svg',
                width: 34,
                height: 34,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormat.compact().format(count),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}
