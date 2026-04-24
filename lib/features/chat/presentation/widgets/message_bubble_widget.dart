import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../bloc/voice_note_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/message.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Base URL constant — same default as DioClient to avoid an extra import.
// ─────────────────────────────────────────────────────────────────────────────

const _kBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://firstly-perforative-jaylah.ngrok-free.dev',
);

String _resolveUrl(String? relativeOrAbsolute) {
  if (relativeOrAbsolute == null || relativeOrAbsolute.isEmpty) return '';
  if (relativeOrAbsolute.startsWith('http')) return relativeOrAbsolute;
  final base = _kBaseUrl.endsWith('/') ? _kBaseUrl : '$_kBaseUrl/';
  final path = relativeOrAbsolute.startsWith('/')
      ? relativeOrAbsolute.substring(1)
      : relativeOrAbsolute;
  return '$base$path';
}

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

  Color get _bgColor => _isMine ? AppColors.primaryLight : AppColors.surface;

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
      default:
        return const SizedBox.shrink();
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
    if (message.type == MessageType.system || message.senderId == '000000000000000000000000') {
      return _buildSystemBubble(context);
    }

    return Align(
      alignment: _isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 4.resH),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: _borderRadius(),
          boxShadow: [
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
                padding: EdgeInsets.only(left: 12.resW, right: 12.resW, top: 8.resH),
                child: FutureBuilder<String>(
                  future: context.read<ChatCubit>().getLocalContactName(message.senderId),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? message.senderId,
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
      ),
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
    final fileUrl = message.fileUrl;

    final hasLocal = localPath != null && File(localPath).existsSync();
    final url = _resolveUrl(fileUrl);
    final isUploading = !hasLocal && url.isEmpty;

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.resR),
          child: isUploading
              ? _UploadingPlaceholder()
              : GestureDetector(
                  onTap: () => _openImageViewer(
                    context,
                    hasLocal ? localPath : url,
                    hasLocal,
                  ),
                  child: hasLocal
                      ? Image.file(
                          File(localPath),
                          width: 220.resW,
                          height: 180.resH,
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: url,
                          width: 220.resW,
                          height: 180.resH,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _UploadingPlaceholder(),
                          errorWidget: (_, __, ___) => Container(
                            width: 220.resW,
                            height: 180.resH,
                            color: AppColors.surfaceVariant,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 8.resW,
            right: 8.resW,
            bottom: 6.resH,
            top: 4.resH,
          ),
          child: footer,
        ),
      ],
    );
  }

  void _openImageViewer(BuildContext context, String pathOrUrl, bool isLocal) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _FullScreenImageViewer(pathOrUrl: pathOrUrl, isLocal: isLocal),
      ),
    );
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
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String pathOrUrl;
  final bool isLocal;
  const _FullScreenImageViewer({
    required this.pathOrUrl,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: isLocal
              ? Image.file(File(pathOrUrl), fit: BoxFit.contain)
              : CachedNetworkImage(imageUrl: pathOrUrl, fit: BoxFit.contain),
        ),
      ),
    );
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

class _VoiceBubbleState extends State<_VoiceBubble> {
  late final PlayerController _playerController;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isPlaying = false;
  bool _isPrepared = false;
  bool _isPreparing = false;

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController();
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

    String? path;
    if (localPath != null && File(localPath).existsSync()) {
      path = localPath;
    } else if (fileUrl != null && fileUrl.isNotEmpty) {
      path = _resolveUrl(fileUrl);
    }

    if (path != null) {
      try {
        await _playerController.preparePlayer(
          path: path,
          shouldExtractWaveform: true,
          noOfSamples: 50,
          volume: 1.0,
        );
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
    VoiceNoteController().currentlyPlayingIdNotifier.removeListener(
      _onCurrentlyPlayingChanged,
    );
    _playerStateSubscription?.cancel();

    _safeDisposeAudio();

    super.dispose();
  }

  Future<void> _safeDisposeAudio() async {
    try {
      if (!_playerController.playerState.isStopped) {
        await _playerController.stopPlayer();
      }
      _playerController.dispose();
    } on PlatformException catch (e) {
      debugPrint('AudioWaveforms safely caught codec exception: $e');
    } catch (e) {
      debugPrint('Error disposing audio controller: $e');
    }
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
                              enableSeekGesture: true,
                              waveformType: WaveformType.fitWidth,
                              playerWaveStyle: PlayerWaveStyle(
                                fixedWaveColor: Colors.grey.shade400,
                                liveWaveColor: AppColors.primary,
                                spacing: 5,
                                waveThickness: 2.resW,
                              ),
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
              SizedBox(width: 8.resW),

              // Avatar placeholder (optional)
              CircleAvatar(
                radius: 18.resR,
                backgroundColor: AppColors.divider,
                child: Icon(Icons.person, color: AppColors.surface, size: 20.resW),
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

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final address = meta['address'] as String? ?? 'Shared Location';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            height: 150.resH,
            width: 250.resW,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.resR),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 32.resW),
                  SizedBox(height: 8.resH),
                  Text(
                    address,
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: isMine ? Colors.white24 : AppColors.primary.withOpacity(0.1),
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            '📊 $question',
            style: AppTypography.body1.copyWith(
              fontWeight: FontWeight.bold,
              color: isMine ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.resH),
          ...options.map((opt) => Padding(
                padding: EdgeInsets.only(bottom: 4.resH),
                child: Container(
                  width: 200.resW,
                  padding: EdgeInsets.symmetric(vertical: 6.resH, horizontal: 12.resW),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.white24 : AppColors.divider,
                    borderRadius: BorderRadius.circular(8.resR),
                  ),
                  child: Text(
                    opt,
                    style: AppTypography.caption.copyWith(
                      color: isMine ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              )),
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? {};
    final title = meta['title'] as String? ?? 'Event';
    final dateStr = meta['dateTime'] as String?;
    final desc = meta['description'] as String? ?? '';
    
    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 8.resH),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                color: isMine ? Colors.white : AppColors.primary,
                size: 20.resW,
              ),
              SizedBox(width: 8.resW),
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (date != null) ...[
            SizedBox(height: 4.resH),
            Text(
              DateFormat('MMM d, yyyy • h:mm a').format(date),
              style: AppTypography.caption.copyWith(
                color: isMine ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
          if (desc.isNotEmpty) ...[
            SizedBox(height: 4.resH),
            Text(
              desc,
              style: AppTypography.caption.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
          SizedBox(height: 4.resH),
          footer,
        ],
      ),
    );
  }
}
