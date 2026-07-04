import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_mention.dart';

/// Reel description with tappable `#hashtag` and `@mention` spans
/// (FR-047a): a hashtag opens the hashtag feed, a mention opens that user's
/// profile. Collapses to 2 lines with a "more" toggle. Owns
/// [TapGestureRecognizer]s, so this must stay a leaf `StatefulWidget` that
/// disposes them (constitution V) — it never wraps or rebuilds the video.
class ReelDescription extends StatefulWidget {
  const ReelDescription({
    super.key,
    required this.description,
    required this.mentions,
  });

  final String description;
  final List<ReelMention> mentions;

  @override
  State<ReelDescription> createState() => _ReelDescriptionState();
}

class _ReelDescriptionState extends State<ReelDescription> {
  final List<TapGestureRecognizer> _recognizers = [];
  bool _expanded = false;

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _newRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.description.isEmpty) return const SizedBox.shrink();

    final mentionByUsername = {
      for (final mention in widget.mentions) mention.username.toLowerCase(): mention,
    };
    final tokenPattern = RegExp(r'(#[a-zA-Z0-9_]+|@[a-zA-Z0-9_.]+)');
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in tokenPattern.allMatches(widget.description)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: widget.description.substring(lastEnd, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('#')) {
        final tag = token.substring(1).toLowerCase();
        spans.add(
          TextSpan(
            text: token,
            style: const TextStyle(fontWeight: FontWeight.w700),
            recognizer: _newRecognizer(() => context.push('/reels/hashtag/$tag')),
          ),
        );
      } else {
        final username = token.substring(1).toLowerCase();
        final mention = mentionByUsername[username];
        if (mention != null) {
          spans.add(
            TextSpan(
              text: token,
              style: const TextStyle(fontWeight: FontWeight.w700),
              recognizer: _newRecognizer(() => context.push('/reels/profile/${mention.userId}')),
            ),
          );
        } else {
          // Unresolved mention — plain text (FR-047).
          spans.add(TextSpan(text: token));
        }
      }
      lastEnd = match.end;
    }
    if (lastEnd < widget.description.length) {
      spans.add(TextSpan(text: widget.description.substring(lastEnd)));
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: RichText(
        maxLines: _expanded ? null : 2,
        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          children: spans,
        ),
      ),
    );
  }
}
