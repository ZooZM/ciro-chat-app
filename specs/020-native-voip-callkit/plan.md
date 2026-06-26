# Implementation Plan: Native VoIP CallKit Integration

**Branch**: `020-native-voip-callkit` | **Date**: 2026-06-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/020-native-voip-callkit/spec.md`

## Summary

Elevate the existing LiveKit-based calling feature to behave like a native system VoIP call:
(1) native lock-screen incoming/outgoing UI for 1:1 calls via `flutter_callkit_incoming`,
(2) background-mode declarations so call audio survives backgrounding,
(3) an in-call **audio-route picker** (Earpiece / Speakerphone / Bluetooth) backed by LiveKit `Hardware.instance`, surfaced through a **speaker icon** button, and
(4) a new in-app **Calls history** screen wired to the already-present "Calls" bottom-nav tab (index 3), recording every call (1:1 + group, voice + video) in `sqflite`.

The work wraps native presentation and audio routing around the current `CallCubit` / LiveKit flow rather than replacing it, and must coexist with the feature-019 `CallAudioSessionService` (voiceChat session with `allowBluetooth`) and `CallAudioConfig` (WebRTC NS/EC/AGC filters) **without degrading noise cancellation**.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (existing app)
**Primary Dependencies**: `livekit_client ^2.6.4`, vendored `flutter_webrtc` fork, `audio_session ^0.2.3`, `flutter_local_notifications ^18.0.1`, `firebase_messaging ^15.2.5`, `permission_handler ^12.0.1`, `flutter_bloc`, `get_it`/`injectable`, `go_router`, `fpdart`, `sqflite`. **NEW**: `flutter_callkit_incoming` (latest stable).
**Storage**: `sqflite` for the call-history table (Constitution §III — offline-first, Hive forbidden). No OS system call-log writes (per clarification).
**Testing**: `flutter_test` + `bloc_test` + `mocktail` (existing patterns under `test/features/`).
**Target Platform**: iOS 15+ and Android (existing minSdk); desktop/web out of scope for native VoIP.
**Project Type**: Mobile app (Flutter, Clean Architecture per Constitution §I).
**Performance Goals**: Native call UI on locked device < 5s (SC-001); route change audible < 1s (SC-004); Calls screen render < 1s for ≤500 records (SC-009).
**Constraints**: Must NOT alter `CallAudioConfig.captureOptions` (voiceIsolation/typingNoiseDetection stay false) or `CallAudioSessionService` category/mode; route changes go through LiveKit `Hardware.instance` so the existing `playAndRecord`/`voiceChat`/`allowBluetooth` session is preserved (FR-VoIP-11). Socket map-safety rule (§IV-A) and teardown rules (§V) apply.
**Scale/Scope**: ~1 new feature module (`call_history`), 2 new core services (`CallKitService`, `AudioRouteService`), edits to `CallCubit`, `voice_call_screen`, `video_call_screen`, `chat_list_screen`, `push_notification_service`, plus platform manifests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: New `call_history` feature is split into `data` (model, sqflite datasource, repo impl), `domain` (entity, repo interface), `presentation` (cubit, page, widgets). Core services (`CallKitService`, `AudioRouteService`) live in `lib/core/services/` like the existing `CallAudioSessionService`.
- [x] **II. State Management**: New `CallHistoryCubit` (Cubit) with `Equatable` states; audio-route state added to `CallActive` via `copyWith` (already Equatable). Constructor injection via `injectable`.
- [x] **III. Offline-First**: Call history persisted in `sqflite` (new `call_history` table); read via stream into the UI. **No Hive** (Constitution §III forbids it — supersedes the plan-template "Hive" wording).
- [x] **IV. Socket.IO**: No new socket events required for routing/CallKit; call-history rows are derived from existing `CallCubit` state transitions. Any payload reads follow §IV-A (`Map<String,dynamic>.from(data)`).
- [x] **V. Teardown**: `AudioRouteService` cancels its device-change subscription on call end; `CallKitService` cancels its event subscription; `CallHistoryCubit` cancels its stream sub in `close()`. Logout sequence (§V-A) extended: any active CallKit call is ended inside `CallCubit.reset()`.
- [x] **Code Quality**: snake_case files, `const`/`final`, no gratuitous comments (§VI).
- [x] **Error Handling**: Data layer returns `Either<Failure, T>` (§VII); CallKit/Hardware failures are best-effort logged via `debugPrint` and never crash a call (matches `CallAudioSessionService`).

**Result**: PASS (no violations; Complexity Tracking not required).

## Project Structure

### Documentation (this feature)

```text
specs/020-native-voip-callkit/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (UI + CallKit + route contracts)
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
lib/
├── core/
│   └── services/
│       ├── call_audio_session_service.dart   # EXISTING (019) — do not break
│       ├── callkit_service.dart              # NEW — flutter_callkit_incoming wrapper
│       └── audio_route_service.dart          # NEW — Hardware.instance route control
└── features/
    ├── video_call/
    │   └── presentation/
    │       ├── bloc/call_cubit.dart          # EDIT — history, CallKit, audio route, mute sync (C1), multi-device dedup (C2), PSTN collision (E1)
    │       ├── pages/voice_call_screen.dart  # EDIT — speaker→route picker
    │       ├── pages/video_call_screen.dart  # EDIT — route picker
    │       └── widgets/audio_route_picker_sheet.dart  # NEW — in-call route picker (F1: lives in video_call per §I)
    └── call_history/                         # NEW feature module
        ├── data/
        │   ├── datasources/call_history_local_data_source.dart
        │   ├── models/call_history_record_model.dart
        │   └── repositories/call_history_repository_impl.dart
        ├── domain/
        │   ├── entities/call_history_record.dart
        │   └── repositories/call_history_repository.dart
        └── presentation/
            ├── bloc/call_history_cubit.dart
            ├── pages/calls_history_screen.dart
            └── widgets/
                └── call_history_tile.dart

