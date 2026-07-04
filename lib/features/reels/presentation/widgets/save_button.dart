import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

/// Selects exactly one map entry (`saves[reelId]`) so tapping Save rebuilds
/// only this ~48px icon — never the playing video behind it (FR-014, FR-049).
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.reelId});

  final String reelId;

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<ReelsInteractionCubit>();
    return BlocSelector<ReelsInteractionCubit, ReelsInteractionState, bool>(
      bloc: cubit,
      selector: (state) => state.saves[reelId] ?? false,
      builder: (context, saved) {
        return GestureDetector(
          onTap: () => cubit.toggleSave(reelId),
          child: AnimatedScale(
            scale: saved ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
              color: saved ? Colors.amberAccent : Colors.white,
              size: 32,
              shadows: const [Shadow(color: Colors.white, blurRadius: 8)],
            ),
          ),
        );
      },
    );
  }
}
