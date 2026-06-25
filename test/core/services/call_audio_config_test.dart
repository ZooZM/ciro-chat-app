import 'package:ciro_chat_app/core/services/call_audio_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CallAudioConfig.captureOptions', () {
    test('enables the three WebRTC filters (FR-Audio-02)', () {
      const opts = CallAudioConfig.captureOptions;
      expect(opts.noiseSuppression, isTrue);
      expect(opts.echoCancellation, isTrue);
      expect(opts.autoGainControl, isTrue);
    });

    test('disables aggressive AI gating to protect STT (FR-Audio-02a)', () {
      const opts = CallAudioConfig.captureOptions;
      expect(opts.voiceIsolation, isFalse);
      expect(opts.typingNoiseDetection, isFalse);
    });

    test('attaches no third-party audio processor (FR-Audio-03)', () {
      expect(CallAudioConfig.captureOptions.processor, isNull);
    });
  });

  group('CallAudioConfig.roomOptions', () {
    test('carries the canonical capture options', () {
      final room = CallAudioConfig.roomOptions();
      final capture = room.defaultAudioCaptureOptions;
      expect(capture.noiseSuppression, isTrue);
      expect(capture.echoCancellation, isTrue);
      expect(capture.autoGainControl, isTrue);
      expect(capture.voiceIsolation, isFalse);
      expect(capture.typingNoiseDetection, isFalse);
    });

    test('preserves existing adaptiveStream / dynacast behaviour', () {
      final room = CallAudioConfig.roomOptions();
      expect(room.adaptiveStream, isTrue);
      expect(room.dynacast, isTrue);
    });
  });
}
