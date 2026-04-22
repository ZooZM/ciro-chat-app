import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/message.dart';

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

  const MessageBubbleWidget({
    Key? key,
    required this.message,
    required this.currentUserId,
  }) : super(key: key);

  bool get _isMine => message.senderId == currentUserId;

  Color get _bgColor =>
      _isMine ? AppColors.surface : const Color(0xFFDFFAC4);

  BorderRadius _borderRadius() {
    final r = Radius.circular(16.resR);
    return BorderRadius.only(
      topLeft: _isMine ? r : Radius.zero,
      topRight: r,
      bottomLeft: r,
      bottomRight: _isMine ? Radius.zero : r,
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.pending:
        return Icon(Icons.access_time, size: 14.resW, color: AppColors.textSecondary);
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14.resW, color: AppColors.textSecondary);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14.resW, color: AppColors.textSecondary);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14.resW, color: Colors.blue);
      case MessageStatus.error:
        return Icon(Icons.error_outline, size: 14.resW, color: Colors.red);
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
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _ImageBubble(message: message, isMine: _isMine, footer: _buildFooter());
      case MessageType.file:
        return _FileBubble(message: message, isMine: _isMine, footer: _buildFooter());
      case MessageType.voiceNote:
        return _VoiceBubble(message: message, isMine: _isMine, footer: _buildFooter());
      case MessageType.contact:
        return _ContactBubble(message: message, isMine: _isMine, footer: _buildFooter());
      case MessageType.text:
      default:
        return _TextBubble(message: message, isMine: _isMine, footer: _buildFooter());
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
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: AppTypography.body1.copyWith(color: Colors.black),
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
    final url = _resolveUrl(message.fileUrl);
    final isUploading = url.isEmpty;

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.resR),
          child: isUploading
              ? _UploadingPlaceholder()
              : GestureDetector(
                  onTap: () => _openImageViewer(context, url),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: 220.resW,
                    height: 180.resH,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _UploadingPlaceholder(),
                    errorWidget: (_, __, ___) => Container(
                      width: 220.resW,
                      height: 180.resH,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
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

  void _openImageViewer(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImageViewer(url: url),
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
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8.resH),
            Text(
              'Uploading…',
              style: AppTypography.caption.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  const _FullScreenImageViewer({required this.url});

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
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
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
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                        color: Colors.black87,
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
  late final AudioPlayer _player;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = _resolveUrl(widget.message.fileUrl);
    if (url.isEmpty) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.idle ||
            _player.processingState == ProcessingState.completed) {
          await _player.setUrl(url);
        }
        await _player.play();
      }
    } catch (e) {
      debugPrint('[VoiceBubble] Playback error: $e');
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
    final isUploading =
        widget.message.fileUrl == null || widget.message.fileUrl!.isEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 10.resH),
      child: Column(
        crossAxisAlignment: widget.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play / pause button.
              GestureDetector(
                onTap: isUploading ? null : _toggle,
                child: Container(
                  width: 40.resW,
                  height: 40.resW,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: isUploading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 22.resW,
                        ),
                ),
              ),
              SizedBox(width: 10.resW),
              // Waveform placeholder bar.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.resR),
                      child: StreamBuilder<Duration?>(
                        stream: _player.positionStream,
                        builder: (context, snapshot) {
                          final pos = snapshot.data?.inSeconds ?? 0;
                          final total = duration > 0 ? duration : 1;
                          final progress = (pos / total).clamp(0.0, 1.0);
                          return LinearProgressIndicator(
                            value: isUploading ? null : progress,
                            backgroundColor: Colors.grey.shade300,
                            color: AppColors.primary,
                            minHeight: 4.resH,
                          );
                        },
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
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ContactBubble] Save contact failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save contact'),
            backgroundColor: Colors.red,
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
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                        onLongPress: () => Clipboard.setData(
                          ClipboardData(text: phone),
                        ),
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
          Divider(height: 1, color: Colors.grey.shade200),
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
