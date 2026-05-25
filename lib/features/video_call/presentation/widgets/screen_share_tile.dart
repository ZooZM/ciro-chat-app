import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Receive-side screen-share tile (T024 / FR-004).
///
/// All data flows in via constructor — no getIt calls inside this widget
/// (Constitution II widget purity). Track resolution lives in the parent screen.
class ScreenShareTile extends StatelessWidget {
  final VideoTrack? videoTrack;
  final String participantName;
  final bool hasAudio;
  final bool isMutedLocally;
  final VoidCallback onMuteToggle;

  const ScreenShareTile({
    super.key,
    required this.videoTrack,
    required this.participantName,
    required this.hasAudio,
    required this.isMutedLocally,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Screen content (or connecting placeholder)
          videoTrack != null
              ? VideoTrackRenderer(videoTrack!)
              : const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white54),
                      SizedBox(height: 8),
                      Text(
                        'Connecting…',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

          // Label: "{name} • Screen"
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_share_outlined, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$participantName • Screen',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Per-receiver audio mute toggle (FR-013b) — only shown when share includes audio
          if (hasAudio)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onMuteToggle,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMutedLocally ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
