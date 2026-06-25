import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Configures the native OS audio session for voice communication before a
/// LiveKit call connects (FR-Audio-01), and re-asserts it after OS
/// interruptions (FR-Audio-06).
///
/// iOS: `playAndRecord` + `voiceChat` mode. Android: `voiceCommunication`
/// usage with `speech` content type. All work is best-effort — failures are
/// logged and swallowed so they never block or crash a call join
/// (Constitution §VII).
@lazySingleton
class CallAudioSessionService {
  AudioSession? _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  @visibleForTesting
  Future<AudioSession> Function() audioSessionResolver =
      () => AudioSession.instance;

  static const AudioSessionConfiguration _voiceCommunicationConfig =
      AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
    avAudioSessionMode: AVAudioSessionMode.voiceChat,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.speech,
      usage: AndroidAudioUsage.voiceCommunication,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
  );

  /// Configure and activate the voice-communication session. MUST be awaited
  /// BEFORE `room.connect()` so the session is ready when the local mic track
  /// publishes (SC-003). Never throws.
  Future<void> configureForCall() async {
    try {
      final session = await audioSessionResolver();
      _session = session;
      await session.configure(_voiceCommunicationConfig);
      await session.setActive(true);
      _listenForInterruptions(session);
    } catch (e) {
      debugPrint('[CallAudioSessionService] configureForCall failed: $e');
    }
  }

  void _listenForInterruptions(AudioSession session) {
    _interruptionSub?.cancel();
    _interruptionSub = session.interruptionEventStream.listen((event) async {
      // Re-assert the voice-communication session once an interruption ends so
      // the call returns to voice mode instead of a media/playback profile.
      if (!event.begin) {
        try {
          await session.setActive(true);
        } catch (e) {
          debugPrint('[CallAudioSessionService] re-activate failed: $e');
        }
      }
    });
  }

  /// Relinquish the session and cancel the interruption subscription. Call from
  /// each call's teardown/dispose so no subscription leaks (Constitution §V).
  Future<void> deactivate() async {
    await _interruptionSub?.cancel();
    _interruptionSub = null;
    try {
      await _session?.setActive(false);
    } catch (e) {
      debugPrint('[CallAudioSessionService] deactivate failed: $e');
    }
    _session = null;
  }
}
