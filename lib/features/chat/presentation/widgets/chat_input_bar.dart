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
  bool _isRecordingLocked = false;
  int _recordDuration = 0;
  Timer? _timer;

  Timer? _typingTimer;

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

      // Debounced typing indicator emission
      context.read<ChatCubit>().notifyTyping(isTyping: true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          context.read<ChatCubit>().notifyTyping(isTyping: false);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      // Best-effort stop before disposing to release native resources
      _recorderController.stop().catchError((_) => null);
    }
    _recorderController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  // ── Recording Flow ────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    debugPrint('[ChatInputBar] _startRecording initiated...');
    try {
      final hasPermission = await _recorderController.checkPermission();
      if (!mounted) return;

      if (!hasPermission) {
        debugPrint('[ChatInputBar] Microphone permission denied.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      debugPrint(
        '[ChatInputBar] Starting audio_waveforms record to $filePath...',
      );
      await _recorderController.record(path: filePath);

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordDuration++;
          });
        }
      });
      debugPrint('[ChatInputBar] Recording started successfully.');
    } catch (e, stack) {
      debugPrint('[ChatInputBar] Start recording failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
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
      _isRecordingLocked = false;
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
        _isRecordingLocked = false;
        _recordDuration = 0;
      });

      if (path != null && File(path).existsSync()) {
        if (duration > 0) {
          // T143: Extract waveform at record-time (sender side) so receiver
          // never needs to re-extract (FR-025).
          List<double> waveformSamples = [];
          try {
            final tmpController = PlayerController();
            await tmpController.preparePlayer(
              path: path,
              shouldExtractWaveform: true,
              noOfSamples: 50,
            );
            waveformSamples = await tmpController.waveformExtraction
                .extractWaveformData(path: path, noOfSamples: 50);
          } catch (e) {
            debugPrint('[ChatInputBar] Waveform extraction failed: $e');
          }

          if (mounted) {
            context.read<ChatCubit>().sendVoiceNote(
              context,
              path,
              durationSeconds: duration,
              waveformSamples: waveformSamples,
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
      padding: EdgeInsets.symmetric(horizontal: 8.resW, vertical: 8.resH),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left Action
            if (_isRecordingLocked)
              Padding(
                padding: EdgeInsets.only(bottom: 4.resH),
                child: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: AppColors.error,
                    size: 28.resW,
                  ),
                  onPressed: _cancelRecording,
                ),
              )
            else if (!_isRecording)
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24.resR),
                  border: Border.all(
                    color: _isRecording ? AppColors.error : AppColors.divider,
                    width: 1.5.resW,
                  ),
                ),
                child: _isRecording ? _buildRecordingUi() : _buildTextFieldUi(),
              ),
            ),

            SizedBox(width: 8.resW),

            // Right Button
            Padding(
              padding: EdgeInsets.only(bottom: 10.resH),
              child: _isRecordingLocked
                  ? GestureDetector(
                      onTap: _stopAndSendRecording,
                      child: Container(
                        width: 48.resW,
                        height: 48.resW,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send,
                          color: AppColors.surface,
                          size: 24.resW,
                        ),
                      ),
                    )
                  : _isTextEmpty || _isRecording
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
            style: AppTypography.body1.copyWith(color: AppColors.textPrimary),
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
          onPressed: () async {
            await context.read<ChatCubit>().sendCameraMessage(context);
          },
        ),
      ],
    );
  }

  Widget _buildRecordingUi() {
    return Row(
      children: [
        SizedBox(width: 16.resW),
        // Pulsing Red Dot & Timer
        Icon(Icons.mic, color: AppColors.error, size: 20.resW),
        SizedBox(width: 8.resW),
        Text(
          _formatDuration(_recordDuration),
          style: AppTypography.body1.copyWith(
            color: AppColors.error,
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
        if (!_isRecordingLocked)
          Padding(
            padding: EdgeInsets.only(right: 16.resW),
            child: Text(
              '< Slide to cancel',
              style: AppTypography.caption.copyWith(color: AppColors.textHint),
            ),
          )
        else
          SizedBox(width: 16.resW),
      ],
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hold to record, release to send. Swipe up to lock.'),
          ),
        );
      },
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) {
        if (!_isRecordingLocked) {
          debugPrint('[ChatInputBar] Finger released, stopping and sending.');
          _stopAndSendRecording();
        } else {
          debugPrint(
            '[ChatInputBar] Finger released, but recording is locked.',
          );
        }
      },
      onLongPressMoveUpdate: (details) {
        if (details.offsetFromOrigin.dx < -100) {
          debugPrint('[ChatInputBar] Swiped left: cancelling recording.');
          _cancelRecording();
        } else if (details.offsetFromOrigin.dy < -50 && !_isRecordingLocked) {
          debugPrint('[ChatInputBar] Swiped up: locking recording.');
          setState(() {
            _isRecordingLocked = true;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isRecording ? 60.resW : 48.resW,
        height: _isRecording ? 60.resW : 48.resW,
        decoration: BoxDecoration(
          color: _isRecording ? AppColors.error : AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording && !_isRecordingLocked)
              Icon(Icons.lock_outline, color: Colors.white, size: 14.resW),
            Icon(
              Icons.mic,
              color: Colors.white,
              size: _isRecording ? 28.resW : 24.resW,
            ),
          ],
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
        child: Icon(Icons.send, color: AppColors.surface, size: 22.resW),
      ),
    );
  }
}
