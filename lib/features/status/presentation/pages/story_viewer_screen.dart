import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class StoryViewerScreen extends StatefulWidget {
  final StatusEntity status;

  const StoryViewerScreen({super.key, required this.status});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  @override
  void initState() {
    super.initState();
    getIt<StatusCubit>().markStatusAsViewed(widget.status.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.status.backgroundColor != null 
          ? Color(int.parse(widget.status.backgroundColor!.replaceAll('#', 'FF'), radix: 16))
          : const Color(0xFFB3966D),
      body: SafeArea(
        child: Column(
          children: [
            const _StoryProgressBar(),
            const SizedBox(height: 8),
            _StoryHeader(status: widget.status),
            Expanded(
              child: Center(
                child: _buildContent(),
              ),
            ),
            if (widget.status.caption != null && widget.status.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.status.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            _StoryBottomBar(status: widget.status),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.status.contentType) {
      case StatusContentType.text:
        return Text(
          widget.status.textContent ?? '',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            fontFamily: widget.status.fontStyle,
          ),
          textAlign: TextAlign.center,
        );
      case StatusContentType.image:
        if (widget.status.mediaUrl != null) {
          return Image.network(widget.status.mediaUrl!);
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
  const _StoryProgressBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(child: _buildSegment(isActive: true)),
          const SizedBox(width: 6),
          Expanded(child: _buildSegment(isActive: false)),
          const SizedBox(width: 6),
          Expanded(child: _buildSegment(isActive: false)),
        ],
      ),
    );
  }

  Widget _buildSegment({required bool isActive}) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(1.5),
      ),
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
