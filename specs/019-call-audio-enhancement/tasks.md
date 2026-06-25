---

description: "Task list for Call Audio Enhancement & Noise Cancellation (Frontend)"
---

# Tasks: Call Audio Enhancement & Noise Cancellation (Frontend)

**Input**: Design documents from `/specs/019-call-audio-enhancement/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/audio-configuration.md, quickstart.md

**Tests**: Included — the plan's verification contract (C4) and quickstart specify unit tests for `CallAudioConfig` and `CallAudioSessionService`.

**Organization**: Tasks are grouped by user story. Note that this feature is mostly shared infrastructure (two `core/services/` units consumed at four connect sites), so the bulk of code lands in Foundational + US1; US2 and US3 are primarily verification + platform-parity increments built on that foundation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

## Path Conventions

- **Core Logic**: `lib/core/services/`
- **Call surfaces**: `lib/features/video_call/`
- **Tests**: `test/core/services/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm preconditions; no new packages required (`livekit_client` and `audio_session` already in `pubspec.yaml`).

- [X] T001 Verify `livekit_client` (^2.6.4) and `audio_session` (^0.2.3) are present in `pubspec.yaml` and that NO third-party/AI denoising SDK (e.g. Krisp) is declared (supports FR-Audio-03 / SC-005)
- [X] T002 [P] Create the `test/core/services/` directory if it does not already exist

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The two `core/services/` units every user story depends on. MUST complete before US1–US3.

- [X] T003 Create `CallAudioConfig` in `lib/core/services/call_audio_config.dart`: a `const AudioCaptureOptions` with `noiseSuppression: true`, `echoCancellation: true`, `autoGainControl: true`, `voiceIsolation: false`, `typingNoiseDetection: false`, plus a `roomOptions()` factory preserving existing `adaptiveStream`/`dynacast`/`ScreenShareCaptureOptions(useiOSBroadcastExtension: true)` (contract C1; FR-Audio-02, FR-Audio-02a)
- [X] T004 Create `CallAudioSessionService` (`@lazySingleton`) in `lib/core/services/call_audio_session_service.dart` with `configureForCall()` (iOS `playAndRecord`+`voiceChat`, Android `voiceCommunication` usage + `speech` content type, then `setActive(true)`) and `deactivate()`; subscribe to `AudioSession.interruptionEventStream` and re-assert the session on interruption end; wrap all calls in try/catch + `debugPrint` so failures never throw into the call flow (contract C2; FR-Audio-01, FR-Audio-06, Constitution §VII)
- [X] T005 Register `CallAudioSessionService` in DI and regenerate `lib/core/di/injection.config.dart` via `dart run build_runner build --delete-conflicting-outputs`

**Checkpoint**: Foundation ready — call surfaces can now be wired and verified.

---

## Phase 3: User Story 1 - Clear, noise-free speech for accurate translation (Priority: P1) 🎯 MVP

**Goal**: Every call that publishes a microphone track configures the OS voice-communication session before connecting and publishes with the WebRTC filters enabled, so participants hear clean speech and the STT pipeline gets clean input — with no manual setup (FR-Audio-01/02/05/06/07).

**Independent Test**: Join a 1:1 voice call from a noisy/echo-prone room on speaker; a second participant confirms background noise is suppressed and no echo returns — with no settings toggled.

### Implementation for User Story 1

