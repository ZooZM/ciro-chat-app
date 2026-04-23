import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';

class VoiceNoteController {
  static final VoiceNoteController _instance = VoiceNoteController._internal();
  factory VoiceNoteController() => _instance;
  VoiceNoteController._internal();

  PlayerController? _currentPlayer;
  String? _currentlyPlayingId;

  final ValueNotifier<String?> currentlyPlayingIdNotifier = ValueNotifier(null);

  void play(String messageId, PlayerController controller) async {
    if (_currentlyPlayingId != null && _currentlyPlayingId != messageId) {
      try {
        if (_currentPlayer?.playerState.isPlaying ?? false) {
          await _currentPlayer?.pausePlayer();
        }
      } catch (e) {
        debugPrint('Error pausing previous player: $e');
      }
    }
    _currentPlayer = controller;
    _currentlyPlayingId = messageId;
    currentlyPlayingIdNotifier.value = messageId;
    
    try {
      await controller.setFinishMode(finishMode: FinishMode.pause);
      await controller.startPlayer();
    } catch (e) {
      debugPrint('Error starting player: $e');
      _currentlyPlayingId = null;
      currentlyPlayingIdNotifier.value = null;
    }
  }

  void stopCurrent() async {
    try {
      if (_currentPlayer?.playerState.isPlaying ?? false) {
        await _currentPlayer?.pausePlayer();
      }
    } catch (e) {
      debugPrint('Error stopping current player: $e');
    } finally {
      _currentPlayer = null;
      _currentlyPlayingId = null;
      currentlyPlayingIdNotifier.value = null;
    }
  }
}
