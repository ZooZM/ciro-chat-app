import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Lightweight spinner shown only while the video at this position is
/// buffering. Listens to `media_kit`'s own [Player.stream.buffering]
/// directly rather than a bloc — this is deliberately the most granular
/// possible rebuild scope (FR-016).
class BufferingIndicator extends StatelessWidget {
  const BufferingIndicator({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: controller.player.stream.buffering,
      initialData: true,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
          ),
        );
      },
    );
  }
}
