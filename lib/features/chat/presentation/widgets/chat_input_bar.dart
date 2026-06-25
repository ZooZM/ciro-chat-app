import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ciro_chat_app/core/helpers/permission_service.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatInputBar extends StatefulWidget {
  final VoidCallback onAttachmentTap;
  final Function(String) onSendText;

  /// Pre-fills the input as an editable draft (e.g. the map's "invite to
  /// share location" flow) rather than auto-sending it.
  final String? initialText;

  const ChatInputBar({
    Key? key,
    required this.onAttachmentTap,
    required this.onSendText,
    this.initialText,
  }) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _msgController;
  late final RecorderController _recorderController;

  bool _isTextEmpty = true;
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  bool _isSendingVoiceNote = false;
  int _recordDuration = 0;
  Timer? _timer;

  // Stored so Android's stop() null-return edge case has a fallback path.
  String? _currentRecordingPath;

  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    _msgController = TextEditingController(text: widget.initialText ?? '');
    _isTextEmpty = _msgController.text.trim().isEmpty;

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
      final granted = await PermissionService.requestSingle(Permission.microphone);
      if (!mounted) return;

      if (!granted) {
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
      // Store path as field — Android's stop() can return null in edge cases.
      _currentRecordingPath = filePath;

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
    final savedPath = _currentRecordingPath;
    _currentRecordingPath = null;
    try {
      final stoppedPath = await _recorderController.stop();
      final resolvedPath = stoppedPath ?? savedPath;
      debugPrint('[ChatInputBar] Cancel: stoppedPath=$stoppedPath savedPath=$savedPath resolved=$resolvedPath');
      if (resolvedPath != null && File(resolvedPath).existsSync()) {
        File(resolvedPath).deleteSync();
        debugPrint('[ChatInputBar] Cancelled recording deleted: $resolvedPath');
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
    if (!_isRecording || _isSendingVoiceNote) return;
    _isSendingVoiceNote = true;
    _timer?.cancel();

    // Capture path and duration before any state changes.
    final savedPath = _currentRecordingPath;
    _currentRecordingPath = null;
    final duration = _recordDuration;

    // Remove AudioWaveforms from the tree BEFORE stopping the native recorder —
    // the waveform widget crashes if it reads from an already-stopped recorder.
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _recordDuration = 0;
      });
    }

    try {
      debugPrint('[ChatInputBar] Calling recorderController.stop()... (savedPath=$savedPath)');
      String? stoppedPath;
      try {
        // Android bug: stop() can hang indefinitely. Add 5s timeout.
        stoppedPath = await _recorderController.stop().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[ChatInputBar] recorderController.stop() timed out after 5s — using savedPath');
            return null;
          },
        );
      } catch (e, stack) {
        debugPrint('[ChatInputBar] recorderController.stop() threw: $e\n$stack');
      }

      // Android edge case: stop() can return null even though the file was
      // written successfully. Fall back to the path stored at record-start.
      final path = stoppedPath ?? savedPath;
      debugPrint('[ChatInputBar] stoppedPath=$stoppedPath  savedPath=$savedPath  resolvedPath=$path');

      if (path == null) {
        debugPrint('[ChatInputBar] ERROR: resolved path is null — cannot send voice note.');
        return;
      }

      final fileExists = File(path).existsSync();
      debugPrint('[ChatInputBar] File.existsSync($path) = $fileExists');
      if (!fileExists) {
        debugPrint('[ChatInputBar] ERROR: recorded file does not exist at $path');
        return;
      }

      final fileSize = File(path).lengthSync();
      debugPrint('[ChatInputBar] File size: $fileSize bytes  duration: $duration s');

      if (duration <= 0) {
        debugPrint('[ChatInputBar] Duration is 0, discarding recording.');
        try { File(path).deleteSync(); } catch (_) {}
        return;
      }

      // ── Waveform extraction (best-effort; failures must NOT block send) ──────
      List<double> waveformSamples = [];
      // Android: PlayerController cannot access private app directory paths.
      // Skip waveform extraction on Android to avoid PlatformException.
      // Waveform is cosmetic only; message sends fine without it.
      if (!defaultTargetPlatform.name.contains('android')) {
        final tmpController = PlayerController();
        try {
          debugPrint('[ChatInputBar] Preparing player for waveform extraction...');
          await tmpController.preparePlayer(
            path: path,
            shouldExtractWaveform: true,
            noOfSamples: 50,
          );
          debugPrint('[ChatInputBar] Player prepared. Extracting waveform data...');
          waveformSamples = await tmpController.waveformExtraction
              .extractWaveformData(path: path, noOfSamples: 50);
          debugPrint('[ChatInputBar] Waveform extraction succeeded: ${waveformSamples.length} samples');
        } catch (e, stack) {
          debugPrint('[ChatInputBar] Waveform extraction failed (non-fatal): $e\n$stack');
        } finally {
          // Dispose in its own try-catch — a dispose failure on Android must NOT
          // propagate and prevent sendVoiceNote from being called.
          try {
            tmpController.dispose();
          } catch (e) {
            debugPrint('[ChatInputBar] tmpController.dispose() failed (ignored): $e');
          }
        }
      } else {
        debugPrint('[ChatInputBar] Skipping waveform extraction on Android (file path inaccessible)');
      }

      // ── Send ─────────────────────────────────────────────────────────────────
      debugPrint('[ChatInputBar] Calling sendVoiceNote with path=$path  duration=$duration  samples=${waveformSamples.length}');
      if (mounted) {
        context.read<ChatCubit>().sendVoiceNote(
          context,
          path,
          durationSeconds: duration,
          waveformSamples: waveformSamples,
        );
        debugPrint('[ChatInputBar] sendVoiceNote dispatched successfully.');
      } else {
        debugPrint('[ChatInputBar] Widget unmounted before sendVoiceNote — message not sent.');
      }
    } catch (e, stack) {
      debugPrint('[ChatInputBar] _stopAndSendRecording unexpected error: $e\n$stack');
    } finally {
      _isSendingVoiceNote = false;
    }
  }

  void _onSendText() {
    if (_isRecording || _isRecordingLocked) return;
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