- [X] T006 [US1] Wire `LivekitVideoCallRepositoryImpl.connect()` to `await getIt<CallAudioSessionService>().configureForCall()` before `Room(...)`, and build the room with `CallAudioConfig.roomOptions()` in `lib/features/video_call/data/repositories/livekit_video_call_repository_impl.dart` (covers **avatar calls**, which use this repo path) (FR-Audio-05)
- [X] T007 [US1] Wire `_connectToRoom` in `lib/features/video_call/presentation/pages/voice_call_screen.dart`: replace the bare `Room()` with `Room(roomOptions: CallAudioConfig.roomOptions())` and call `configureForCall()` before `connect` (FR-Audio-01/02)
- [X] T008 [US1] Wire `_connectToRoom` in `lib/features/video_call/presentation/pages/video_call_screen.dart`: use `CallAudioConfig.roomOptions()` and call `configureForCall()` before `connect` (FR-Audio-01/02)
- [X] T009 [US1] Wire `_connectToRoom` in `lib/features/video_call/presentation/pages/group_call_screen.dart`: use `CallAudioConfig.roomOptions()` and call `configureForCall()` before `connect` (FR-Audio-01/02)
- [X] T010 [US1] Add `await getIt<CallAudioSessionService>().deactivate()` to the teardown/`dispose` path of the repository and the three call screens; ensure `deactivate()` cancels the `interruptionEventStream` `StreamSubscription` (set the field to null after cancel) so no subscription leaks across calls (Constitution §V; FR-Audio-06)
- [X] T011 [P] [US1] Unit test `test/core/services/call_audio_config_test.dart`: assert `captureOptions.noiseSuppression == true`, `echoCancellation == true`, `autoGainControl == true`, and that `roomOptions().defaultAudioCaptureOptions` carries the same flags (SC-001)
- [X] T012 [P] [US1] Unit test `test/core/services/call_audio_session_service_test.dart` (mocked `AudioSession`): assert `configure(...)` is invoked with `voiceChat` / `voiceCommunication` and `setActive(true)` before the service reports ready; that a thrown configuration error is swallowed (no rethrow); and that `deactivate()` cancels the `interruptionEventStream` subscription (no further interruption handling fires after deactivate) (SC-003, Constitution §V, §VII)
- [ ] T013 [US1] Manual verification (quickstart §5.1/§5.3): confirm `configureForCall()` runs before the mic track publishes on all four surfaces, and noise/echo are suppressed in a noisy speaker-mode call (SC-001, SC-003, SC-004)

**Checkpoint**: User Story 1 fully functional — the enhancement is live on every call surface. This is the MVP.

---

## Phase 4: User Story 2 - Enhancement preserves translation fidelity (no over-filtering) (Priority: P1)

**Goal**: Confirm the configuration does not over-filter speech — OS AI voice isolation and typing-noise detection are off, only built-in WebRTC/OS filters are in the path, and STT accuracy does not regress (FR-Audio-03/08, SC-002, SC-005).

**Independent Test**: Transcribe a fixed consonant-heavy phrase set in a quiet room with enhancement on vs off; verify WER difference ≤ 2% absolute.

### Implementation for User Story 2

- [X] T014 [P] [US2] Extend `test/core/services/call_audio_config_test.dart`: assert `captureOptions.voiceIsolation == false` and `captureOptions.typingNoiseDetection == false` (FR-Audio-02a)
- [X] T015 [US2] Audit `pubspec.yaml` and `pubspec.lock` to confirm no third-party/AI denoising SDK is present and no audio `TrackProcessor` is attached in `CallAudioConfig` (SC-005)
- [ ] T016 [US2] Manual WER A/B verification (quickstart §5.2): record/transcribe the fixed phrase set with enhancement on vs off; confirm enhancement-on WER is within ≤ 2% absolute of enhancement-off (SC-002)

**Checkpoint**: US1 + US2 hold — clarity gained without sacrificing translation accuracy.

---

## Phase 5: User Story 3 - Consistent behavior across iOS and Android (Priority: P2)

**Goal**: The voice-communication session and filters behave equivalently on both platforms (FR-Audio-01, SC-007).

### Implementation for User Story 3

- [X] T017 [US3] Extend `test/core/services/call_audio_session_service_test.dart` with platform-specific assertions: the iOS branch requests `playAndRecord`/`voiceChat`, the Android branch requests `voiceCommunication` usage + `speech` content type (FR-Audio-01)
- [X] T018 [US3] Verify platform manifests support a voice-communication capture session and adjust only if missing: iOS `ios/Runner/Info.plist` (`NSMicrophoneUsageDescription`, audio background mode) and Android `android/app/src/main/AndroidManifest.xml` (`RECORD_AUDIO`, foreground-service for calls)
- [ ] T019 [US3] Manual parity verification (quickstart §5.5): run the noisy-environment test on one iOS and one Android device; confirm neither shows unsuppressed noise, clipping, or echo the other does not (SC-007)

