import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// FR-032a: Abstracts audio-only (M4A via record) and video (MP4 via
/// flutter_screen_recording) capture. Callers pick [hasVideo]; this service
/// selects the right encoder and output path automatically.
@lazySingleton
class RecordingCaptureService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  bool _hasVideo = false;
  String? _activeFilePath;

  bool get isRecording => _isRecording;

  /// Starts a recording session.
  /// [hasVideo] true  → screen+mic recording (MP4), false → audio only (M4A).
  /// Returns the file path that will be written, or null on failure.
  Future<String?> start({required bool hasVideo}) async {
    if (_isRecording) return _activeFilePath;

    try {
      final dir = await _recordingsDirectory();
      final ext = hasVideo ? 'mp4' : 'm4a';
      final filePath = p.join(dir, '${const Uuid().v4()}.$ext');

      _hasVideo = hasVideo;

      if (hasVideo) {
        // flutter_screen_recording is triggered through the group call screen
        // via platform channel — defer to the caller which has the Activity
        // context needed on Android. We track the path here so stop() can
        // retrieve the file uniformly.
        // The actual startRecordScreenAndAudio call happens in GroupCallScreen
        // before this service is invoked with the resolved path.
        _activeFilePath = filePath;
      } else {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: filePath,
        );
        _activeFilePath = filePath;
      }

      _isRecording = true;
      return filePath;
    } catch (e) {
      debugPrint('[RecordingCaptureService] start failed: $e');
      return null;
    }
  }

  /// Stops the active recording.
  /// Returns the final file path (may differ from [start] path for audio
  /// if the recorder changed it), or null on failure.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    _isRecording = false;

    try {
      if (_hasVideo) {
        // Video stop is triggered by the caller (GroupCallScreen) via platform
        // channel; we just return the tracked path.
        final path = _activeFilePath;
        _activeFilePath = null;
        return path;
      } else {
        final path = await _audioRecorder.stop();
        _activeFilePath = null;
        return path;
      }
    } catch (e) {
      debugPrint('[RecordingCaptureService] stop failed: $e');
      _activeFilePath = null;
      return null;
    }
  }

  Future<void> dispose() async {
    if (_isRecording) await stop();
    await _audioRecorder.dispose();
  }

  Future<String> _recordingsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = '${base.path}/recordings';
    return dir;
  }
}
