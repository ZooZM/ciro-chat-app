import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:ciro_chat_app/core/services/call_audio_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioSession extends Mock implements AudioSession {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const AudioSessionConfiguration());
  });

  late _MockAudioSession session;
  late StreamController<AudioInterruptionEvent> interruptions;
  late CallAudioSessionService service;
  late List<bool> setActiveCalls;

  setUp(() {
    session = _MockAudioSession();
    interruptions = StreamController<AudioInterruptionEvent>.broadcast();
    setActiveCalls = [];

    when(() => session.configure(any())).thenAnswer((_) async {});
    when(() => session.interruptionEventStream)
        .thenAnswer((_) => interruptions.stream);
    when(() => session.setActive(any())).thenAnswer((invocation) async {
      setActiveCalls.add(invocation.positionalArguments.first as bool);
      return true;
    });

    service = CallAudioSessionService()
      ..audioSessionResolver = (() async => session);
  });

  tearDown(() => interruptions.close());

  group('configureForCall', () {
    test('configures voice-communication session and activates it before ready '
        '(FR-Audio-01, SC-003)', () async {
      await service.configureForCall();

      final config = verify(() => session.configure(captureAny()))
          .captured
          .single as AudioSessionConfiguration;

      // iOS: voiceChat mode (FR-Audio-01)
      expect(config.avAudioSessionMode, AVAudioSessionMode.voiceChat);
      expect(config.avAudioSessionCategory,
          AVAudioSessionCategory.playAndRecord);
      // Android: voiceCommunication usage (FR-Audio-01)
      expect(config.androidAudioAttributes?.usage,
          AndroidAudioUsage.voiceCommunication);
      expect(config.androidAudioAttributes?.contentType,
          AndroidAudioContentType.speech);

      expect(setActiveCalls, contains(true));
    });

    test('swallows configuration failures and never throws '
        '(Constitution §VII)', () async {
      when(() => session.configure(any())).thenThrow(Exception('boom'));

      await expectLater(service.configureForCall(), completes);
    });

    test('re-asserts the session when an interruption ends (FR-Audio-06)',
        () async {
      await service.configureForCall();
      setActiveCalls.clear();

      interruptions.add(AudioInterruptionEvent(false, AudioInterruptionType.pause));
      await Future<void>.delayed(Duration.zero);

      expect(setActiveCalls, contains(true));
    });
  });

  group('deactivate', () {
    test('cancels the interruption subscription so no handling fires afterward '
        '(Constitution §V)', () async {
      await service.configureForCall();
      await service.deactivate();

      expect(interruptions.hasListener, isFalse);

      // Any event after deactivate must NOT trigger further re-activation.
      setActiveCalls.clear();
      interruptions.add(AudioInterruptionEvent(false, AudioInterruptionType.pause));
      await Future<void>.delayed(Duration.zero);
      expect(setActiveCalls, isEmpty);
    });

    test('deactivates the session and swallows failures', () async {
      await service.configureForCall();
      when(() => session.setActive(any())).thenThrow(Exception('boom'));

      await expectLater(service.deactivate(), completes);
    });
  });
}
