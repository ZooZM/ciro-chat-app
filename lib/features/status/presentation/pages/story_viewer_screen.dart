import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_reaction.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_viewer.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How long each segment of the progress bar takes to fill.
const _kStorySegmentDuration = Duration(seconds: 5);

/// Full-screen story viewer for a group of statuses belonging to the same
/// author. Shows a segmented progress bar (one segment per status) and
/// supports tap-to-navigate: tap the right half of the screen to advance,
/// the left half to go back, mirroring WhatsApp/Instagram stories.
class StoryViewerScreen extends StatefulWidget {
  final List<StatusEntity> statuses;
  final int initialIndex;

  /// True when opened from a "X loved your status" push notification — the
  /// viewers/reactions sheet opens automatically once the screen settles.
  final bool openViewersOnStart;

  const StoryViewerScreen({
    super.key,
    required this.statuses,
    this.initialIndex = 0,
    this.openViewersOnStart = false,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _progressController;
  bool _isPopping = false;

  StatusEntity get _currentStatus => widget.statuses[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.statuses.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: _kStorySegmentDuration,
    )..addStatusListener(_onProgressStatusChanged);
    // Defer so context.read<StatusCubit>() resolves against the BlocProvider
    // ancestor rather than a separate factory instance from getIt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startCurrent();
    });
  }

  void _onProgressStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToNext();
    }
  }

  void _startCurrent() {
    context.read<StatusCubit>().markStatusAsViewed(_currentStatus.id);
    _progressController
      ..reset()
      ..forward();
  }

  void _goToNext() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _startCurrent();
    } else {
      _safePop();
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

  void _safePop() {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
          ? Color(
              int.parse(
                status.backgroundColor!.replaceAll('#', 'FF'),
                radix: 16,
              ),
            )
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
            _StoryHeader(status: status, onBack: _safePop),
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
            if (status.isMine)
              _StoryViewersBar(
                statusId: status.id,
                autoOpen:
                    widget.openViewersOnStart &&
                    _currentIndex == widget.initialIndex,
              )
            else
              _StoryBottomBar(
                status: status,
                onPause: _pause,
                onResume: _resume,
              ),
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
        if (status.mediaUrl != null && status.mediaUrl!.isNotEmpty) {
          final url = status.mediaUrl!;
          if (url.startsWith('http://') || url.startsWith('https://')) {
            return CachedNetworkImage(
              imageUrl: url,
              httpHeaders: UrlUtils.authHeaders ?? {},
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
              errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image,
                size: 80,
                color: Colors.white54,
              ),
            );
          }
          // Local file path (e.g. optimistic insert before server upload)
          return Image.file(File(url), fit: BoxFit.contain);
        }
        return const Icon(Icons.image, size: 100, color: Colors.white);
      case StatusContentType.video:
        return const Icon(Icons.videocam, size: 100, color: Colors.white);
      case StatusContentType.voice:
        return const Icon(Icons.mic, size: 100, color: Colors.white);
    }
  }
}

// ── Progress bar ────────────────────────────────────────────────────────────

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

// ── Header ──────────────────────────────────────────────────────────────────

class _StoryHeader extends StatelessWidget {
  final StatusEntity status;
  final VoidCallback onBack;

  const _StoryHeader({required this.status, required this.onBack});

  /// Returns the contact-resolved name for this status from the current cubit
  /// state, falling back to [status.authorName] when not found.
  String _resolvedName(StatusState state) {
    if (state is! StatusLoaded) return status.authorName;
    final all = [
      ...state.recentStatuses,
      ...state.viewedStatuses,
      ...state.myStatuses,
    ];
    final latest = all.cast<StatusEntity?>().firstWhere(
      (s) => s?.id == status.id,
      orElse: () => null,
    );
    final name = latest?.authorName ?? status.authorName;
    return name.isNotEmpty ? name : status.authorName;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatusCubit, StatusState>(
      buildWhen: (prev, curr) {
        // Only rebuild when the author name for this specific status changes.
        if (prev is StatusLoaded && curr is StatusLoaded) {
          return _resolvedName(prev) != _resolvedName(curr);
        }
        return prev.runtimeType != curr.runtimeType;
      },
      builder: (context, state) {
        final displayName = _resolvedName(state);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black54),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFCB64F),
                backgroundImage: status.authorAvatar.isNotEmpty
                    ? NetworkImage(status.authorAvatar)
                    : null,
                child: status.authorAvatar.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
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
                    displayName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(status.timestamp),
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays == 0) {
      return '${'status.today'.tr()} ${DateFormat.jm().format(timestamp)}';
    } else if (diff.inDays == 1) {
      return '${'status.yesterday'.tr()} ${DateFormat.jm().format(timestamp)}';
    }
    return DateFormat.yMMMd().format(timestamp);
  }
}

