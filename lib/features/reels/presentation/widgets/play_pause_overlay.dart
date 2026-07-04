import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Tap-to-pause/resume for the video underneath (FR-015). Listens to
/// `media_kit`'s own `player.stream.playing` directly — no bloc — so the
/// paused-icon flash never touches feed or interaction state.
class PlayPauseOverlay extends StatelessWidget {
  const PlayPauseOverlay({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => controller.player.playOrPause(),
      child: StreamBuilder<bool>(
        stream: controller.player.stream.playing,
        initialData: true,
        builder: (context, snapshot) {
          final playing = snapshot.data ?? true;
          return AnimatedOpacity(
            opacity: playing ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: const Center(
              child: Icon(Icons.play_arrow, color: Colors.white70, size: 72),
            ),
          );
        },
      ),
    );
  }
}
