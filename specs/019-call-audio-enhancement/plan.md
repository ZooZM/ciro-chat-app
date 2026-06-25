# Implementation Plan: Call Audio Enhancement & Noise Cancellation (Frontend)

**Branch**: `019-call-audio-enhancement` (spec authored on `018-snap-map-realtime`; no separate branch) | **Date**: 2026-06-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/019-call-audio-enhancement/spec.md`

## Summary

Make every LiveKit call publish a **clean local microphone track** so the Google-STT live-translation pipeline (feature 015) transcribes accurately and participants hear each other clearly — using only built-in WebRTC filters and OS-level voice-communication audio sessions (zero-cost, zero-latency, no Krisp/AI SDK).

Technical approach (from codebase audit + research):
- **Single source of truth**: today four call sites each build their own `Room`/`RoomOptions` and rely on LiveKit's *defaults* — [livekit_video_call_repository_impl.dart:70](../../lib/features/video_call/data/repositories/livekit_video_call_repository_impl.dart#L70), [voice_call_screen.dart:59](../../lib/features/video_call/presentation/pages/voice_call_screen.dart#L59) (a bare `Room()` with **no** `RoomOptions` at all), [video_call_screen.dart:132](../../lib/features/video_call/presentation/pages/video_call_screen.dart#L132), and [group_call_screen.dart:177](../../lib/features/video_call/presentation/pages/group_call_screen.dart#L177). Introduce one `CallAudioConfig` (canonical `AudioCaptureOptions` + a `RoomOptions` factory) in `core/` and have all four sites use it (FR-Audio-05).
- **WebRTC filters (FR-Audio-02)**: pass an explicit `AudioCaptureOptions(noiseSuppression: true, echoCancellation: true, autoGainControl: true)` as `RoomOptions.defaultAudioCaptureOptions`. **Critically**, also set `voiceIsolation: false` (and `typingNoiseDetection: false`): livekit_client 2.7 defaults these to `true`, and Apple Voice Isolation is exactly the kind of aggressive AI processing the spec warns against — it can strip consonants and degrade STT (SC-002). This keeps suppression on the WebRTC/OS path only.
- **OS audio session (FR-Audio-01)**: configure the `audio_session` package (already a dependency, currently unused) **before** `room.connect()` with a voice-communication profile — iOS `AVAudioSessionCategory.playAndRecord` + `AVAudioSessionMode.voiceChat`; Android `AndroidAudioUsage.voiceCommunication` + speech content type. Wrap this in a `CallAudioSessionService` (core singleton) invoked at the start of each `_connectToRoom`.
- **Conflict avoidance**: LiveKit already auto-manages the iOS session via `onConfigureNativeAudio` (its default is already `voiceChat`/`videoChat`). Our explicit `audio_session` config and LiveKit's are aligned (both voiceChat/playAndRecord), so they cooperate rather than fight; the service re-asserts the session on interruption/route-change and reconnect (FR-Audio-06) and we keep LiveKit's automatic configuration enabled.
- **Zero-cost / zero-latency (FR-Audio-03/04)**: no new packages; only `livekit_client` filters + `audio_session` OS configuration. No external processing stage, so no added latency.
- **No UI / no toggle (FR-Audio-07)**: enhancement is applied unconditionally at connect time; no settings surface.

## Technical Context

**Language/Version**: Dart 3 / Flutter (stable)
**Primary Dependencies**: `livekit_client: ^2.6.4` (resolved 2.7.0) — `RoomOptions`, `AudioCaptureOptions`, `Hardware`, `NativeAudioConfiguration`; `audio_session: ^0.2.3` (already in `pubspec.yaml`, not yet used); `permission_handler` (mic permission, already wired via `PermissionService`); `get_it`/`injectable` (DI for the new core service).
**Storage**: N/A — no persistence. Audio config is ephemeral per-call; no SQLite/SharedPreferences/SecureStorage involved.
**Testing**: `flutter_test` + `mocktail` — unit tests for `CallAudioConfig` (asserts the exact filter flags) and `CallAudioSessionService` (asserts the voice-communication configuration is requested before connect); widget/integration smoke where feasible.
**Target Platform**: iOS 15+ / Android (mobile).
**Project Type**: Mobile app (Flutter, Clean Architecture) atop existing LiveKit call feature.
**Performance Goals**: No perceptible added end-to-end audio latency vs. baseline (SC-006); no regression in STT/translation accuracy (SC-002).
**Constraints**: Zero-cost — built-in WebRTC + OS only, no Krisp/AI SDK (FR-Audio-03, SC-005); session configured **before** local track publish on 100% of calls (FR-Audio-01, SC-003); explicit filter flags, with `voiceIsolation` disabled to avoid over-filtering; applies to every mic-publishing surface (FR-Audio-05); resilient to interruption/route-change/reconnect (FR-Audio-06); no user toggle (FR-Audio-07).
**Scale/Scope**: One small `core/` config + service, applied at four existing call-connect sites (1:1 voice, 1:1 video, group, and the repository path used by avatar calls). No backend changes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Audio enhancement is a cross-cutting infrastructure concern, not a feature domain — `CallAudioConfig` (constants/factory) and `CallAudioSessionService` live in `lib/core/services/` alongside existing singletons. No new domain/data layers needed (no entities, no persistence). Call screens (presentation) and the existing video-call repository (data) consume them. ✅
- [x] **II. State Management**: No new Cubit/state — this configures the media stack at connect time. Existing call cubits/screens are unchanged except for the connect call. ✅
- [x] **III. Offline-First / Storage**: No data stored. Real-time audio config is volatile; no SQLite/Hive/SharedPreferences. (Hive not introduced.) ✅
- [x] **IV. Socket.IO**: No socket events involved; audio is LiveKit/WebRTC media, not Socket.IO. ✅
- [x] **V. Teardown**: `CallAudioSessionService` deactivates / relinquishes the audio session and cancels its interruption-event subscription when the call ends; no leaked subscriptions. ✅
- [x] **VI. Code Quality**: snake_case files (`call_audio_config.dart`, `call_audio_session_service.dart`), `const` `AudioCaptureOptions`, `final` fields, comments only for the non-obvious `voiceIsolation: false` rationale. ✅
- [x] **VII. Error Handling**: Audio-session configuration is best-effort — failures are logged via `debugPrint` and MUST NOT block joining the call or throw into the UI (Constitution VII "Silent Failures" for fire-and-forget). No `Failure`/`Either` needed since there is no repository boundary. ✅

**Result: PASS** — no violations; Complexity Tracking not required.

## Project Structure

### Documentation (this feature)

```text
specs/019-call-audio-enhancement/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (config value objects — no DB)
├── quickstart.md        # Phase 1 output
└── contracts/
    └── audio-configuration.md   # Canonical config + integration-point contract
```

### Source Code (repository root)

```text
lib/
├── core/
│   └── services/
│       ├── call_audio_config.dart          # NEW: canonical AudioCaptureOptions + RoomOptions factory
│       └── call_audio_session_service.dart  # NEW: audio_session voice-comm config + lifecycle
└── features/
    └── video_call/
        ├── data/repositories/
        │   └── livekit_video_call_repository_impl.dart   # use CallAudioConfig.roomOptions(); configure session before connect
        └── presentation/pages/
            ├── voice_call_screen.dart        # add RoomOptions (currently none) + session config
            ├── video_call_screen.dart        # use CallAudioConfig + session config
            └── group_call_screen.dart        # use CallAudioConfig + session config

test/
└── core/services/
    ├── call_audio_config_test.dart
    └── call_audio_session_service_test.dart
```

**Structure Decision**: Mobile-app Clean Architecture (per Constitution §I). Because audio enhancement is cross-cutting infrastructure with no domain model, it is implemented as two `core/services/` units and consumed at the four existing LiveKit connect sites — mirroring how `SocketService`, `PermissionService`, and `TokenRefreshService` already live in `core/`.

## Complexity Tracking

> No Constitution violations — not applicable.
