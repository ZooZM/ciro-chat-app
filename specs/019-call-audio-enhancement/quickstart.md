# Quickstart: Call Audio Enhancement & Noise Cancellation

How a developer implements and verifies this feature. No new packages required —
`livekit_client` and `audio_session` are already in `pubspec.yaml`.

## 1. Add the canonical config (`core/`)

Create `lib/core/services/call_audio_config.dart` — see [contract C1](./contracts/audio-configuration.md#c1--canonical-capture-options-single-source-of-truth).
Key point: NS/AEC/AGC `true`, `voiceIsolation` **`false`** (protects STT, SC-002).

## 2. Add the audio-session service (`core/`)

Create `lib/core/services/call_audio_session_service.dart` as a `@lazySingleton` — see
[contract C2](./contracts/audio-configuration.md#c2--audio-session-service). Sketch:

```dart
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
  avAudioSessionMode: AVAudioSessionMode.voiceChat,
  avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
      AVAudioSessionCategoryOptions.defaultToSpeaker,
  androidAudioAttributes: AndroidAudioAttributes(
    contentType: AndroidAudioContentType.speech,
    usage: AndroidAudioUsage.voiceCommunication,
  ),
  androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
));
await session.setActive(true);
```

Subscribe to `session.interruptionEventStream` and re-activate on interruption end.
Wrap everything in try/catch + `debugPrint` — never throw into the call flow.

Register it in DI (`injectable`) and regenerate (`dart run build_runner build`).

## 3. Wire the four connect sites

For each site in [contract C3](./contracts/audio-configuration.md#c3--integration-points-every-mic-publishing-surface):

```dart
await getIt<CallAudioSessionService>().configureForCall();   // BEFORE connect (SC-003)
_room = Room(roomOptions: CallAudioConfig.roomOptions());
await _room!.connect(url, token);
await _room!.localParticipant?.setMicrophoneEnabled(true);   // unchanged
```

Add `await getIt<CallAudioSessionService>().deactivate();` to each call's teardown
(`dispose`/leave).

## 4. Tests

```bash
flutter test test/core/services/call_audio_config_test.dart
flutter test test/core/services/call_audio_session_service_test.dart
```

- `call_audio_config_test.dart`: assert `captureOptions.noiseSuppression == true`,
  `echoCancellation == true`, `autoGainControl == true`, `voiceIsolation == false`.
- `call_audio_session_service_test.dart`: with a mocked `AudioSession`, assert
  `configure` is called with `voiceChat` / `voiceCommunication` and `setActive(true)`
  before the service reports ready; assert failures are swallowed (no throw).

## 5. Manual verification (Success Criteria)

1. **Noise/echo (SC-001/004)**: join a 1:1 voice call from a noisy room on speaker; a
   second participant confirms background noise is suppressed and no echo returns.
2. **STT accuracy (SC-002)**: with feature 015 captions on, read a consonant-heavy
   phrase set in a quiet room with the build before vs after this change; confirm
   translated captions are no less accurate.
3. **Session-before-publish (SC-003)**: add a temporary log in `configureForCall()` and
   confirm it logs before LiveKit publishes the mic track on all four surfaces.
4. **No paid SDK (SC-005)**: `grep -i krisp pubspec.yaml pubspec.lock` returns nothing.
5. **Parity (SC-007)**: repeat step 1 on both an iOS and an Android device.
6. **No added latency (SC-006 / FR-Audio-04)**: compare end-to-end audio latency on a build with this configuration vs. a baseline build without it (e.g., mouth-to-ear timing or round-trip clap test). Confirm there is no perceptible increase and that the path adds no extra buffering/processing stage (only the in-pipeline WebRTC/OS filters are used — no external processor).

## Gotchas

- Don't leave `voiceIsolation` at its `true` default — it over-filters and hurts STT.
- Configure the session **before** `connect`, not after.
- Keep LiveKit's automatic audio configuration enabled; our `audio_session` profile is
  intentionally aligned (voiceChat/playAndRecord) so they don't fight.
- `voice_call_screen.dart` currently has **no** `RoomOptions` — easy to miss.
