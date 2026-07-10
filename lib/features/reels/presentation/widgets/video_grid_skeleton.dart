import 'package:flutter/material.dart';

/// Skeleton for the 3-column video-thumbnail grid shared by the Creator
/// Profile screen, its Liked/Saved tabs, and Search's video results
/// (FR-025, FR-050/051, FR-057). Not shimmer-wrapped itself — nest it inside
/// a single ancestor [Shimmer] so multi-section skeletons sweep as one.
class VideoGridSkeleton extends StatelessWidget {
  const VideoGridSkeleton({
    super.key,
    this.itemCount = 9,
    this.color = const Color(0xFFBDBDBD),
  });

  final int itemCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => ColoredBox(color: color),
    );
  }
}
