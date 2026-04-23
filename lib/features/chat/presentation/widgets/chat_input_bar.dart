import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatInputBar extends StatefulWidget {
  final VoidCallback onAttachmentTap;
  final Function(String) onSendText;

  const ChatInputBar({
    Key? key,
    required this.onAttachmentTap,
    required this.onSendText,
  }) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _msgController = TextEditingController();
  late final RecorderController _recorderController;

  bool _isTextEmpty = true;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();

    _msgController.addListener(() {
      final isEmpty = _msgController.text.trim().isEmpty;
      if (_isTextEmpty != isEmpty) {
        setState(() {
          _isTextEmpty = isEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorderController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  // ── Recording Flow ────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorderController.record(path: filePath);
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
      });
    } catch (e) {
      debugPrint('[ChatInputBar] Start recording failed: $e');
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    try {
      final path = await _recorderController.stop();
      if (path != null && File(path).existsSync()) {
        File(path).deleteSync();
      }
    } catch (e) {
      debugPrint('[ChatInputBar] Cancel recording failed: $e');
    }
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    try {
      final path = await _recorderController.stop();
      final duration = _recordDuration;
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      if (path != null && File(path).existsSync()) {
        if (duration > 0) {
          if (mounted) {
            context.read<ChatCubit>().sendVoiceNote(
                  context,
                  path,
                  durationSeconds: duration,
                );
          }
        } else {
          File(path).deleteSync(); // Too short
        }
      }
    } catch (e) {
      debugPrint('[ChatInputBar] Stop recording failed: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _onSendText() {
    final text = _msgController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text);
      _msgController.clear();
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8.resW,
        vertical: 8.resH,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left Attachment Button
            if (!_isRecording)
              Padding(
                padding: EdgeInsets.only(bottom: 4.resH),
                child: IconButton(
                  icon: Icon(
                    Icons.add,
                    color: AppColors.textSecondary,
                    size: 28.resW,
                  ),
                  onPressed: widget.onAttachmentTap,
                ),
              ),

            // Middle: TextField OR Recording UI
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 4.resH),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.resR),
                  border: Border.all(
                    color: _isRecording ? Colors.red : AppColors.divider,
                    width: 1.5.resW,
                  ),
                ),
                child: _isRecording ? _buildRecordingUi() : _buildTextFieldUi(),
              ),
            ),

            SizedBox(width: 8.resW),

            // Right Button: Send Text OR Mic
            Padding(
              padding: EdgeInsets.only(bottom: 10.resH),
              child: _isRecording
                  ? const SizedBox.shrink()
                  : _isTextEmpty
                      ? _buildMicButton()
                      : _buildSendButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldUi() {
    return Row(
      children: [
        SizedBox(width: 16.resW),
        Expanded(
          child: TextField(
            controller: _msgController,
            maxLines: 5,
            minLines: 1,
            style: AppTypography.body1.copyWith(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: AppTypography.body1.copyWith(
                color: AppColors.textHint,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12.resH),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.camera_alt_outlined,
            color: AppColors.textSecondary,
            size: 24.resW,
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildRecordingUi() {
    return Row(
      children: [
        SizedBox(width: 16.resW),
        // Pulsing Red Dot & Timer
        Icon(Icons.mic, color: Colors.red, size: 20.resW),
        SizedBox(width: 8.resW),
        Text(
          _formatDuration(_recordDuration),
          style: AppTypography.body1.copyWith(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 8.resW),
        // Live Waveform
        Expanded(
          child: AudioWaveforms(
            enableGesture: false,
            size: Size(double.infinity, 30.resH),
            recorderController: _recorderController,
            waveStyle: WaveStyle(
              waveColor: AppColors.primary,
              extendWaveform: true,
              showMiddleLine: false,
              waveCap: StrokeCap.round,
              waveThickness: 2.resW,
            ),
          ),
        ),
        // Slide to cancel hint
        Padding(
          padding: EdgeInsets.only(right: 16.resW),
          child: Text(
            '< Slide to cancel',
            style: AppTypography.caption.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopAndSendRecording(),
      onLongPressMoveUpdate: (details) {
        if (details.offsetFromOrigin.dx < -100) {
          _cancelRecording();
        }
      },
      child: Container(
        width: 48.resW,
        height: 48.resW,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic,
          color: Colors.white,
          size: 24.resW,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _onSendText,
      child: Container(
        width: 48.resW,
        height: 48.resW,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send,
          color: Colors.white,
          size: 22.resW,
        ),
      ),
    );
  }
}
