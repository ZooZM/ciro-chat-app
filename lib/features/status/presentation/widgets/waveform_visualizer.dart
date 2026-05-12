import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:flutter/material.dart';

class WaveformVisualizer extends StatelessWidget {
  final RecorderController controller;
  final bool isRecording;

  const WaveformVisualizer({
    super.key,
    required this.controller,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.waveformHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: AudioWaveforms(
        enableGesture: false,
        size: Size(MediaQuery.of(context).size.width - 64, AppConstants.waveformHeight),
        recorderController: controller,
        waveStyle: const WaveStyle(
          waveColor: AppColors.primary,
          extendWaveform: true,
          showMiddleLine: false,
        ),
      ),
    );
  }
}
