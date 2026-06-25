# Phase 0 Research: Call Audio Enhancement & Noise Cancellation

All NEEDS CLARIFICATION items resolved against the live codebase and the resolved
dependency versions (`livekit_client` 2.7.0, `audio_session` 0.2.3).

## R1 — How to enable the WebRTC filters (FR-Audio-02)

**Decision**: Pass an explicit `const AudioCaptureOptions(noiseSuppression: true, echoCancellation: true, autoGainControl: true, voiceIsolation: false, typingNoiseDetection: false)` as `RoomOptions.defaultAudioCaptureOptions`.

**Rationale**:
- `livekit_client` 2.7.0 `AudioCaptureOptions` (`lib/src/track/options.dart`) exposes `noiseSuppression`, `echoCancellation`, `autoGainControl` — these map 1:1 to FR-Audio-02. `RoomOptions.defaultAudioCaptureOptions` is applied when the mic track is published (`core/room.dart` → `setMicrophoneEnabled(true, audioCaptureOptions: roomOptions.defaultAudioCaptureOptions)`).
- The three flags default to `true`, but **the spec requires them set explicitly** (FR-Audio-02) and the current code passes *no* capture options, so the configuration is undocumented/implicit and `voice_call_screen.dart` uses a bare `Room()`. Making it explicit and centralized satisfies the requirement and removes per-site drift.
- **Over-filtering guard (SC-002)**: `AudioCaptureOptions` also defaults `voiceIsolation: true` and `typingNoiseDetection: true`. Apple **Voice Isolation** is an aggressive AI/ML processing mode that can attenuate high-frequency consonants and degrade machine STT — precisely the regression the spec warns against. We set `voiceIsolation: false` and `typingNoiseDetection: false` so only the standard WebRTC/OS noise-suppression, echo-cancellation, and AGC remain. This keeps us on the "zero-cost, non-aggressive" path (FR-Audio-03).

**Alternatives considered**:
- *Rely on LiveKit defaults* (do nothing): rejected — leaves `voiceIsolation` on (over-filters STT), is implicit/undocumented, and `voice_call_screen.dart` has no `RoomOptions` so behavior is inconsistent across surfaces (violates FR-Audio-05).
- *Per-track `setMicrophoneEnabled(true, audioCaptureOptions: …)` at each site*: rejected — duplicative; `RoomOptions.defaultAudioCaptureOptions` applies it once for every publish (including reconnect republish), satisfying FR-Audio-06 for free.

## R2 — How to configure the OS audio session for voice communication (FR-Audio-01)

**Decision**: Use the `audio_session` package (already in `pubspec.yaml`, currently unused) to apply a voice-communication `AudioSessionConfiguration` **before** `room.connect()`, via a new `CallAudioSessionService`:
- iOS: `AVAudioSessionCategory.playAndRecord`, `AVAudioSessionMode.voiceChat`, options allowing Bluetooth.
- Android: `AndroidAudioAttributes(usage: AndroidAudioUsage.voiceCommunication, contentType: AndroidAudioContentType.speech)`.

**Rationale**:
- This is exactly what the spec's FR-Audio-01 prescribes and uses a dependency already present (zero new cost, FR-Audio-03).
- LiveKit 2.7 already manages the iOS session itself through `onConfigureNativeAudio` (`lib/src/track/audio_management.dart`), and its built-in profiles already use `AppleAudioMode.voiceChat` (`NativeAudioConfiguration.playAndRecordReceiver`) / `videoChat`. Our explicit `audio_session` configuration is **aligned** with LiveKit's (same category/mode), so the two cooperate; we leave LiveKit's `Hardware.instance.isAutomaticConfigurationEnabled` at its default (`true`) so LiveKit re-asserts the correct mode as tracks come and go.
- Configuring the session *before* connect satisfies SC-003 (session ready before the local track publishes).

**Alternatives considered**:
- *Rely solely on LiveKit's `onConfigureNativeAudio`*: viable on iOS, but (a) does not satisfy the explicit Android `voiceCommunication` usage requirement as directly, and (b) the spec explicitly names the `audio_session` package. Using `audio_session` gives a single, testable, cross-platform configuration point and also yields the `audio_session` interruption stream for FR-Audio-06.
- *Disable LiveKit auto-config (`setAutomaticConfigurationEnabled(enable: false)`) and manage the session entirely ourselves*: rejected — more code, loses LiveKit's speaker/route handling, and risks regressions in existing call routing/speaker toggles. Only revisit if a real conflict is observed.

## R3 — Interruption, route-change, and reconnect resilience (FR-Audio-06)

**Decision**: `CallAudioSessionService` subscribes to `audio_session`'s `interruptionEventStream` and re-activates the voice-communication session on `InterruptionType.unknown`/`.pause` end events; and the service is (re)invoked at the top of each `_connectToRoom`, so a LiveKit reconnect that rebuilds/republishes also re-applies capture options (via `RoomOptions`) and the session.

**Rationale**: OS interruptions (incoming phone call, Siri) deactivate the session; without re-activation the mic can stay muted or revert to media mode. The `audio_session` package surfaces these events directly. Reconnect republish already re-applies `defaultAudioCaptureOptions` since they live on `RoomOptions`.

**Alternatives considered**: Polling session state — rejected (wasteful, laggy). Ignoring interruptions — rejected (fails FR-Audio-06 edge cases).

## R4 — Coverage across all call surfaces (FR-Audio-05)

**Decision**: Centralize in `CallAudioConfig.roomOptions()` and apply at all four connect sites; avatar calls are covered transitively because they go through `LivekitVideoCallRepositoryImpl.connect`.

**Rationale**: Code audit found exactly four `Room`/`connect` construction points (see plan Summary). `avatar_active_call_screen.dart` does not construct its own `Room` — it relies on the repository path. Covering the repo + the three screens reaches 100% of mic-publishing surfaces.

**Alternatives considered**: A LiveKit middleware/interceptor — not supported by the SDK; centralized factory is the idiomatic equivalent.

## R5 — Latency & cost (FR-Audio-03/04, SC-005/006)

**Decision**: No new packages and no external processing stage. Filters run inside the existing WebRTC audio pipeline (APM) and the OS; the audio_session call only sets a category/mode and adds no per-frame processing.

**Rationale**: WebRTC's built-in NS/AEC/AGC are already in the realtime path; toggling flags does not add a buffer or a network hop. Confirmed there is no Krisp/AI SDK in `pubspec.yaml` (SC-005 verifiable by dependency audit).

## Summary of decisions

| ID | Decision |
|----|----------|
| R1 | Explicit `AudioCaptureOptions` with NS/AEC/AGC = true, `voiceIsolation`/`typingNoiseDetection` = false, via `RoomOptions.defaultAudioCaptureOptions` |
| R2 | `audio_session` voice-communication config (iOS playAndRecord/voiceChat, Android voiceCommunication) before connect, cooperating with LiveKit auto-config |
| R3 | Re-assert session on interruption end + on every connect/reconnect |
| R4 | Centralize in `CallAudioConfig`; apply at repo + 3 screens (covers avatar via repo) |
| R5 | Zero new deps, zero added latency; no AI/paid SDK |
