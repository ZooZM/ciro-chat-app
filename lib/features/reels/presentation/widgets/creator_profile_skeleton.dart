import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';
import 'video_grid_skeleton.dart';

/// Mirrors the Creator Profile screen's header (avatar, name, bio, follow
/// button, stats) plus its 3-column video grid (FR-023–027) so the
/// profile's initial load shows the shape of the real content instead of a
/// bare spinner.
class CreatorProfileSkeleton extends StatelessWidget {
  const CreatorProfileSkeleton({super.key});

  static const _base = AppColors.surfaceVariant;
  static const _highlight = AppColors.surface;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      baseColor: _base,
      highlightColor: _highlight,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  SkeletonBox.circle(size: 88, color: _base),
                  SizedBox(height: 12),
                  SkeletonBox(width: 140, height: 16, color: _base),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 12, color: _base),
                  SizedBox(height: 16),
                  SkeletonBox(width: 120, height: 36, borderRadius: 18, color: _base),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatSkeleton(),
                      SizedBox(width: 32),
                      _StatSkeleton(),
                      SizedBox(width: 32),
                      _StatSkeleton(),
                    ],
                  ),
                ],
              ),
            ),
            const VideoGridSkeleton(color: _base),
          ],
        ),
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(width: 36, height: 18, color: CreatorProfileSkeleton._base),
        SizedBox(height: 6),
        SkeletonBox(width: 56, height: 10, color: CreatorProfileSkeleton._base),
      ],
    );
  }
}
