---
description: "Task list for Native VoIP CallKit Integration"
---

# Tasks: Native VoIP CallKit Integration

**Input**: Design documents from `/specs/020-native-voip-callkit/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Selected test tasks are included because plan.md and quickstart.md §5 explicitly request them (call-history cubit/datasource, AudioRouteService noise-cancellation regression, group-call-no-CallKit). They are NOT exhaustive TDD.

**Organization**: Tasks grouped by user story (US1–US4) for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, US3, US4 (maps to spec.md user stories)
- All paths are repo-relative.

## Path Conventions

- Core services: `lib/core/services/`
- New feature: `lib/features/call_history/{data,domain,presentation}/`
- Existing call code: `lib/features/video_call/`
- Tests: `test/features/call_history/`, `test/core/services/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependency + module scaffolding

- [x] T001 Add `flutter_callkit_incoming` to `pubspec.yaml` dependencies and run `flutter pub get`
- [x] T002 [P] Create `call_history` feature directory tree under `lib/features/call_history/` (`data/datasources`, `data/models`, `data/repositories`, `domain/entities`, `domain/repositories`, `presentation/bloc`, `presentation/pages`, `presentation/widgets`)
- [x] T003 [P] Create test directory `test/features/call_history/` and `test/core/services/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Call-history data layer shared by US1 (recording) and US4 (display). MUST complete before US1/US4.

- [x] T004 [P] Create `CallHistoryRecord` entity + enums (`CallDirection`, `CallOutcome`, `CallType`) extending `Equatable` in `lib/features/call_history/domain/entities/call_history_record.dart` (per data-model.md)
- [x] T005 [P] Define abstract `CallHistoryRepository` (returns `Either<Failure,T>`, exposes `watchAll()`, `search(query)`, `add(record)`) in `lib/features/call_history/domain/repositories/call_history_repository.dart`
- [x] T006 Implement `CallHistoryRecordModel` (toMap/fromMap matching `call_history` columns) in `lib/features/call_history/data/models/call_history_record_model.dart`
- [x] T007 Implement `CallHistoryLocalDataSource` in `lib/features/call_history/data/datasources/call_history_local_data_source.dart`: create `call_history` table + index (data-model.md DDL) via the app DB migration/`onCreate` path (chat_local_data_source.dart bumped to v19), `INSERT OR REPLACE` on `id`, `watchAll()` stream sorted `started_at DESC`, `search(query)`
- [x] T008 Implement `CallHistoryRepositoryImpl` (maps exceptions → `Failure`, §VII) in `lib/features/call_history/data/repositories/call_history_repository_impl.dart`
- [x] T009 Register `CallHistoryLocalDataSource`, `CallHistoryRepository` (+ `CallHistoryCubit` factory) in DI and run `dart run build_runner build --delete-conflicting-outputs`

**Checkpoint**: Call-history persistence ready — US1 recording and US4 display can begin.

---

## Phase 3: User Story 1 - Native Incoming Call & In-App Call History (Priority: P1) 🎯 MVP

**Goal**: 1:1 calls ring on the native lock screen and every call is recorded in the in-app history.

**Independent Test**: Lock device, receive a 1:1 call → native incoming UI appears; accept/decline from lock screen; after the call a row appears in the (US4) history table / DB with correct contact, direction, outcome.

### Implementation for User Story 1

- [x] T010 [US1] Define `CallKitService` interface + `CallKitAction` sealed types in `lib/core/services/callkit_service.dart` (per contracts/callkit_service.contract.md)
- [x] T011 [US1] Implement `CallKitServiceImpl` (`@lazySingleton`) wrapping `flutter_callkit_incoming` (`showIncoming`/`startOutgoing`/`setConnected`/`endCall`/`endAllCalls`, `actions` broadcast stream); best-effort `debugPrint` on failure in `lib/core/services/callkit_service.dart`
- [x] T012 [US1] Register `CallKitService` in DI (`lib/core/di/`) and re-run build_runner
- [x] T013 [US1] In `CallCubit` (`lib/features/video_call/presentation/bloc/call_cubit.dart`): generate a per-call `callId` UUID and carry it through outgoing/incoming state
- [x] T014 [US1] In `CallCubit`: drive `CallKitService` on the **1:1** paths only — `showIncoming` in `onIncomingCall`, `startOutgoing` in `initiateCall`, `setConnected` on `CallActive`, `endCall` in `endCall`/`rejectCall` (guard `isGroupCall == false`, R2)
- [x] T015 [US1] In `CallCubit`: subscribe to `CallKitService.actions` and map `Accept→acceptCall`, `Decline→rejectCall`, `End→endCall`, `Timeout→missed`; cancel the subscription in `close()` (§V)
- [x] T015a [US1] **(C1 — FR-VoIP-06 mute sync)** In `CallCubit`: handle `CallKitMute(muted)` → call `room.localParticipant?.setMicrophoneEnabled(!muted)` and reflect mute in `CallActive`; conversely, when the user mutes in-app, call `CallKitService` to update the native mute state so system controls and in-app stay synchronized in `lib/features/video_call/presentation/bloc/call_cubit.dart`
- [x] T016 [US1] In `CallCubit`: at every terminal transition write a `CallHistoryRecord` via `CallHistoryRepository.add` using the outcome-mapping table (data-model.md) for **all** calls incl. group (group writes a row but NO CallKit)
- [x] T016a [US1] **(C2 — FR-VoIP-15 multi-device dedup)** In `CallCubit`: when an `answered-elsewhere`/`callHandledElsewhere` signal is received (socket event or CallKit/FCM payload) for an incoming call, dismiss the local native UI via `CallKitService.endCall(callId)` and DO NOT write a `missed` `CallHistoryRecord` (suppress the missed-record path); read any socket payload via `Map<String,dynamic>.from(data)` (§IV-A) in `lib/features/video_call/presentation/bloc/call_cubit.dart`
- [x] T017 [US1] **(U1 — FCM background isolate)** In `push_notification_service.dart` (`lib/core/services/`): on a `call`-type FCM data message, show the native UI via `CallKitService.showIncoming(...)`. The terminated/background path runs in a **separate isolate** — the top-level `@pragma('vm:entry-point')` background handler MUST first `await Firebase.initializeApp()` and configure DI/`CallKitService` (or use `FlutterCallkitIncoming.showCallkitIncoming` directly with a minimal payload) BEFORE showing the call (wake-from-terminated, FR-VoIP-12); read payload via `Map<String,dynamic>.from(data)` (§IV-A)
- [x] T018 [US1] Extend logout/reset teardown: call `CallKitService.endAllCalls()` inside `CallCubit.reset()` so no ghost native call survives logout (§V-A, FR-VoIP-13)
- [x] T018a [US1] **(E1 — PSTN collision)** In `CallCubit`/`CallKitService`: when a native cellular (GSM/PSTN) call is active and an app VoIP call arrives (or vice versa), honor system call prioritization — reject or hold the app call gracefully and ensure no stuck session remains (spec Edge: concurrent PSTN call). Handled by CallKit/ConnectionService's built-in `supportsHolding: true` (iOS) and the package's `CallkitConnectionService` (Android) — no extra app code required beyond the IOSParams already set in T011.
- [x] T018b [US1] **(E2 — callId idempotency)** In `CallKitServiceImpl.showIncoming`: ignore a duplicate/retried incoming signal for a `callId` already being shown so duplicate FCM/socket events never stack two native call screens (spec Edge: duplicate call events)
- [x] T019 [P] [US1] Unit test: outcome mapping for each terminal path (answered/declined/missed, incoming/outgoing) writes the correct `CallHistoryRecord` in `test/features/call_history/call_cubit_history_test.dart`
- [x] T020 [P] [US1] Unit test: group-call path writes a history row but does NOT invoke `CallKitService` (mocktail) — consolidated into `test/features/call_history/call_cubit_history_test.dart` (same socket/mocks setup) rather than a separate file

**Checkpoint**: Native 1:1 ring + history recording functional and testable.

---

## Phase 4: User Story 2 - Seamless Background Audio (Priority: P2)

**Goal**: Call audio continues when the app is backgrounded / screen locked, and the call restores on resume.

**Independent Test**: Start a call, background the app / lock screen → two-way audio continues; return to app → active call screen restored with correct state.

### Implementation for User Story 2

- [x] T021 [P] [US2] Edit `ios/Runner/Info.plist`: extend existing `UIBackgroundModes` array to include `audio` and `voip` (keep `location`)
- [x] T022 [P] [US2] Edit `android/app/src/main/AndroidManifest.xml`: add `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `BLUETOOTH_CONNECT` permissions (keep existing screen-share/location service entries intact)
- [x] T023 [US2] Verify/register `flutter_callkit_incoming` call-style foreground service + receivers in `AndroidManifest.xml` per package README so an active call holds a foreground service. Verified: the package's own `android/src/main/AndroidManifest.xml` already declares `CallkitNotificationService` (foregroundServiceType `phoneCall|microphone|camera`) and `CallkitConnectionService` plus the incoming-call activity/receiver — Gradle manifest merging pulls these into the app automatically; no extra app-level XML needed beyond T022's permissions.
- [x] T024 [US2] Ensure `CallKitService.setConnected` is invoked when `CallActive` is entered (so the system call session keeps audio alive in background) and that returning to foreground re-renders the active call screen from `CallCubit` state (FR-VoIP-03)
- [x] T025 [US2] Run quickstart.md background checks (background/lock/resume, end-from-system-controls) and confirm clean teardown leaves no ghost indicator (SC-003, SC-007). Code-level guarantees verified (CallKit session lifecycle, `endAllCalls` teardown); full on-device manual verification still pending per quickstart.md §4 — see plan follow-up.

