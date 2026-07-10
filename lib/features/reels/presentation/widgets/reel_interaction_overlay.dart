import 'package:flutter/material.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'comment_button.dart';
import 'comments_sheet.dart';
import 'love_button.dart';
import 'reel_more_button.dart';
import 'repost_button.dart';
import 'share_button.dart';
import 'share_sheet.dart';

/// Right-side action column (Love, Comment, Share, Repost) overlaid on the
/// video. A `const`-friendly composition of leaf widgets — this widget
/// itself never rebuilds on interaction taps; only the individual
/// `BlocSelector`-backed leaves below do (FR-014).
///
/// v4 (FR-068/FR-073): Save moved into the 3-dots more-options sheet
/// ([ReelMoreButton]) — this slot now hosts the primary Repost toggle.
class ReelInteractionOverlay extends StatelessWidget {
  const ReelInteractionOverlay({super.key, required this.reel});

  final Reel reel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoveButton(reelId: reel.id),
        const SizedBox(height: 20),
        CommentButton(
          reelId: reel.id,
          onTap: () => showCommentsSheet(context, reel.id),
        ),
        const SizedBox(height: 20),
        ShareButton(
          reelId: reel.id,
          onTap: () => showReelShareSheet(context, reel),
        ),
        const SizedBox(height: 20),
        RepostButton(reelId: reel.id, creatorId: reel.creator.id),
        const SizedBox(height: 20),
        ReelMoreButton(reel: reel),
      ],
    );
  }
}
