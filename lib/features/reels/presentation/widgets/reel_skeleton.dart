import 'package:flutter/material.dart';

/// Shimmer-style placeholder shown while a deep-linked reel is being fetched
/// (FR-041) — replaces the plain spinner so opening a shared link never
/// shows a blank screen.
class ReelSkeleton extends StatefulWidget {
  const ReelSkeleton({super.key});

  @override
  State<ReelSkeleton> createState() => _ReelSkeletonState();
}

class _ReelSkeletonState extends State<ReelSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = 0.15 + (_controller.value * 0.15);
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.white.withValues(alpha: opacity)),
              ),
              const Center(
                child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
              ),
            ],
          );
        },
      ),
    );
  }
}
