import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../domain/entities/caption.dart';

/// Full-width subtitle strip overlaid at the bottom of the participant grid
/// (FR-004/FR-010). Bound to `TranslationCubit.latestActiveCaption` via
/// [ValueListenableBuilder] — only this widget rebuilds on caption updates
/// (FR-007/FR-015). Hidden when no caption is active.
class SubtitleOverlayWidget extends StatelessWidget {
  final ValueListenable<Caption?> caption;
  final List<RemoteParticipant> participants;

  const SubtitleOverlayWidget({
    super.key,
    required this.caption,
    required this.participants,
  });

  String _resolveName(String speakerId) {
    for (final p in participants) {
      if (p.identity == speakerId) {
        return p.name.isNotEmpty ? p.name : p.identity;
      }
    }
    return speakerId;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Caption?>(
      valueListenable: caption,
      builder: (_, cap, __) {
        if (cap == null || cap.text.isEmpty) return const SizedBox.shrink();

        final isInterim = cap.type == CaptionType.interim;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.30,
          ),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xA8000000), // ~66% black
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _resolveName(cap.speakerId),
                    style: const TextStyle(
                      color: Color(0xFF81D4FA),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cap.text,
                    style: TextStyle(
                      color: isInterim ? Colors.white70 : Colors.white,
                      fontSize: 15,
                      fontStyle:
                          isInterim ? FontStyle.italic : FontStyle.normal,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