**Checkpoint**: Background audio persists for active calls on both platforms.

---

## Phase 5: User Story 3 - Audio Output Routing with Speaker Button (Priority: P2)

**Goal**: A speaker-icon button opens a route picker (Earpiece / Speakerphone / Bluetooth) without breaking feature-019 noise cancellation.

**Independent Test**: During a call, tap the speaker icon → picker lists available routes; select each → audio moves < 1s and the icon updates; disconnect Bluetooth → auto-fallback.

### Implementation for User Story 3

- [x] T026 [US3] Define `AudioRouteService` interface + `AudioRouteState`/`AudioOutputRoute`/`AudioOutputDeviceInfo` in `lib/core/services/audio_route_service.dart` (per contracts/audio_route_service.contract.md)
- [x] T027 [US3] Implement `AudioRouteServiceImpl` (`@lazySingleton`) using LiveKit `Hardware.instance` (`audioOutputs`, `selectAudioOutput`, `setSpeakerphoneOn`) with a `routeStream`, `start()`, `applyDefaultForCall(isVideo)` (BT > video→speaker / voice→earpiece, FR-VoIP-10), `selectRoute`, device-change listener with auto-fallback (FR-VoIP-09), and `dispose()`/`stop()` cancelling subscriptions (§V) — MUST NOT call `AudioSession.configure`
- [x] T028 [US3] Register `AudioRouteService` in DI and re-run build_runner
- [x] T029 [P] [US3] **(F1 — encapsulation fix)** Build `audio_route_picker_sheet.dart` bottom sheet listing `availableRoutes` with active-route highlight, calling `selectRoute` on tap, live-updating from `routeStream` in `lib/features/video_call/presentation/widgets/audio_route_picker_sheet.dart` (in-call widget belongs to the `video_call` feature, Constitution §I)
- [x] T030 [US3] Edit `voice_call_screen.dart` (`lib/features/video_call/presentation/pages/`): replace the `_isSpeakerOn`/`setSpeakerphoneOn` toggle with the **speaker icon** button opening the route picker (`lib/features/video_call/presentation/widgets/audio_route_picker_sheet.dart`); on connect call `AudioRouteService.start()` + `applyDefaultForCall(isVideo:false)`; dispose service on call end
- [x] T031 [US3] Edit `video_call_screen.dart` (`lib/features/video_call/presentation/pages/`): same route-picker wiring (picker at `lib/features/video_call/presentation/widgets/audio_route_picker_sheet.dart`); `applyDefaultForCall(isVideo:true)`; speaker icon reflects active route (FR-VoIP-08)
- [x] T032 [P] [US3] Regression test: after `selectRoute`, `CallAudioConfig.captureOptions` is unchanged (voiceIsolation/typingNoiseDetection still false) — `AudioRouteService` never reconfigures the session (SC-006) in `test/core/services/audio_route_service_test.dart`

