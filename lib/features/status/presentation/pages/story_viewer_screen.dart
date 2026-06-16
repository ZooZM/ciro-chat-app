import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// How long each segment of the progress bar takes to fill.
const _kStorySegmentDuration = Duration(seconds: 5);

/// Full-screen story viewer for a group of statuses belonging to the same
/// author. Shows a segmented progress bar (one segment per status) and
/// supports tap-to-navigate: tap the right half of the screen to advance,
/// the left half to go back, mirroring WhatsApp/Instagram stories.
class StoryViewerScreen extends StatefulWidget {
  final List<StatusEntity> statuses;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.statuses,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _progressController;

  StatusEntity get _currentStatus => widget.statuses[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.statuses.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: _kStorySegmentDuration,
    )..addStatusListener(_onProgressStatusChanged);
    _startCurrent();
  }

  void _onProgressStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToNext();
    }
  }

  void _startCurrent() {
    getIt<StatusCubit>().markStatusAsViewed(_currentStatus.id);
    _progressController
      ..reset()
      ..forward();
  }

  void _goToNext() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _startCurrent();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startCurrent();
    } else {
      // Already on the first status — restart its progress.
      _progressController
        ..reset()
        ..forward();
    }
  }

  void _pause() => _progressController.stop();

  void _resume() {
    if (!_progressController.isAnimating) {
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;
    return Scaffold(
      backgroundColor: status.backgroundColor != null
          ? Color(int.parse(status.backgroundColor!.replaceAll('#', 'FF'), radix: 16))
          : const Color(0xFFB3966D),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) => _StoryProgressBar(
                count: widget.statuses.length,
                currentIndex: _currentIndex,
                progress: _progressController.value,
              ),
            ),
            const SizedBox(height: 8),
            _StoryHeader(status: status),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: (_) => _pause(),
                onLongPressEnd: (_) => _resume(),
                onTapUp: (details) {
                  final width = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < width / 2) {
                    _goToPrevious();
                  } else {
                    _goToNext();
                  }
                },
                child: Center(child: _buildContent(status)),
              ),
            ),
            if (status.caption != null && status.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  status.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            // Own statuses can't be replied to or reacted on.
            if (!status.isMine) _StoryBottomBar(status: status),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StatusEntity status) {
    switch (status.contentType) {
      case StatusContentType.text:
        return Text(
          status.textContent ?? '',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            fontFamily: status.fontStyle,
          ),
          textAlign: TextAlign.center,
        );
      case StatusContentType.image:
        if (status.mediaUrl != null) {
          return Image.network(status.mediaUrl!, headers: UrlUtils.authHeaders);
        }
        return const Icon(Icons.image, size: 100, color: Colors.white);
      case StatusContentType.video:
        return const Icon(Icons.videocam, size: 100, color: Colors.white);
      case StatusContentType.voice:
        return const Icon(Icons.mic, size: 100, color: Colors.white);
    }
  }
}

class _StoryProgressBar extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double progress;

  const _StoryProgressBar({
    required this.count,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: List.generate(count, (index) {
          final double value;
          if (index < currentIndex) {
            value = 1.0;
          } else if (index == currentIndex) {
            value = progress;
          } else {
            value = 0.0;
          }
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == count - 1 ? 0 : 6),
              child: _buildSegment(value),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSegment(double value) {
    return Stack(
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryHeader extends StatelessWidget {
  final StatusEntity status;

  const _StoryHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black54),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFCB64F), // Orange background
            backgroundImage: status.authorAvatar.isNotEmpty ? NetworkImage(status.authorAvatar) : null,
            child: status.authorAvatar.isEmpty
                ? Text(
                    status.authorName.isNotEmpty ? status.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.authorName,
                style: const TextStyle(
                  color: Colors.black, // Matches image exactly
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTimestamp(status.timestamp),
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays == 0) {
      return 'status.today'.tr() + ' ${DateFormat.jm().format(timestamp)}';
    } else if (diff.inDays == 1) {
      return 'status.yesterday'.tr() + ' ${DateFormat.jm().format(timestamp)}';
    }
    return DateFormat.yMMMd().format(timestamp);
  }
}

class _StoryBottomBar extends StatelessWidget {
  final StatusEntity status;

  const _StoryBottomBar({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF5D4F3F), // Dark semi-transparent brown
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'status.reply'.tr(),
                  hintStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onSubmitted: (text) {
                  // TODO: Send reply logic
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              // TODO: React logic
            },
            child: Container(
              height: 48,
              width: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF5D4F3F),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
