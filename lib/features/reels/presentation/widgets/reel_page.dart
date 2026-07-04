import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_status.dart';
import 'buffering_indicator.dart';
import 'follow_button.dart';
import 'play_pause_overlay.dart';
import 'reel_creator_header.dart';
import 'reel_description.dart';
import 'reel_interaction_overlay.dart';

/// Full-bleed video surface for a single reel, composed with the
/// interaction overlay, creator header, and play/pause layer. The video
/// surface itself contains no `BlocBuilder`/`BlocSelector` — every dynamic
/// element (love, comments, buffering, play/pause) lives in leaf widgets so
/// a tap anywhere else never rebuilds the video (FR-014).
class ReelPage extends StatelessWidget {
  const ReelPage({
    super.key,
    required this.reel,
    required this.controller,
    this.isFailed = false,
    this.onRetry,
    this.onCreatorTap,
  });

  final Reel reel;

  /// Null while this index is outside the live player window (e.g. briefly
  /// during a fast multi-swipe) — shows the thumbnail only.
  final VideoController? controller;

  /// True when this reel's player failed to open (FR-035) — shows an error
  /// placeholder instead of the video; the user can still swipe past it.
  final bool isFailed;
  final VoidCallback? onRetry;

  /// Navigates to the Creator Profile screen (US4).
  final VoidCallback? onCreatorTap;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isFailed)
            _FailedPlaceholder(onRetry: onRetry)
          else ...[
            if (activeController != null)
              Video(
                controller: activeController,
                fit: BoxFit.cover,
                controls: NoVideoControls,
              ),
            // Thumbnail-while-buffering — reacts to media_kit's own stream
            // directly (constitution VIII-C: never a blank spinner).
            if (activeController != null)
              StreamBuilder<bool>(
                stream: activeController.player.stream.buffering,
                initialData: true,
                builder: (context, snapshot) {
                  return AnimatedOpacity(
                    opacity: snapshot.data == true ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      child: _Thumbnail(url: reel.thumbnailUrl),
                    ),
                  );
                },
              )
            else
              _Thumbnail(url: reel.thumbnailUrl),
            if (activeController != null)
              BufferingIndicator(controller: activeController),
            // Tap-to-pause sits below the overlay controls in the stack so
            // Love/Comment/Share/creator taps are hit-tested first (FR-015).
            if (activeController != null)
              PlayPauseOverlay(controller: activeController),
            // Soft dark scrim so the creator info, description, and action
            // column stay readable over a bright/white video background.
            // `IgnorePointer` keeps tap-to-pause working underneath it.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(child: _BottomScrim()),
            ),
            Positioned(
              left: 12,
              right: 88,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ReelCreatorHeader(
                          creator: reel.creator,
                          onTap: onCreatorTap,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // A reel's creator is always a mock/other account in v1
                      // (no upload feature — see spec.md Assumptions), so
                      // isSelf is safely false here; the Creator Profile screen
                      // enforces FR-031 with the backend-verified flag.
                      FollowButton(creatorId: reel.creator.id, isSelf: false),
                    ],
                  ),
                  if (reel.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ReelDescription(
                      description: reel.description,
                      mentions: reel.mentions,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 24,
              child: ReelInteractionOverlay(reel: reel),
            ),
            // v3 (FR-065): own-reel-view banner for a non-published reel —
            // only the owner ever reaches one here (own-profile deep dive).
            if (reel.status != ReelStatus.published)
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: _StatusBanner(status: reel.status),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.black.withValues(alpha: 0.35),
            Colors.black.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final ReelStatus status;

  @override
  Widget build(BuildContext context) {
    final isProcessing = status == ReelStatus.pendingModeration;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isProcessing ? Colors.black : Colors.red.shade900).withValues(
          alpha: 0.85,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isProcessing ? Icons.hourglass_top : Icons.block,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              (isProcessing
                      ? 'reels.status_processing'
                      : 'reels.status_removed')
                  .tr(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const ColoredBox(color: Colors.black);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (context, url, error) =>
          const ColoredBox(color: Colors.black),
    );
  }
}

class _FailedPlaceholder extends StatelessWidget {
  const _FailedPlaceholder({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          Text(
            'reels.error_title'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text('reels.retry'.tr())),
          ],
        ],
      ),
    );
  }
}