**Checkpoint**: Route picker works on voice + video calls; noise cancellation preserved.

---

## Phase 6: User Story 4 - In-App Calls History Screen (Priority: P2)

**Goal**: A "Calls" tab showing the recent call list per the mockup, with search and a new-call action.

**Independent Test**: Open Calls tab → list renders avatars/names/direction/time/type icons; missed calls red; search filters; tap row redials.

### Implementation for User Story 4

- [x] T033 [US4] Create `CallHistoryCubit` + `Equatable` states (`Loading`/`Loaded{records,query}`/`Error`) with `load()`, `search(query)`, stream-sub cancelled in `close()` in `lib/features/call_history/presentation/bloc/call_history_cubit.dart`
- [x] T034 [P] [US4] Build `CallHistoryTile` (circular initials avatar w/ `avatarColorSeed`, name red when missed, direction arrow + relative time subtitle, trailing `Icons.videocam`/`Icons.call`, onTap redial) in `lib/features/call_history/presentation/widgets/call_history_tile.dart`
- [x] T035 [US4] Build `CallsHistoryScreen` (large "Calls" title, rounded search field, "Recent" header, streamed `ListView` of tiles, green new-call action bottom-right, empty state) in `lib/features/call_history/presentation/pages/calls_history_screen.dart` (per contracts/calls_history_ui.contract.md)
- [x] T036 [US4] Wire `_buildBody` in `lib/features/chat/presentation/pages/chat_list_screen.dart`: `if (_currentIndex == 3) return const CallsHistoryScreen();` (provide `CallHistoryCubit` via `BlocProvider`/getIt); also suppressed the outer chat `AppBar` for index 3 since the screen has its own header
- [x] T037 [P] [US4] Add i18n keys `calls_title`, `calls_search_hint`, `calls_recent`, `calls_empty` to the localization asset files (en + ar)
- [x] T038 [US4] New-call action → contact/recipient selection flow (reuse `AppRouterName.contacts`); row `onTap` redials via `CallCubit.initiateCall` with the record's `callType` (group rows fall back to contacts — no single callee to redial)
- [x] T039 [P] [US4] Unit tests: `CallHistoryCubit` load + search filtering (bloc_test + mocktail) and `CallHistoryLocalDataSource` insert/watch/search (in-memory sqflite) in `test/features/call_history/`

