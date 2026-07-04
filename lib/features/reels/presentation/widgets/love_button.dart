import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

/// Selects exactly one map entry (`likes[reelId]`) so tapping Love rebuilds
/// only this ~48px icon — never the playing video behind it (FR-014, FR-018).
class LoveButton extends StatelessWidget {
  const LoveButton({super.key, required this.reelId});

  final String reelId;

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<ReelsInteractionCubit>();
    return BlocSelector<ReelsInteractionCubit, ReelsInteractionState, LikeEntry?>(
      bloc: cubit,
      selector: (state) => state.likes[reelId],
      builder: (context, entry) {
        final liked = entry?.liked ?? false;
        final count = entry?.count ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => cubit.toggleLike(reelId),
              child: AnimatedScale(
                scale: liked ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                child: Icon(
                  liked ? CupertinoIcons.heart_solid : CupertinoIcons.heart,
                  color: liked ? Colors.redAccent : Colors.white,
                  size: 30,
                  shadows: const [Shadow(color: Colors.white, blurRadius: 8)],
                ),
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
