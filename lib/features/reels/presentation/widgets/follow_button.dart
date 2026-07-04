import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

/// Follow/Following toggle keyed by **creator** id — shared by both the
/// video overlay and the Creator Profile screen so they stay consistent
/// (FR-028/FR-030). Hidden entirely when [isSelf] is true (FR-031).
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.creatorId, required this.isSelf});

  final String creatorId;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    if (isSelf) return const SizedBox.shrink();
    final cubit = getIt<ReelsInteractionCubit>();
    return BlocSelector<ReelsInteractionCubit, ReelsInteractionState, FollowEntry?>(
      bloc: cubit,
      selector: (state) => state.follows[creatorId],
      builder: (context, entry) {
        final following = entry?.following ?? false;
        return SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: () => cubit.toggleFollow(creatorId),
            style: OutlinedButton.styleFrom(
              backgroundColor: following ? Colors.transparent : Colors.white,
              foregroundColor: following ? Colors.white : Colors.black,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              following ? 'reels.following'.tr() : 'reels.follow'.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
