import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/features/map/presentation/mock/map_mock_data.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ReelsViewerScreen extends StatefulWidget {
  const ReelsViewerScreen({super.key});

  @override
  State<ReelsViewerScreen> createState() => _ReelsViewerScreenState();
}

class _ReelsViewerScreenState extends State<ReelsViewerScreen> {
  int _currentPage = 0;
  bool _isFollowing = true;

  @override
  Widget build(BuildContext context) {
    final statuses = mockStatuses;
    final currentStatus =
        statuses.isNotEmpty ? statuses[_currentPage] : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen vertical PageView ─────────────────────────────
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: statuses.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final status = statuses[index];
              return SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: status.mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Icon(Icons.broken_image,
                        color: Colors.white38, size: 60),
                  ),
                ),
              );
            },
          ),
          // ── Dark gradient overlay (bottom half) ───────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // ── Top bar ───────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ReelsTopBar(
              isFollowing: _isFollowing,
              onTabChanged: (val) => setState(() => _isFollowing = val),
            ),
          ),
          // ── Right action column ───────────────────────────────────────
          if (currentStatus != null)
            Positioned(
              right: 10,
              bottom: 120,
              child: _ReelsActionColumn(status: currentStatus),
            ),
          // ── Bottom info overlay ───────────────────────────────────────
          if (currentStatus != null)
            Positioned(
              bottom: 40,
              left: 16,
              right: 100,
              child: _ReelsBottomInfo(status: currentStatus),
            ),
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _ReelsTopBar extends StatelessWidget {
  const _ReelsTopBar({
    required this.isFollowing,
    required this.onTabChanged,
  });

  final bool isFollowing;
  final ValueChanged<bool> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {},
            ),
            const Spacer(),
            // Following / Explore pill
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopPillTab(
                    label: 'reels_following'.tr(),
                    isSelected: isFollowing,
                    onTap: () => onTabChanged(true),
                  ),
                  _TopPillTab(
                    label: 'reels_explore'.tr(),
                    isSelected: !isFollowing,
                    onTap: () => onTabChanged(false),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.add_box_outlined, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPillTab extends StatelessWidget {
  const _TopPillTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Right Action Column ───────────────────────────────────────────────────────

class _ReelsActionColumn extends StatefulWidget {
  const _ReelsActionColumn({required this.status});

  final MockStatus status;

  @override
  State<_ReelsActionColumn> createState() => _ReelsActionColumnState();
}

class _ReelsActionColumnState extends State<_ReelsActionColumn> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReelActionItem(
            icon: _liked ? Icons.favorite : Icons.favorite_border,
            iconColor: _liked ? Colors.redAccent : Colors.white,
            count: widget.status.likeCount + (_liked ? 1 : 0),
            onTap: () => setState(() => _liked = !_liked),
          ),
          const SizedBox(height: 4),
          _ReelActionItem(
            icon: Icons.chat_bubble_outline,
            count: widget.status.commentCount,
            onTap: () {},
          ),
          const SizedBox(height: 4),
          _ReelActionItem(
            icon: Icons.reply,
            label: 'reels_share'.tr(),
            onTap: () {},
          ),
          const SizedBox(height: 4),
          _ReelActionItem(
            icon: Icons.refresh,
            onTap: () {},
          ),
          const SizedBox(height: 4),
          _ReelActionItem(
            icon: Icons.music_note_outlined,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ReelActionItem extends StatelessWidget {
  const _ReelActionItem({
    required this.icon,
    this.iconColor = Colors.white,
    this.count,
    this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final int? count;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 28),
            if (count != null) ...[
              const SizedBox(height: 2),
              Text(
                '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ] else if (label != null) ...[
              const SizedBox(height: 2),
              Text(
                label!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bottom Info Overlay ───────────────────────────────────────────────────────

class _ReelsBottomInfo extends StatelessWidget {
  const _ReelsBottomInfo({required this.status});

  final MockStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status.author.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _timeAgo(status.timestamp),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          status.caption,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
