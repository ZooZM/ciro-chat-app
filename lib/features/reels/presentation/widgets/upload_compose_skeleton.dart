import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'shimmer.dart';
import 'skeleton_box.dart';

/// Mirrors the upload compose screen's picked-video layout (9:16 thumbnail,
/// description field, submit button — FR-060) while the source video is
/// still being probed/thumbnailed, instead of a bare spinner.
class UploadComposeSkeleton extends StatelessWidget {
  const UploadComposeSkeleton({super.key});

  static const _base = AppColors.surfaceVariant;
  static const _highlight = AppColors.surface;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      baseColor: _base,
      highlightColor: _highlight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const ColoredBox(color: _base),
              ),
            ),
            const SizedBox(height: 16),
            const SkeletonBox(width: double.infinity, height: 88, borderRadius: 4, color: _base),
            const SizedBox(height: 8),
            const SkeletonBox(width: 140, height: 44, borderRadius: 22, color: _base),
          ],
        ),
      ),
    );
  }
}
