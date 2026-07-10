import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'video_grid_skeleton.dart';

/// Mirrors the search results layout — a handful of user rows (avatar +
/// name/username, matching `_UserTile`) followed by the video grid (FR-057)
/// — so a search shows the shape of results while it's still loading.
class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({super.key});

  static const _base = AppColors.surfaceVariant;
  static const _highlight = AppColors.surface;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      baseColor: _base,
      highlightColor: _highlight,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) const _UserRowSkeleton(),
          const VideoGridSkeleton(itemCount: 6, color: _base),
        ],
      ),
    );
  }
}

class _UserRowSkeleton extends StatelessWidget {
  const _UserRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SkeletonBox.circle(size: 40, color: SearchResultsSkeleton._base),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBox(width: 120, height: 14, color: SearchResultsSkeleton._base),
              SizedBox(height: 6),
              SkeletonBox(width: 80, height: 11, color: SearchResultsSkeleton._base),
            ],
          ),
        ],
      ),
    );
  }
}