**Checkpoint**: All user stories independently verified across platforms.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finalize documentation accuracy and code quality.

- [X] T020 [P] Update `specs/019-call-audio-enhancement/contracts/audio-configuration.md` (C4) and `quickstart.md` to cite the concrete **≤ 2% absolute WER** threshold from the SC-002 clarification
- [X] T021 Run `flutter analyze` and ensure zero warnings for the new/changed files (Constitution §VI)
- [ ] T022 Run the full `quickstart.md` validation checklist end-to-end and record results
- [ ] T023 Verify zero added latency (quickstart §5.6): measure end-to-end audio latency on a build with the configuration vs. a baseline build without it, and confirm no perceptible increase and no extra buffering/processing stage in the audio path (FR-Audio-04, SC-006)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS all user stories** (US1–US3 all consume `CallAudioConfig` + `CallAudioSessionService`)
- **User Stories (Phase 3+)**: All depend on Foundational completion
  - US1 must land first in practice (it wires the services into the app); US2 and US3 verify behaviors that only exist once US1 is wired
- **Polish (Phase 6)**: After the desired user stories are complete

### User Story Dependencies

- **US1 (P1)**: Depends only on Foundational. Delivers the actual enhancement (MVP).
- **US2 (P1)**: Logically depends on US1 being wired (it verifies the running config); the `voiceIsolation: false` flag itself is set in Foundational (T003).
- **US3 (P2)**: Depends on Foundational (service) and is best validated after US1 is wired.

### Within Each User Story

- Tests for `CallAudioConfig`/`CallAudioSessionService` (T011, T012, T014, T017) can be written against the foundational units and run independently
- Wiring tasks (T006–T009) touch different files → parallelizable; T010 (teardown) follows them
- Manual verification tasks come last within their story

### Parallel Opportunities

- T002 (Setup) is [P]
- T006, T007, T008, T009 touch four different files → can run in parallel
- T011, T012 (US1 tests) and T014 (US2 test) are [P] — different test files / independent assertions
- T020 (docs) is [P] with code polish

---

## Parallel Example: User Story 1

```bash
# After Foundational (T003–T005), wire the four connect sites in parallel:
Task: "T006 Wire repository connect() in livekit_video_call_repository_impl.dart"
Task: "T007 Wire voice_call_screen.dart _connectToRoom"
Task: "T008 Wire video_call_screen.dart _connectToRoom"
Task: "T009 Wire group_call_screen.dart _connectToRoom"

# Run the unit tests in parallel:
Task: "T011 call_audio_config_test.dart"
Task: "T012 call_audio_session_service_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup (T001–T002)
2. Phase 2: Foundational (T003–T005) — CRITICAL, blocks everything
3. Phase 3: User Story 1 (T006–T013)
4. **STOP and VALIDATE**: noisy-call test — noise/echo suppressed, session before publish
5. Ship MVP

### Incremental Delivery

1. Setup + Foundational → services exist
2. US1 → enhancement live on all surfaces → validate → ship (MVP)
3. US2 → confirm no STT regression (WER ≤ 2%) + no AI/paid SDK → ship
4. US3 → iOS/Android parity verified → ship
5. Polish → docs/threshold + analyze + quickstart run

---

## Notes

- [P] tasks = different files, no dependencies
- This feature has no domain/data entities and no persistence — by design (see plan Constitution Check); all code lives in `core/services/` + the four call connect sites
- Audio-session configuration is best-effort: it MUST NOT block or fail a call join (Constitution §VII)
- Do NOT leave `voiceIsolation`/`typingNoiseDetection` at their `true` SDK defaults — that is the over-filtering regression the spec guards against (FR-Audio-02a, SC-002)
- Commit after each task or logical group
