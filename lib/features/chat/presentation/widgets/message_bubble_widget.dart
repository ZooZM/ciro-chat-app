import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import '../bloc/voice_note_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/message.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_cubit.dart';
import 'media_gallery_viewer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main bubble widget
// ─────────────────────────────────────────────────────────────────────────────

class MessageBubbleWidget extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final bool isGroup;

  const MessageBubbleWidget({
    Key? key,
    required this.message,
    required this.currentUserId,
    this.isGroup = false,
  }) : super(key: key);

  bool get _isMine => message.senderId == currentUserId;

  /// Image & video bubbles have their own ClipRRect — the outer container
  /// must be transparent and have no padding so the media fills edge-to-edge.
  bool get _isMediaBubble =>
      message.type == MessageType.image || message.type == MessageType.video;

  /// Group-chat sender label: if the phone is saved in local contacts, show
  /// the saved name; otherwise show `+phone ~ServerName` (or just `+phone` /
  /// `ServerName` / `senderId` depending on what we have).
  Future<String> _resolveGroupSenderLabel(BuildContext context) async {
    final phone = message.senderPhone;
    if (phone.isNotEmpty) {
      final contactName = await context.read<ChatCubit>().getLocalContactName(phone);
      if (contactName.isNotEmpty && contactName != phone) return contactName;
      if (message.senderName.isNotEmpty) return '$phone ~${message.senderName}';
      return phone;
    }
    if (message.senderName.isNotEmpty) return message.senderName;
    return message.senderId;
  }

  String _fallbackSenderLabel() {
    if (message.senderPhone.isNotEmpty) {
      return message.senderName.isNotEmpty
          ? '${message.senderPhone} ~${message.senderName}'
          : message.senderPhone;
    }
    return message.senderName.isNotEmpty ? message.senderName : message.senderId;
  }

  Color get _bgColor =>
      _isMediaBubble ? Colors.transparent : (_isMine ? AppColors.primaryLight : AppColors.surface);

  BorderRadius _borderRadius() {
    final r = Radius.circular(12.resR);
    return BorderRadius.only(
      topLeft: _isMine ? r : Radius.zero,
      topRight: _isMine ? Radius.zero : r,
      bottomLeft: r,
      bottomRight: r,
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.pending:
        return Icon(
          Icons.access_time,
          size: 14.resW,
          color: AppColors.textSecondary,
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14.resW, color: AppColors.textSecondary);
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14.resW,
          color: AppColors.textSecondary,
        );
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14.resW, color: AppColors.secondary);
      case MessageStatus.error:
        return Icon(Icons.error_outline, size: 14.resW, color: AppColors.error);
    }
  }

  Widget _buildFooter() {
    final formattedTime = DateFormat('hh:mm a').format(message.timestamp);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formattedTime,
          style: AppTypography.caption.copyWith(
            fontSize: 10.resSp,
            color: AppColors.textSecondary,
          ),
        ),
        if (_isMine) ...[SizedBox(width: 4.resW), _buildStatusIcon()],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system ||
        message.senderId == '000000000000000000000000') {
      return _buildSystemBubble(context);
    }

    // FR-022: Render deleted placeholder instead of content.
    if (message.isDeleted) {
      return Align(
        alignment: _isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 4.resH),
          padding: EdgeInsets.symmetric(horizontal: 14.resW, vertical: 10.resH),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: _borderRadius(),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 14.resW, color: AppColors.textSecondary),
              SizedBox(width: 6.resW),
              Text(
                'This message was deleted',
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubble = Container(
      margin: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 4.resH),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: _isMediaBubble ? null : _borderRadius(),
        boxShadow: _isMediaBubble
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2.resR,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGroup && !_isMine)
            Padding(
              padding: EdgeInsets.only(
                left: 12.resW,
                right: 12.resW,
                top: 8.resH,
              ),
              child: FutureBuilder<String>(
                future: _resolveGroupSenderLabel(context),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? _fallbackSenderLabel(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          _buildContent(context),
        ],
      ),
    );

    final aligned = Align(
      alignment: _isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: _isMine && message.status == MessageStatus.error
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: AppColors.error,
                  onPressed: () {
                    context.read<ChatCubit>().resendMessage(
                      message.clientMessageId,
                    );
                  },
                ),
                bubble,
              ],
            )
          : bubble,
    );

    // FR-022: Long-press menu for delete options.
    return GestureDetector(
      onLongPress: () => _showDeleteMenu(context),
      child: aligned,
    );
  }

  void _showDeleteMenu(BuildContext context) {
    final cubit = context.read<ChatCubit>();
    final canDeleteForEveryone = _isMine &&
        DateTime.now().difference(message.timestamp).inHours < 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete for me'),
                onTap: () {
                  Navigator.pop(context);
                  cubit.deleteMessageForMe(message.clientMessageId);
                },
              ),
              if (canDeleteForEveryone)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete for everyone'),
                  onTap: () {
                    Navigator.pop(context);
                    cubit.deleteMessageForEveryone(message.clientMessageId);
                  },
                ),
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: AppColors.textSecondary),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemBubble(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12.resH, horizontal: 32.resW),
      alignment: Alignment.center,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 8.resH),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16.resR),
        ),
        child: Text(
          message.text,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _ImageBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.file:
        return _FileBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.voiceNote:
        return _VoiceBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.contact:
        return _ContactBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.location:
        return _LocationBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.audio:
        return _AudioBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.poll:
        return _PollBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.event:
        return _EventBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.video:
        return _VideoBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
      case MessageType.system:
      case MessageType.text:
        return _TextBubble(
          message: message,
          isMine: _isMine,
          footer: _buildFooter(),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text bubble (unchanged behaviour)
// ─────────────────────────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _TextBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: AppTypography.body1.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image bubble
// ─────────────────────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _ImageBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final localPath = meta['localPath'] as String?;

    final hasLocal = localPath != null && File(localPath).existsSync();
    final url = message.resolvedFileUrl;
    final isUploading = !hasLocal && url.isEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.resR),
      child: SizedBox(
        width: 220.resW,
        height: 180.resH,
        child: isUploading
            ? _UploadingPlaceholder()
            : GestureDetector(
                onTap: () => _openMediaGallery(context, message),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    hasLocal
                        ? Image.file(
                            File(localPath),
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _UploadingPlaceholder(),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.surfaceVariant,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                    // T155: Footer overlay — dark gradient at bottom-right
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.only(
                          left: 8.resW,
                          right: 6.resW,
                          top: 18.resH,
                          bottom: 6.resH,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: DefaultTextStyle(
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.resSp,
                            ),
                            child: footer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _openMediaGallery(BuildContext context, Message tappedMsg) {
    final state = context.read<ChatCubit>().state;
    if (state is ChatRoomActive) {
      final mediaMessages = state.messages
          .where(
            (m) => m.type == MessageType.image || m.type == MessageType.video,
          )
          .toList()
          .reversed
          .toList();

      final index = mediaMessages.indexWhere((m) => m.id == tappedMsg.id);

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaGalleryViewer(
            mediaMessages: mediaMessages,
            initialIndex: index == -1 ? 0 : index,
          ),
        ),
      );
    }
  }
}

class _UploadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220.resW,
      height: 180.resH,
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8.resH),
            Text(
              'Uploading…',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video bubble
// ─────────────────────────────────────────────────────────────────────────────

class _VideoBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _VideoBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final localThumb = meta['localThumbPath'] as String?;
    final thumbUrl = meta['thumbnailUrl'] as String?;
    final durationSec = meta['duration'] as int?;
    final durationLabel = durationSec != null
        ? '${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}'
        : null;

    final hasLocalThumb = localThumb != null && File(localThumb).existsSync();
    final url = UrlUtils.resolveMediaUrl(thumbUrl);
    // Only show uploading state if we have no local thumb AND no CDN URL AND no fileUrl.
    // A video with a fileUrl but no thumbnail is still watchable — show a play tile.
    final hasFileUrl = message.fileUrl != null && message.fileUrl!.isNotEmpty;
    final isUploading = !hasLocalThumb && url.isEmpty && !hasFileUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.resR),
      child: SizedBox(
        width: 220.resW,
        height: 180.resH,
        child: isUploading
            ? _UploadingPlaceholder()
            : GestureDetector(
                onTap: () => _openMediaGallery(context, message),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail — local first, CDN next, plain dark fallback
                    if (hasLocalThumb)
                      Image.file(File(localThumb), fit: BoxFit.cover)
                    else if (url.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _UploadingPlaceholder(),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceVariant,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      Container(color: const Color(0xFF1A1A2E)),
                    // Dark gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.only(
                          left: 8.resW,
                          right: 6.resW,
                          top: 18.resH,
                          bottom: 6.resH,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // T156: Duration chip bottom-left
                            if (durationLabel != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.resW,
                                  vertical: 2.resH,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(4.resR),
                                ),
                                child: Text(
                                  durationLabel,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.resSp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            // Footer overlay bottom-right
                            DefaultTextStyle(
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.resSp,
                              ),
                              child: footer,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // T156: Centered play button
                    Center(
                      child: Container(
                        width: 48.resW,
                        height: 48.resW,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32.resW,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _openMediaGallery(BuildContext context, Message tappedMsg) {
    final state = context.read<ChatCubit>().state;
    if (state is ChatRoomActive) {
      final mediaMessages = state.messages
          .where(
            (m) => m.type == MessageType.image || m.type == MessageType.video,
          )
          .toList()
          .reversed
          .toList();

      final index = mediaMessages.indexWhere((m) => m.id == tappedMsg.id);

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaGalleryViewer(
            mediaMessages: mediaMessages,
            initialIndex: index == -1 ? 0 : index,
          ),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File bubble
// ─────────────────────────────────────────────────────────────────────────────

class _FileBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _FileBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final fileName = meta['fileName'] as String? ?? 'File';
    final fileSize = meta['fileSize'] as int? ?? 0;
    final isUploading = message.fileUrl == null || message.fileUrl!.isEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 10.resH),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.resW,
                height: 42.resW,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.resR),
                ),
                child: isUploading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.insert_drive_file_outlined,
                        color: AppColors.primary,
                        size: 24.resW,
                      ),
              ),
              SizedBox(width: 10.resW),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (fileSize > 0)
                      Text(
                        _formatSize(fileSize),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8.resW),
              if (!isUploading)
                Icon(
                  Icons.download_outlined,
                  size: 20.resW,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          SizedBox(height: 6.resH),
          footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice note bubble (stateful — owns the AudioPlayer)
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceBubble extends StatefulWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _VoiceBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  late final PlayerController _playerController;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  late final AnimationController _shimmerController;
  bool _isPlaying = false;
  bool _isPrepared = false;
  bool _isPreparing = false;
  List<double>? _cachedWaveformData;

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _playerStateSubscription = _playerController.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    VoiceNoteController().currentlyPlayingIdNotifier.addListener(
      _onCurrentlyPlayingChanged,
    );
    _preparePlayer();
  }

  void _onCurrentlyPlayingChanged() {
    if (VoiceNoteController().currentlyPlayingIdNotifier.value !=
        widget.message.id) {
      if (_isPlaying) {
        _playerController.pausePlayer().catchError((_) {});
      }
    }
  }

  Future<void> _preparePlayer() async {
    if (_isPrepared || _isPreparing) return;
    _isPreparing = true;

    final meta = widget.message.metadata ?? {};
    final localPath = meta['localPath'] as String?;
    final fileUrl = widget.message.fileUrl;

    // T145: Use pre-extracted waveform from sender if available.
    final rawSamples = meta['waveformSamples'];
    if (rawSamples is List && rawSamples.isNotEmpty) {
      _cachedWaveformData = rawSamples.whereType<num>().map((e) => e.toDouble()).toList();
    }

    String? path;
    if (localPath != null && File(localPath).existsSync()) {
      path = localPath;
    } else if (fileUrl != null && fileUrl.isNotEmpty) {
      path = widget.message.resolvedFileUrl;
    }

    if (path != null) {
      try {
        // If we already have waveform from metadata, skip extraction on receiver.
        final skipExtraction = _cachedWaveformData != null && _cachedWaveformData!.isNotEmpty;

        final cached = skipExtraction
            ? _cachedWaveformData
            : await context.read<ChatCubit>().getWaveformCache(
                widget.message.clientMessageId,
              );

        await _playerController.preparePlayer(
          path: path,
          shouldExtractWaveform: !skipExtraction && cached == null,
          noOfSamples: 50,
          volume: 1.0,
        );

        if (!skipExtraction && cached == null) {
          final extracted = await _playerController.waveformExtraction
              .extractWaveformData(path: path, noOfSamples: 50);
          if (extracted.isNotEmpty) {
            await context.read<ChatCubit>().saveWaveformCache(
              widget.message.clientMessageId,
              extracted,
            );
            _cachedWaveformData = extracted;
          }
        } else if (cached != null) {
          _cachedWaveformData = cached;
        }

        if (mounted) {
          setState(() {
            _isPrepared = true;
            _isPreparing = false;
          });
        }
      } catch (e) {
        debugPrint('[VoiceBubble] prepare error: $e');
        if (mounted) {
          setState(() {
            _isPreparing = false;
          });
        }
      }
    } else {
      _isPreparing = false;
    }
  }

  @override
  void didUpdateWidget(covariant _VoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If it was uploading and now has a URL/Path, prepare it
    if (!_isPrepared && !_isPreparing) {
      _preparePlayer();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    VoiceNoteController().currentlyPlayingIdNotifier.removeListener(
      _onCurrentlyPlayingChanged,
    );
    _playerStateSubscription?.cancel();

    // ── IMPORTANT: We intentionally do NOT call _playerController.dispose()
    // The audio_waveforms package's dispose() internally calls
    // stopWaveformExtraction() via a MethodChannel created in the root zone.
    // When the native MediaCodec is already released (rapid back-navigation),
    // this throws PlatformException("codec is released already") which
    // CANNOT be caught by try/catch, runZonedGuarded, or .catchError()
    // because root-zone platform channel errors bypass all child zones.
    //
    // The PlayerController will be garbage collected and its native
    // resources freed by the Android finalizer. Active playback is
    // stopped by VoiceNoteController().stopCurrent() in ChatRoomScreen's
    // PopScope before navigation occurs.

    super.dispose();
  }

  void _togglePlay() async {
    if (!_isPrepared) return;
    if (_isPlaying) {
      await _playerController.pausePlayer();
    } else {
      VoiceNoteController().play(widget.message.id, _playerController);
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.message.metadata ?? {};
    final duration = meta['duration'] as int? ?? 0;

    final localPath = meta['localPath'] as String?;
    final fileUrl = widget.message.fileUrl;
    final hasLocal = localPath != null && File(localPath).existsSync();
    final isUploading = !hasLocal && (fileUrl == null || fileUrl.isEmpty);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: widget.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play / pause button or spinner
              GestureDetector(
                onTap: (isUploading || !_isPrepared) ? null : _togglePlay,
                child: Container(
                  width: 44.resW,
                  height: 44.resW,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: isUploading || (_isPreparing && !hasLocal)
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 26.resW,
                        ),
                ),
              ),
              SizedBox(width: 8.resW),

              // Waveform
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 36.resH,
                      child: _isPrepared
                          ? AudioFileWaveforms(
                              size: Size(
                                MediaQuery.of(context).size.width * 0.4,
                                36.resH,
                              ),
                              playerController: _playerController,
                              waveformData: _cachedWaveformData ?? const [],
                              enableSeekGesture: true,
                              waveformType: WaveformType.fitWidth,
                              playerWaveStyle: PlayerWaveStyle(
                                fixedWaveColor: Colors.grey.shade400,
                                liveWaveColor: AppColors.primary,
                                spacing: 5,
                                waveThickness: 2.resW,
                              ),
                            )
                          : _isPreparing
                              ? AnimatedBuilder(
                                  animation: _shimmerController,
                                  builder: (context, _) {
                                    final opacity = 0.3 + (0.7 * _shimmerController.value);
                                    return Container(
                                      height: 2.resH,
                                      width: MediaQuery.of(context).size.width * 0.4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300
                                            .withValues(alpha: opacity),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  height: 2.resH,
                                  color: Colors.grey.shade300,
                                ),
                    ),
                    SizedBox(height: 4.resH),
                    Text(
                      duration > 0 ? _formatDuration(duration) : '–:––',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10.resSp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.resH),
          widget.footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact card bubble
// ─────────────────────────────────────────────────────────────────────────────

class _ContactBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _ContactBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  Future<void> _saveContact(BuildContext context) async {
    final meta = message.metadata ?? {};
    final name = meta['contactName'] as String? ?? 'Unknown';
    final phone = meta['contactPhone'] as String? ?? '';

    try {
      final contact = Contact(
        name: Name(first: name),
        phones: phone.isNotEmpty ? [Phone(number: phone)] : [],
      );
      await FlutterContacts.create(contact);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name saved to contacts'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ContactBubble] Save contact failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save contact'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final name = meta['contactName'] as String? ?? 'Contact';
    final phone = meta['contactPhone'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 10.resH),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20.resR,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 22.resW,
                ),
              ),
              SizedBox(width: 10.resW),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      GestureDetector(
                        onLongPress: () =>
                            Clipboard.setData(ClipboardData(text: phone)),
                        child: Text(
                          phone,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.resH),
          Divider(height: 1, color: AppColors.divider),
          SizedBox(height: 6.resH),
          OutlinedButton.icon(
            onPressed: () => _saveContact(context),
            icon: Icon(Icons.person_add_alt_1_outlined, size: 16.resW),
            label: const Text('Save Contact'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: EdgeInsets.symmetric(
                horizontal: 14.resW,
                vertical: 6.resH,
              ),
              textStyle: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.resR),
              ),
            ),
          ),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Location bubble
// ─────────────────────────────────────────────────────────────────────────────

class _LocationBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _LocationBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final address = meta['address'] as String? ?? 'Shared Location';
    final lat = (meta['latitude'] as num?)?.toDouble();
    final lng = (meta['longitude'] as num?)?.toDouble();
    final hasCoords = lat != null && lng != null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: hasCoords ? () => _openMaps(lat, lng) : null,
            child: Container(
              height: 150.resH,
              width: 250.resW,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12.resR),
                border: hasCoords
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 32.resW,
                  ),
                  SizedBox(height: 8.resH),
                  Text(
                    address,
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasCoords) ...[
                    SizedBox(height: 6.resH),
                    Text(
                      'Tap to open in Maps',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio bubble
// ─────────────────────────────────────────────────────────────────────────────

class _AudioBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _AudioBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final fileName = meta['fileName'] as String? ?? 'Audio file';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: isMine
                    ? Colors.white24
                    : AppColors.primary.withOpacity(0.1),
                child: Icon(
                  Icons.headphones,
                  color: isMine ? Colors.white : AppColors.primary,
                ),
              ),
              SizedBox(width: 12.resW),
              Flexible(
                child: Text(
                  fileName,
                  style: AppTypography.body2.copyWith(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Poll bubble
// ─────────────────────────────────────────────────────────────────────────────

class _PollBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _PollBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final question = meta['question'] as String? ?? 'Poll';
    final options = (meta['options'] as List<dynamic>?)?.cast<String>() ?? [];
    final votes = (meta['votes'] as Map?)?.cast<String, List>() ?? {};
    final totalVotes = votes.values.fold<int>(0, (sum, list) => sum + list.length);

    // Poll bubble uses the same green bubble background as regular messages.
    final textColor = AppColors.textPrimary;
    final dimColor = AppColors.textSecondary;
    final accentColor = AppColors.primaryDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14.resW, 12.resH, 14.resW, 4.resH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question
              Text(
                question,
                style: AppTypography.body1.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontSize: 15.resSp,
                ),
              ),
              SizedBox(height: 4.resH),
              // "Select one or more" hint
              Row(
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    size: 14.resW,
                    color: dimColor,
                  ),
                  SizedBox(width: 4.resW),
                  Text(
                    'Select one or more',
                    style: AppTypography.caption.copyWith(
                      color: dimColor,
                      fontSize: 12.resSp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.resH),
              // Options with progress bars
              ...options.asMap().entries.map((entry) {
                final opt = entry.value;
                final optVotes = votes[opt]?.length ?? 0;
                final frac = totalVotes > 0 ? optVotes / totalVotes : 0.0;
                return Padding(
                  padding: EdgeInsets.only(bottom: 10.resH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20.resW,
                            height: 20.resW,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: dimColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.resW),
                          Expanded(
                            child: Text(
                              opt,
                              style: AppTypography.body2.copyWith(
                                color: textColor,
                                fontSize: 15.resSp,
                              ),
                            ),
                          ),
                          Text(
                            '$optVotes',
                            style: AppTypography.caption.copyWith(
                              color: dimColor,
                              fontSize: 13.resSp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.resH),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3.resR),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 3.resH,
                          backgroundColor: accentColor.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 2.resH),
              footer,
              SizedBox(height: 4.resH),
            ],
          ),
        ),
        // Divider + View votes button
        Divider(height: 1, color: AppColors.divider.withOpacity(0.6)),
        InkWell(
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 11.resH,
              horizontal: 14.resW,
            ),
            child: Center(
              child: Text(
                'View votes',
                style: AppTypography.body2.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.resSp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event bubble
// ─────────────────────────────────────────────────────────────────────────────

class _EventBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Widget footer;

  const _EventBubble({
    required this.message,
    required this.isMine,
    required this.footer,
  });

  String _formatEventDateRange(DateTime? start) {
    if (start == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    String fmtDay(DateTime d) {
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        return 'Today';
      }
      final tomorrow = now.add(const Duration(days: 1));
      if (d.year == tomorrow.year &&
          d.month == tomorrow.month &&
          d.day == tomorrow.day) {
        return 'Tomorrow';
      }
      return '${d.day} ${months[d.month - 1]}';
    }

    final h = start.hour == 0 ? 12 : (start.hour > 12 ? start.hour - 12 : start.hour);
    final m = start.minute.toString().padLeft(2, '0');
    final ampm = start.hour < 12 ? 'AM' : 'PM';
    // Show end as 2 hours later by default
    final end = start.add(const Duration(hours: 2));
    final eh = end.hour == 0 ? 12 : (end.hour > 12 ? end.hour - 12 : end.hour);
    final em = end.minute.toString().padLeft(2, '0');
    final eampm = end.hour < 12 ? 'AM' : 'PM';
    return '${fmtDay(start)}, $h:$m $ampm - ${fmtDay(end)}, $eh:$em $eampm';
  }

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final title = meta['title'] as String? ?? 'Event';
    final dateStr = meta['dateTime'] as String?;
    final desc = meta['description'] as String? ?? '';

    DateTime? date;
    if (dateStr != null) date = DateTime.tryParse(dateStr);
    final dateLabel = _formatEventDateRange(date);

    final accentColor = AppColors.primaryDark;
    final textColor = AppColors.textPrimary;
    final dimColor = AppColors.textSecondary;
    const iconBg = Color(0xFF2D5A1B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14.resW, 14.resH, 14.resW, 8.resH),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular calendar icon
              Container(
                width: 44.resW,
                height: 44.resW,
                decoration: const BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 24.resW,
                ),
              ),
              SizedBox(width: 12.resW),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body1.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        fontSize: 15.resSp,
                      ),
                    ),
                    if (dateLabel.isNotEmpty) ...[
                      SizedBox(height: 2.resH),
                      Text(
                        dateLabel,
                        style: AppTypography.caption.copyWith(
                          color: textColor,
                          fontSize: 13.resSp,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      SizedBox(height: 2.resH),
                      Text(
                        desc,
                        style: AppTypography.caption.copyWith(
                          color: dimColor,
                          fontSize: 13.resSp,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 6.resH),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10.resR,
                          backgroundColor: AppColors.primary.withOpacity(0.3),
                          child: Icon(
                            Icons.person,
                            size: 12.resW,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 6.resW),
                        Text(
                          '1 Going',
                          style: AppTypography.caption.copyWith(
                            color: dimColor,
                            fontSize: 12.resSp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.resH),
                    footer,
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.divider.withOpacity(0.6)),
        InkWell(
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 11.resH),
            child: Center(
              child: Text(
                'Join call',
                style: AppTypography.body2.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.resSp,
                ),
              ),
            ),
          ),
        ),
        Divider(height: 1, color: AppColors.divider.withOpacity(0.6)),
        InkWell(
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 11.resH),
            child: Center(
              child: Text(
                'Add to calendar',
                style: AppTypography.body2.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.resSp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
