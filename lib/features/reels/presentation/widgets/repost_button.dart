import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';

/// v4 (FR-073): primary action-column Repost toggle — occupies the slot
/// formerly held by [SaveButton] (Save relocated to the 3-dots sheet,
/// FR-068). Hidden on the viewer's own reels (no self-repost). Selects
/// exactly one map entry so tapping only rebuilds this ~48px icon, never
/// the playing video behind it (FR-014).
class RepostButton extends StatefulWidget {
  const RepostButton({super.key, required this.reelId, required this.creatorId});

  final String reelId;
  final String creatorId;

  @override
  State<RepostButton> createState() => _RepostButtonState();
}

class _RepostButtonState extends State<RepostButton> {
  bool _isOwnReel = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    final userId = await getIt<AuthLocalDataSource>().getUserId();
    if (!mounted) return;
    setState(() => _isOwnReel = userId != null && userId == widget.creatorId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isOwnReel) return const SizedBox.shrink();
    final cubit = getIt<ReelsInteractionCubit>();
    return BlocSelector<ReelsInteractionCubit, ReelsInteractionState, bool>(
      bloc: cubit,
      selector: (state) => state.reposts[widget.reelId] ?? false,
      builder: (context, reposted) {
        return GestureDetector(
          onTap: () => cubit.toggleRepost(widget.reelId),
          child: AnimatedScale(
            scale: reposted ? 1.15 : 1.0,
            duration: AppConstants.durationFast,
            curve: Curves.easeOutBack,
            child: SvgPicture.asset(
              'assets/icons/reels/repost.svg',
              width: 34,
              height: 34,
              colorFilter: ColorFilter.mode(
                reposted ? AppColors.primary : Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        );
      },
    );
  }
}
