import 'package:flutter/material.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';

/// Mirrors the trimmer screen's video-preview + trim-slider layout
/// (FR-060a) while `video_editor` is still initializing the source clip.
class ReelTrimmerSkeleton extends StatelessWidget {
  const ReelTrimmerSkeleton({super.key});

  static const _base = Color(0xFF3A3A3A);
  static const _highlight = Color(0xFF5C5C5C);

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      baseColor: _base,
      highlightColor: _highlight,
      child: Column(
        children: [
          const Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ColoredBox(color: _base),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SkeletonBox(width: 160, height: 12, color: _base),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SkeletonBox(width: double.infinity, height: 48, borderRadius: 4, color: _base),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
