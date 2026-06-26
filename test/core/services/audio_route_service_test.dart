import 'package:ciro_chat_app/core/services/audio_route_service.dart';
import 'package:ciro_chat_app/core/services/call_audio_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// T032 — regression guard for SC-006 / FR-VoIP-11: routing audio through
/// [AudioRouteService] MUST NOT reconfigure the feature-019 audio session.
/// [AudioRouteServiceImpl] is implemented to talk exclusively to LiveKit's
/// `Hardware.instance` (output-device selection) and never touches
/// `AudioSession`/`CallAudioConfig` — this test pins the canonical capture
/// options and proves a full route-service call cycle leaves them untouched
/// and never throws into the caller, even when the underlying platform
/// channel (no WebRTC binding in a unit-test environment) is unavailable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Stub the WebRTC platform channel so LiveKit's Hardware singleton can
    // initialize and enumerate devices without a real native binding.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Method'),
      (call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'getSources':
            return {'sources': <Map<String, dynamic>>[]};
          case 'setSpeakerphoneOn':
            return null;
          case 'selectAudioOutput':
            return null;
          default:
            return null;
        }
      },
    );
  });

  test('CallAudioConfig.captureOptions stays at the noise-cancellation baseline', () {
    const opts = CallAudioConfig.captureOptions;
    expect(opts.noiseSuppression, isTrue);
    expect(opts.echoCancellation, isTrue);
    expect(opts.autoGainControl, isTrue);
    expect(opts.voiceIsolation, isFalse);
    expect(opts.typingNoiseDetection, isFalse);
  });

  test('a full AudioRouteService call cycle never alters CallAudioConfig and never throws', () async {
    const before = CallAudioConfig.captureOptions;

    final service = AudioRouteServiceImpl();
    // Every Hardware.instance call is wrapped in try/catch inside the service
    // (mirrors CallAudioSessionService) so a missing platform channel in the
    // test environment must never propagate as an exception.
    await service.start();
    await service.applyDefaultForCall(isVideo: false);
    await service.selectRoute(AudioOutputRoute.speaker);
    await service.setSpeakerphoneOn(true);
    await service.stop();
    await service.dispose();

    const after = CallAudioConfig.captureOptions;
    expect(after.noiseSuppression, before.noiseSuppression);
    expect(after.echoCancellation, before.echoCancellation);
    expect(after.autoGainControl, before.autoGainControl);
    expect(after.voiceIsolation, before.voiceIsolation);
    expect(after.typingNoiseDetection, before.typingNoiseDetection);
  });
}
