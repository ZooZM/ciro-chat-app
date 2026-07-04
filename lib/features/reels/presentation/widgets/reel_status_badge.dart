import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_status.dart';

/// v3 (FR-065): Processing/Removed overlay for the owner's own grid and
/// reel view. Renders nothing for [ReelStatus.published] — non-self grids
/// only ever contain published items, so this is a harmless no-op there.
/// `const`-friendly leaf: never rebuilds with playback (constitution I/II).
class ReelStatusBadge extends StatelessWidget {
  const ReelStatusBadge({super.key, required this.status});

  final ReelStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == ReelStatus.published) return const SizedBox.shrink();
    final isProcessing = status == ReelStatus.pendingModeration;
    return Positioned(
      left: 4,
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: (isProcessing ? Colors.black : Colors.red.shade900).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isProcessing ? Icons.hourglass_top : Icons.block,
              size: 11,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                (isProcessing ? 'reels.status_processing' : 'reels.status_removed').tr(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