// ── Reply bottom bar (other users' statuses) ────────────────────────────────

class _StoryBottomBar extends StatefulWidget {
  final StatusEntity status;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const _StoryBottomBar({
    required this.status,
    required this.onPause,
    required this.onResume,
  });

  @override
  State<_StoryBottomBar> createState() => _StoryBottomBarState();
}

class _StoryBottomBarState extends State<_StoryBottomBar> {
  final _textController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _sendReply() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    context.read<StatusCubit>().reply(widget.status.id, text);
    _textController.clear();
    widget.onResume();
  }

  void _sendReaction() {
    context.read<StatusCubit>().react(widget.status.id, '❤️');
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

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
                color: const Color(0xFF5D4F3F),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'status.reply'.tr(),
                  hintStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onTap: widget.onPause,
                onSubmitted: (_) => _sendReply(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _hasText ? _sendReply : _sendReaction,
            child: Container(
              height: 48,
              width: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF5D4F3F),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _hasText ? Icons.send : Icons.favorite_border,
                  key: ValueKey(_hasText),
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Viewers bar (own statuses) ───────────────────────────────────────────────

class _StoryViewersBar extends StatefulWidget {
  final String statusId;
  final bool autoOpen;

  const _StoryViewersBar({required this.statusId, this.autoOpen = false});

  @override
  State<_StoryViewersBar> createState() => _StoryViewersBarState();
}

class _StoryViewersBarState extends State<_StoryViewersBar> {
  bool _hasAutoOpened = false;

  StatusEntity? _findStatus(StatusState state) {
    if (state is! StatusLoaded) return null;
    return state.myStatuses.cast<StatusEntity?>().firstWhere(
      (s) => s?.id == widget.statusId,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatusCubit, StatusState>(
      buildWhen: (prev, curr) {
        final prevStatus = _findStatus(prev);
        final currStatus = _findStatus(curr);
        return prevStatus?.viewers != currStatus?.viewers ||
            prevStatus?.reactions != currStatus?.reactions;
      },
      builder: (context, state) {
        final status = _findStatus(state);
        final viewers = status?.viewers ?? const <StatusViewer>[];
        final reactedUserIds = (status?.reactions ?? const <StatusReaction>[])
            .map((r) => r.userId)
            .toSet();

        if (widget.autoOpen && !_hasAutoOpened && viewers.isNotEmpty) {
          _hasAutoOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showViewersList(context, viewers, reactedUserIds);
          });
        }

        return GestureDetector(
          onTap: viewers.isNotEmpty
              ? () => _showViewersList(context, viewers, reactedUserIds)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  viewers.isEmpty
                      ? 'status.no_views'.tr()
                      : '${'status.views'.tr()} ${viewers.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (viewers.isNotEmpty) ...[
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showViewersList(
    BuildContext context,
    List<StatusViewer> viewers,
    Set<String> reactedUserIds,
  ) {
    showModalBottomSheet(
      context: context,

      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ViewersSheet(viewers: viewers, reactedUserIds: reactedUserIds),
    );
  }
}

class _ViewersSheet extends StatelessWidget {
  final List<StatusViewer> viewers;
  final Set<String> reactedUserIds;

  const _ViewersSheet({required this.viewers, required this.reactedUserIds});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(
                Icons.remove_red_eye_outlined,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${viewers.length} ${'status.views'.tr()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: viewers.length,
            itemBuilder: (context, index) {
              final viewer = viewers[index];
              final hasLoved = reactedUserIds.contains(viewer.userId);
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: viewer.avatarUrl.isNotEmpty
                      ? NetworkImage(viewer.avatarUrl)
                      : null,
                  child: viewer.avatarUrl.isEmpty
                      ? Text(
                          viewer.name.isNotEmpty
                              ? viewer.name[0].toUpperCase()
                              : '?',
                        )
                      : null,
                ),
                title: Text(
                  viewer.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  DateFormat.jm().format(viewer.viewedAt),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: hasLoved
                    ? const Icon(
                        Icons.favorite,
                        color: Colors.redAccent,
                        size: 20,
                      )
                    : null,
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}
