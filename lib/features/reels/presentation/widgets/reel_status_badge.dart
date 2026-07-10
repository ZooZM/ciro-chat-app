import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_status.dart';

/// v3 (FR-065)/v4 (FR-072): Processing/Under review/Removed overlay for the
/// owner's own grid and reel view. Renders nothing for [ReelStatus.published]
/// — non-self grids only ever contain published items, so this is a
/// harmless no-op there. `const`-friendly leaf: never rebuilds with
/// playback (constitution I/II).
class ReelStatusBadge extends StatelessWidget {
  const ReelStatusBadge({super.key, required this.status});

  final ReelStatus status;

  @override
  Widget build(BuildContext context) {
    final visuals = _visualsFor(status);
    if (visuals == null) return const SizedBox.shrink();
    return Positioned(
      left: 4,
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXs + 2,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: visuals.color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visuals.icon, size: 11, color: Colors.white),
            const SizedBox(width: AppConstants.spacingXs),
            Flexible(
              child: Text(
                visuals.labelKey.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusVisuals? _visualsFor(ReelStatus status) {
    switch (status) {
      case ReelStatus.published:
        return null;
      case ReelStatus.pendingModeration:
        return const _StatusVisuals(
          AppColors.textPrimary,
          Icons.hourglass_top,
          'reels.status_processing',
        );
      case ReelStatus.hidden:
        return const _StatusVisuals(
          AppColors.warning,
          Icons.visibility_off,
          'reels.status_under_review',
        );
      case ReelStatus.rejected:
        return const _StatusVisuals(
          AppColors.error,
          Icons.block,
          'reels.status_removed',
        );
    }
  }
}

class _StatusVisuals {
  const _StatusVisuals(this.color, this.icon, this.labelKey);

  final Color color;
  final IconData icon;
  final String labelKey;
}
