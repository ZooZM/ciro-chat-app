# Contract: Call Audio Configuration

This feature exposes no network/API surface. Its "contract" is the **canonical audio
configuration** and the **integration points** every call surface MUST use. Treat this as
the authoritative interface; any new call surface MUST go through it.

## C1 — Canonical capture options (single source of truth)

```dart
// lib/core/services/call_audio_config.dart
abstract final class CallAudioConfig {
  /// Built-in WebRTC filters only — no AI/paid processing (FR-Audio-02, FR-Audio-03).
  /// voiceIsolation/typingNoiseDetection disabled to protect STT accuracy (SC-002).
  static const AudioCaptureOptions captureOptions = AudioCaptureOptions(
    noiseSuppression: true,
    echoCancellation: true,
    autoGainControl: true,
    voiceIsolation: false,
    typingNoiseDetection: false,
  );

  /// RoomOptions every call surface MUST use. Preserves the existing
  /// adaptiveStream / dynacast / iOS broadcast-extension settings.
  static RoomOptions roomOptions() => const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: captureOptions,
        defaultScreenShareCaptureOptions:
            ScreenShareCaptureOptions(useiOSBroadcastExtension: true),
      );
}
```

**Contract guarantees**:
- NS, AEC, AGC are always `true`.
- `voiceIsolation` is always `false`.
- No third-party processor is attached (`processor` left null).

## C2 — Audio session service

```dart
// lib/core/services/call_audio_session_service.dart  (@lazySingleton)
class CallAudioSessionService {
  /// Configure + activate the voice-communication session. MUST be awaited
  /// BEFORE room.connect(). Best-effort: logs and returns on failure, never throws.
  Future<void> configureForCall();

  /// Relinquish the session and cancel the interruption subscription. Call on teardown.
  Future<void> deactivate();
}
```

**Contract guarantees**:
- iOS → `playAndRecord` + `voiceChat`; Android → `voiceCommunication` usage (FR-Audio-01).
- Re-asserts the session when an OS interruption ends (FR-Audio-06).
- Never blocks or fails the call join (Constitution §VII silent-failure rule).

## C3 — Integration points (every mic-publishing surface)

Each site MUST: (1) `await getIt<CallAudioSessionService>().configureForCall();` then
(2) build the room via `CallAudioConfig.roomOptions()`, then (3) `room.connect(...)`.

| # | File | Change |
|---|------|--------|
| 1 | [livekit_video_call_repository_impl.dart:70](../../../lib/features/video_call/data/repositories/livekit_video_call_repository_impl.dart#L70) | replace inline `RoomOptions` with `CallAudioConfig.roomOptions()`; `configureForCall()` before `connect`. Covers **avatar calls** (they use this repo). |
| 2 | [voice_call_screen.dart:59](../../../lib/features/video_call/presentation/pages/voice_call_screen.dart#L59) | bare `Room()` → `Room(roomOptions: CallAudioConfig.roomOptions())`; `configureForCall()` before `connect`. |
| 3 | [video_call_screen.dart:132](../../../lib/features/video_call/presentation/pages/video_call_screen.dart#L132) | inline `RoomOptions` → `CallAudioConfig.roomOptions()`; `configureForCall()` before `connect`. |
| 4 | [group_call_screen.dart:177](../../../lib/features/video_call/presentation/pages/group_call_screen.dart#L177) | inline `RoomOptions` → `CallAudioConfig.roomOptions()`; `configureForCall()` before `connect`. |

Teardown sites (`dispose` / leave) MUST call `deactivate()`.

## C4 — Verification contract (maps to Success Criteria)

| Check | Method | SC |
|-------|--------|----|
| Filters explicitly enabled | unit test asserts `CallAudioConfig.captureOptions` flags | SC-001 |
| Session before publish | code review + test asserts `configureForCall()` awaited before `connect` at all 4 sites | SC-003 |
| No accuracy regression | A/B transcription test (enhancement on vs off, quiet room); enhancement-on WER within **≤2% absolute** of enhancement-off | SC-002 |
| Echo eliminated | manual speaker-mode echo test | SC-004 |
| No paid/AI SDK | `pubspec.yaml` dependency audit (no Krisp etc.) | SC-005 |
| No added latency | baseline vs configured call latency comparison | SC-006 |
| iOS/Android parity | run noisy-env test on both | SC-007 |