lib/features/chat/presentation/pages/chat_list_screen.dart  # EDIT — wire index 3 → CallsHistoryScreen

ios/Runner/Info.plist                       # EDIT — UIBackgroundModes += audio, voip
android/app/src/main/AndroidManifest.xml    # EDIT — FOREGROUND_SERVICE(_MICROPHONE), BLUETOOTH_CONNECT, callkit service

test/features/call_history/                 # NEW — cubit + repo + datasource tests
```

**Structure Decision**: Reuse the existing Clean-Architecture layout. The Calls history is a self-contained feature module (`call_history`). The in-call **route picker** lives in `video_call/presentation/widgets/` (it is an in-call widget, owned by the call feature per §I — F1). Native bridges (`CallKitService`, `AudioRouteService`) are cross-cutting singletons in `core/services/`, consistent with `CallAudioSessionService`. The "Calls" bottom-nav tab already exists in `chat_list_screen.dart` (index 3) but currently falls through to the chat list — only `_buildBody` wiring is needed.

### Native ↔ in-app synchronization & edge handling

- **Mute sync (C1, FR-VoIP-06)**: `CallKitMute` ↔ `CallCubit` is bidirectional — system-control mute toggles `setMicrophoneEnabled`, and in-app mute updates the native call state. Neither side may drift.
- **Multi-device dedup (C2, FR-VoIP-15)**: an `answered/declined-elsewhere` signal dismisses this device's native UI and suppresses the `missed` history row.
- **Background isolate (U1, FR-VoIP-12)**: the terminated/background FCM path runs in a separate isolate; the top-level `@pragma('vm:entry-point')` handler must `Firebase.initializeApp()` + bootstrap `CallKitService` before `showIncoming`.
- **PSTN collision (E1)**: app VoIP vs native cellular call honors system prioritization (hold/reject) with no stuck session.
- **callId idempotency (E2)**: `showIncoming` is keyed on `callId`; duplicate/retried signals are no-ops, never stacking native screens.

## Complexity Tracking

> No Constitution violations — section intentionally empty.
