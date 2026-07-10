import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_reposter.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reposters_sheet.dart';

/// v4 (FR-076/FR-077) + v6: the repost attribution pill above the creator
/// name — a solid light chip (TikTok-style), legible over any video.
///
/// - **1 relevant reposter** → single avatar + "[name] reposted" / "You reposted".
/// - **>1 relevant reposters** (people the viewer follows, ∪ self) → a stacked
///   avatar cluster + "N reposted".
/// - an **optimistic** self-repost (no fetched attribution yet) still shows
///   "You reposted" immediately via the viewer's live repost state, hiding on
///   un-repost.
///
/// Tappable (v6 — supersedes FR-077's non-tappable rule): opens the reposters
/// bottom sheet listing everyone who reposted the video.
class RepostBadge extends StatefulWidget {
  const RepostBadge({
    super.key,
    required this.reelId,
    required this.repostedBy,
    this.repostersCount = 0,
    this.topReposters = const [],
    this.viewerReposted = false,
  });

  final String reelId;
  final ReelReposter? repostedBy;

  /// Count of viewer-relevant reposters at fetch time (people the viewer
  /// follows, ∪ the viewer). >1 → "N reposted" with an avatar stack.
  final int repostersCount;

  /// Up to 3 reposter avatars for the stack (most-recent-first).
  final List<ReelReposter> topReposters;

  /// Whether the viewer had reposted at fetch time — combined with the live
  /// optimistic state so the count changes the instant they repost/un-repost.
  final bool viewerReposted;

  @override
  State<RepostBadge> createState() => _RepostBadgeState();
}

class _RepostBadgeState extends State<RepostBadge> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final id = await getIt<AuthLocalDataSource>().getUserId();
    if (!mounted) return;
    setState(() => _currentUserId = id);
  }

  /// The reposter avatars to show in the multi stack, reflecting the viewer's
  /// live repost state (prepend the viewer on an optimistic repost, drop them
  /// on an optimistic un-repost).
  List<ReelReposter> _effectiveTop(bool live) {
    var top = widget.topReposters;
    if (live && !widget.viewerReposted) {
      top = [
        ReelReposter(
          id: _currentUserId ?? 'you',
          username: '',
          name: 'You',
          avatarUrl: '',
        ),
        ...top.where((r) => r.id != _currentUserId),
      ];
    } else if (!live && widget.viewerReposted) {
      top = top.where((r) => r.id != _currentUserId).toList();
    }
    return top.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ReelsInteractionCubit, ReelsInteractionState, bool>(
      bloc: getIt<ReelsInteractionCubit>(),
      selector: (state) => state.reposts[widget.reelId] ?? false,
      builder: (context, live) {
        final reposter = widget.repostedBy;
        // Whenever there's an attribution, the count is at least 1 (the backend
        // sets both together; this fallback also covers older payloads).
        final baseCount =
            widget.repostersCount > 0 ? widget.repostersCount : (reposter != null ? 1 : 0);
        // Reposters other than the viewer, then re-add the viewer per the LIVE
        // optimistic state — so a repost bumps "1 → 2 reposted" instantly.
        final others = baseCount - (widget.viewerReposted ? 1 : 0);
        final effectiveCount = (others < 0 ? 0 : others) + (live ? 1 : 0);
        if (effectiveCount <= 0) return const SizedBox.shrink();

        final isMulti = effectiveCount > 1;
        final viewerIsSole = effectiveCount == 1 && live && others <= 0;
        final isSelfAttribution = reposter != null &&
            _currentUserId != null &&
            reposter.id == _currentUserId;

        final Widget leading;
        final String label;
        if (isMulti) {
          leading = _AvatarStack(reposters: _effectiveTop(live));
          label = 'reels.reposted_count'.tr(namedArgs: {'count': '$effectiveCount'});
        } else if (viewerIsSole || isSelfAttribution) {
          leading = const _Avatar(avatarUrl: '');
          label = 'reels.you_reposted'.tr();
        } else {
          leading = _Avatar(avatarUrl: reposter?.avatarUrl ?? '');
          label = 'reels.reposted_by'.tr(namedArgs: {'name': reposter?.name ?? ''});
        }

        final pill = Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusPill),
              boxShadow: AppConstants.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      label,
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        // v6: the sheet opens ONLY when more than one person reposted; a single
        // reposter badge is informational and lets taps fall through to the
        // video's pause/resume (FR-015).
        if (!isMulti) return pill;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showRepostersSheet(context, widget.reelId),
          child: pill,
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, this.radius = 14});

  final String avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.divider,
      backgroundImage: avatarUrl.isEmpty ? null : CachedNetworkImageProvider(avatarUrl),
      child: avatarUrl.isEmpty
          ? Icon(Icons.person, size: radius * 1.1, color: AppColors.textSecondary)
          : null,
    );
  }
}

/// Overlapping avatar cluster for the multi-reposter badge (up to 3),
/// TikTok-style — each avatar ringed in the pill colour so they read as
/// distinct circles even as placeholders.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.reposters});

  final List<ReelReposter> reposters;

  static const double _radius = 13;
  static const double _step = 18; // horizontal offset between avatars

  @override
  Widget build(BuildContext context) {
    final shown = reposters.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    const double ringed = (_radius + 2) * 2; // avatar + 2px ring, diameter
    final width = ringed + (shown.length - 1) * _step;
    return SizedBox(
      width: width,
      height: ringed,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              // Later avatars sit on top, offset to the right.
              left: i * _step,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.surface, width: 2),
                  ),
                ),
                child: _Avatar(avatarUrl: shown[i].avatarUrl, radius: _radius),
              ),
            ),
        ],
      ),
    );
  }
}
