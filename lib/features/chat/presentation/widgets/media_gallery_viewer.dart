import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';

class MediaGalleryViewer extends StatefulWidget {
  final List<Message> mediaMessages;
  final int initialIndex;

  const MediaGalleryViewer({
    Key? key,
    required this.mediaMessages,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MediaGalleryViewer> createState() => _MediaGalleryViewerState();
}

class _MediaGalleryViewerState extends State<MediaGalleryViewer> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaMessages.length,
        itemBuilder: (context, index) {
          final message = widget.mediaMessages[index];
          if (message.type == MessageType.image) {
            return _ImageGalleryItem(message: message);
          } else if (message.type == MessageType.video) {
            return _VideoGalleryItem(message: message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ImageGalleryItem extends StatelessWidget {
  final Message message;

  const _ImageGalleryItem({required this.message});

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final localPath = meta['localPath'] as String?;

    final hasLocal = localPath != null && File(localPath).existsSync();
    final url = message.resolvedFileUrl;

    return Center(
      child: InteractiveViewer(
        child: hasLocal
            ? Image.file(File(localPath), fit: BoxFit.contain)
            : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
      ),
    );
  }
}

class _VideoGalleryItem extends StatefulWidget {
  final Message message;

  const _VideoGalleryItem({required this.message});

  @override
  State<_VideoGalleryItem> createState() => _VideoGalleryItemState();
}

class _VideoGalleryItemState extends State<_VideoGalleryItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final meta = widget.message.metadata ?? {};
    final localPath = meta['localPath'] as String?;

    final hasLocal = localPath != null && File(localPath).existsSync();

    if (hasLocal) {
      _controller = VideoPlayerController.file(File(localPath));
    } else {
      final url = widget.message.resolvedFileUrl;
      if (url.isNotEmpty) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
    }

    if (_controller != null) {
      await _controller!.initialize();
      _controller!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _controller!.value.isPlaying;
          });
        }
      });
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              if (!_isPlaying)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
