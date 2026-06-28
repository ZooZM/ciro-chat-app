import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
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
  State<VoiceStatusEditor> createState() => VoiceStatusEditorState();
}

class VoiceStatusEditorState extends State<VoiceStatusEditor> {
  Timer? _timer;
  int _recordDuration = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _recordedPath;
  String _userInitials = '';

  @override
  void initState() {
    super.initState();
    _loadUserInitials();
  }

  Future<void> _loadUserInitials() async {
    final name = await getIt<AuthCubit>().getCurrentUserName();
    if (!mounted || name == null || name.isEmpty) return;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
    setState(() => _userInitials = initials);
  }

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
        stopRecording();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void startRecording() async {
    final cubit = context.read<StatusCreationCubit>();
    await cubit.startRecording();
    setState(() {
      _recordedPath = null;
    });
    _startTimer();
  }

  void stopRecording() async {
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

    return Stack(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue,
                      child: Text(_userInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic, size: 10, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: isRecording
                      ? WaveformVisualizer(
                          controller: cubit.recorderController,
                          isRecording: isRecording,
                        )
                      : Text(
                          _recordedPath != null ? 'status.preview'.tr() : '.......................................',
                          style: const TextStyle(color: Colors.white70, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                ),
                if (_recordedPath != null)
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    color: Colors.white,
                    onPressed: _togglePlayback,
                  ),
                if (isRecording)
                  Padding(
                    padding: const EdgeInsets.only(left: AppConstants.spacingSm),
                    child: Text(
                      _formatDuration(_recordDuration),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
