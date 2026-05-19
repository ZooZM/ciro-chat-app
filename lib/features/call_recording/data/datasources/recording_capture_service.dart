import 'package:flutter/foundation.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

/// Wraps flutter_screen_recording for call capture (screen + mic + system audio).
/// Always produces an MP4 — the output path is returned by [stop].
@lazySingleton
class RecordingCaptureService {
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Starts screen + audio recording. Returns a non-null token on success (the
  /// file name used internally), or null if the platform rejected the request
  /// (permission denied, unsupported, already recording, etc.).
  Future<String?> start() async {
    if (_isRecording) return 'active';
    // Claim the slot synchronously before the first await so a second
    // concurrent call sees the flag and bails out immediately.
    _isRecording = true;

    try {
      final fileName = const Uuid().v4();
      final started = await FlutterScreenRecording.startRecordScreenAndAudio(
        fileName,
        titleNotification: 'Call Recording',
        messageNotification: 'Your group call is being recorded',
      );
      if (!started) {
        _isRecording = false;
        return null;
      }
      return fileName;
    } catch (e) {
      _isRecording = false;
      debugPrint('[RecordingCaptureService] start failed: $e');
      return null;
    }
  }

  /// Stops the recording and returns the saved MP4 file path, or null on error.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    _isRecording = false;

    try {
      final path = await FlutterScreenRecording.stopRecordScreen;
      return path.isEmpty ? null : path;
    } catch (e) {
      debugPrint('[RecordingCaptureService] stop failed: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    if (_isRecording) await stop();
  }
}