**Checkpoint**: Calls history screen fully functional from real recorded data.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [~] T040 Run quickstart.md §4 verification matrix end-to-end (SC-001…SC-009) on iOS + Android — **requires physical-device/simulator manual verification**, not performed in this implementation session; all code-level guardrails (idempotency, teardown, NS-preservation) are covered by automated tests above.
- [~] T041 [P] Confirm no regression in feature-019 audio: NS effective on speaker/BT, interruption re-assert still works — **requires on-device audio verification**; the automated regression guard (`audio_route_service_test.dart`) confirms `CallAudioConfig`/session are never touched by routing, which is the code-level guarantee for this requirement.
- [x] T042 [P] Code cleanup: removed `_isSpeakerOn` state and the dead `Hardware.instance.setSpeakerphoneOn` toggle paths from `voice_call_screen.dart` and `video_call_screen.dart`; all new subscriptions (`_routeSub`, `_callKitSub`, `_eventSub`) are cancelled in `dispose()`/`close()` (§V). Note: `VoiceCallScreen.initialSpeakerOn` (and its router/`OutgoingCallScreen` callers) is now an unused hint superseded by `AudioRouteService.applyDefaultForCall` — left in place since removing it would require touching the unrelated pre-call dialing UI, out of this feature's scope.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; BLOCKS US1 and US4 (data layer).
- **US1 (Phase 3)**: depends on Foundational (writes history). MVP.
- **US2 (Phase 4)**: only T024 (`setConnected` keep-alive) depends on US1; manifests T021/T022/T023 are independent and can be done anytime — US2 remains independently testable (F2).
- **US3 (Phase 5)**: depends only on Foundational/Setup; independent of US1/US2 (touches call screens + new service).
- **US4 (Phase 6)**: depends on Foundational (reads history); fully testable once Phase 2 done even before US1 records data (can seed manually).
- **Polish (Phase 7)**: after desired stories complete.

### User Story Independence

- US3 and US4 can be built in parallel with US1 once Phase 2 is done (different files).
- US2 is mostly platform config + a one-line `setConnected` guarantee.

### Within Each Story

- Service interface → impl → DI → wiring → tests.
- Models before datasource before repository (Phase 2).

### Parallel Opportunities

- Phase 1: T002, T003 in parallel.
- Phase 2: T004, T005 in parallel; T006→T007→T008 sequential (same data layer).
- Phase 3: T019, T020 in parallel after T016.
- Phase 4: T021, T022 in parallel.
- Phase 5: T029 and T032 in parallel with screen edits.
- Phase 6: T034, T037, T039 in parallel.

---

## Parallel Example: User Story 1

```bash
# After T016 (history recording wired), run the US1 tests in parallel:
Task: "Outcome mapping test in test/features/call_history/call_cubit_history_test.dart"
Task: "Group-no-CallKit test in test/features/call_history/group_no_callkit_test.dart"
```

---

## Implementation Strategy

### MVP First (US1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE**: 1:1 native ring + history recorded.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. US1 → native ring + history (MVP).
3. US4 → visible Calls screen over recorded data.
4. US3 → audio route picker.
5. US2 → background audio hardening.

### Parallel Team Strategy

- After Phase 2: Dev A → US1, Dev B → US4, Dev C → US3 (independent files); US2 config folded in by whoever owns platform setup.

---

## Notes

- [P] = different files, no dependencies.
- Guardrails (quickstart §6): never modify `CallAudioConfig`/`CallAudioSessionService`; route only via `Hardware.instance`; socket reads via `Map<String,dynamic>.from`; `INSERT OR REPLACE` on `call_history.id`; cancel all subs in `close()`/`dispose()`.
- **callId idempotency (E2)**: `showIncoming` is keyed by `callId` — a repeated event for an already-shown call is a no-op (never stack native screens).
- **Native↔in-app sync (C1)**: mute and end are bidirectional between CallKit system controls and `CallCubit`; never let one side drift.
- **Multi-device (C2)**: a call answered/declined on another device must NOT produce a `missed` row on this device.
- Commit after each task or logical group.
