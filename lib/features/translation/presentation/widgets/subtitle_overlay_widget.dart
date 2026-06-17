import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../domain/entities/caption.dart';

/// Scrollable transcript strip overlaid at the bottom of the participant grid
/// (FR-F02/FR-F04/FR-F05). Bound to [TranslationCubit.transcriptList] via
/// [ValueListenableBuilder] — only this widget rebuilds on caption updates.
///
/// Interim captions appear as italic placeholder text that updates in-place;
/// final captions are locked and the next utterance opens a new row. The list
/// auto-scrolls to the bottom on every update so the user always sees the
/// latest text, and hides itself entirely when the transcript is empty.
class SubtitleOverlayWidget extends StatefulWidget {
  final ValueListenable<List<Caption>> transcript;
  final List<RemoteParticipant> participants;

  const SubtitleOverlayWidget({
    super.key,
    required this.transcript,
    required this.participants,
  });

  @override
  State<SubtitleOverlayWidget> createState() => _SubtitleOverlayWidgetState();
}

class _SubtitleOverlayWidgetState extends State<SubtitleOverlayWidget> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _resolveName(String speakerId) {
    for (final p in widget.participants) {
      if (p.identity == speakerId) {
        return p.name.isNotEmpty ? p.name : p.identity;
      }
    }
    return speakerId;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Caption>>(
      valueListenable: widget.transcript,
      builder: (context, captions, _) {
        if (captions.isEmpty) return const SizedBox.shrink();

        _scrollToBottom();

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.30,
          ),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xA8000000),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              itemCount: captions.length,
              itemBuilder: (context, index) {
                final cap = captions[index];
                final isInterim = cap.type == CaptionType.interim;
                // Show speaker label only when the speaker changes — chat style.
                final showLabel = index == 0 ||
                    captions[index - 1].speakerId != cap.speakerId;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < captions.length - 1 ? 8 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showLabel) ...[
                        Text(
                          _resolveName(cap.speakerId),
                          style: const TextStyle(
                            color: Color(0xFF81D4FA),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        cap.text,
                        style: TextStyle(
                          color: isInterim ? Colors.white70 : Colors.white,
                          fontStyle:
                              isInterim ? FontStyle.italic : FontStyle.normal,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
