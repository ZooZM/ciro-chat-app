import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';

/// Mirrors `_CommentTile`'s layout (avatar + author line + text line —
/// FR-019) so the comments sheet shows the shape of a comment list while
/// it's still loading, instead of a bare spinner.
class CommentsSkeleton extends StatelessWidget {
  const CommentsSkeleton({super.key});

  static const _base = AppColors.surfaceVariant;
  static const _highlight = AppColors.surface;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      baseColor: _base,
      highlightColor: _highlight,
      child: Column(
        children: [for (var i = 0; i < 5; i++) const _CommentRowSkeleton()],
      ),
    );
  }
}

class _CommentRowSkeleton extends StatelessWidget {
  const _CommentRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SkeletonBox.circle(size: 36, color: CommentsSkeleton._base),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(width: 100, height: 12, color: CommentsSkeleton._base),
                SizedBox(height: 6),
                SkeletonBox(width: double.infinity, height: 12, color: CommentsSkeleton._base),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
