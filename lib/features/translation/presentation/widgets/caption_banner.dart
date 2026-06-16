import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../domain/entities/caption.dart';

/// FR-010 fallback: a bottom banner showing `"{speakerName}: {text}"` for the
/// most recently active caption, so translated speech is still visible when
/// the speaking participant's tile is off-screen or has no camera.
class CaptionBanner extends StatelessWidget {
  final ValueListenable<Caption?> caption;
  final List<RemoteParticipant> participants;

  const CaptionBanner({super.key, required this.caption, required this.participants});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Caption?>(
      valueListenable: caption,
      builder: (context, value, _) {
        if (value == null || value.text.isEmpty) return const SizedBox.shrink();

        RemoteParticipant? speaker;
        for (final p in participants) {
          if (p.identity == value.speakerId) {
            speaker = p;
            break;
          }
        }
        final speakerName = speaker == null
            ? value.speakerId
            : (speaker.name.isNotEmpty ? speaker.name : speaker.identity);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$speakerName: ${value.text}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        );
      },
    );
  }
}
