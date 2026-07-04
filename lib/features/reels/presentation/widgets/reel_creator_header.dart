import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';

/// Avatar + username overlaid on the video (FR-022). Purely presentational —
/// a `const`-friendly leaf widget that never touches feed or interaction
/// state directly; navigation to the Creator Profile screen is wired by the
/// caller (US4) via [onTap].
class ReelCreatorHeader extends StatelessWidget {
  const ReelCreatorHeader({super.key, required this.creator, this.onTap});

  final ReelCreator creator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade800,
            backgroundImage:
                creator.avatarUrl.isEmpty ? null : CachedNetworkImageProvider(creator.avatarUrl),
            child: creator.avatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white70, size: 18)
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              creator.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
