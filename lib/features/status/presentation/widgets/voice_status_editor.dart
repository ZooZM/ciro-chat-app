import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_creation_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/waveform_visualizer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class VoiceStatusEditor extends StatefulWidget {
  const VoiceStatusEditor({super.key});

  @override
  State<VoiceStatusEditor> createState() => _VoiceStatusEditorState();
}

class _VoiceStatusEditorState extends State<VoiceStatusEditor> {
  Timer? _timer;
  int _recordDuration = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _recordedPath;

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _recordDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
      if (_recordDuration >= AppConstants.statusMaxVoiceDuration.inSeconds) {
        _stopRecording();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _startRecording() async {
    final cubit = context.read<StatusCreationCubit>();
    await cubit.startRecording();
    setState(() {
      _recordedPath = null;
    });
    _startTimer();
  }

  void _stopRecording() async {
    _timer?.cancel();
    final cubit = context.read<StatusCreationCubit>();
    final path = await cubit.stopRecording();
    setState(() {
      _recordedPath = path;
    });
  }

  void _togglePlayback() async {
    if (_recordedPath == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_audioPlayer.processingState == ProcessingState.completed || _audioPlayer.processingState == ProcessingState.idle) {
        await _audioPlayer.setFilePath(_recordedPath!);
      }
      _audioPlayer.play();
      setState(() => _isPlaying = true);

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<StatusCreationCubit>();
    final isRecording = cubit.isRecording;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          if (isRecording)
            WaveformVisualizer(
              controller: cubit.recorderController,
              isRecording: isRecording,
            )
          else if (_recordedPath != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  color: Colors.white,
                  iconSize: 48,
                  onPressed: _togglePlayback,
                ),
                Text('status.preview'.tr(), style: const TextStyle(color: Colors.white)),
              ],
            )
          else
            const SizedBox(height: AppConstants.waveformHeight),
          const SizedBox(height: AppConstants.spacingXxl),
          GestureDetector(
            onTap: isRecording ? _stopRecording : _startRecording,
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spacingXl),
              decoration: BoxDecoration(
                color: isRecording ? Colors.red.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: isRecording ? Colors.red : AppColors.primary,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            isRecording ? 'status.tap_to_stop'.tr() : 'status.tap_to_record'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
