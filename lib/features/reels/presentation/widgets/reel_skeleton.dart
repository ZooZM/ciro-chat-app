import 'package:flutter/material.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';

/// Reel-shaped shimmer skeleton — mirrors `ReelPage`'s layout (creator
/// header + description bottom-left, action column bottom-right) so a
/// loading reel never shows a blank screen or a generic spinner. Used for
/// the deep-linked reel fetch (FR-041) and the main feed's very first load.
class ReelSkeleton extends StatelessWidget {
  const ReelSkeleton({super.key});

  static const _base = Color(0xFF3A3A3A);
  static const _highlight = Color(0xFF5C5C5C);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Shimmer(
        baseColor: _base,
        highlightColor: _highlight,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              right: 88,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Row(
                    children: [
                      SkeletonBox.circle(size: 36, color: _base),
                      SizedBox(width: 8),
                      SkeletonBox(width: 120, height: 14, color: _base),
                    ],
                  ),
                  SizedBox(height: 12),
                  SkeletonBox(width: 220, height: 12, color: _base),
                  SizedBox(height: 6),
                  SkeletonBox(width: 160, height: 12, color: _base),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 4; i++) ...const [
                    SkeletonBox.circle(size: 30, color: _base),
                    SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
