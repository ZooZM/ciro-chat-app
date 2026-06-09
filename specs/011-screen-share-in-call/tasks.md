---

description: "Tasks for Screen Sharing in Calls (011)"
---

# Tasks: Screen Sharing in Calls

**Input**: Design documents from `/specs/011-screen-share-in-call/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/screen-share-socket-event.md, quickstart.md

**Tests**: One bloc_test file is included for `CallCubit`'s new screen-share branch — start/stop/conflict/teardown is non-trivial control flow that warrants automated coverage. UI and platform integration (iOS Broadcast Extension, Android `MediaProjection`) are verified via the two-device manual scenarios in [quickstart.md](quickstart.md).

**Organization**: Tasks are grouped by user story. US1 (sharer side) and US2 (receive side) are both P1 and intertwined at the file level — Foundational phase prepares all shared touch-points so US1 and US2 can be implemented largely in parallel.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different files, no dependency on incomplete tasks
- **[Story]**: US1, US2, US3, US4 (maps to spec.md user stories)
- File paths are exact

## Path Conventions

- **Flutter feature**: `lib/features/video_call/`
- **Flutter core**: `lib/core/`
- **Flutter tests**: `test/features/video_call/`
- **iOS**: `ios/` — Xcode project plus a new `ios/ScreenShareBroadcast/` target
- **Android**: `android/app/src/main/`
- **Backend**: `chat-app-backend/src/modules/chat/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Platform plumbing that any later code change depends on. iOS and Android each need native-side scaffolding before LiveKit's screen-share API will work; the backend handler must exist before the client can emit the new socket event.

- [X] T001 Add iOS Broadcast Upload Extension target `ScreenShareBroadcast` to the Xcode project (`ios/Runner.xcworkspace`). Manual Xcode UI step: File → New → Target → Broadcast Upload Extension. Bundle id should be `<runner bundle id>.ScreenShareBroadcast`. Add to `Runner.entitlements` and `ScreenShareBroadcast.entitlements` a shared App Group `group.com.cirochat.shared`. Commit the resulting changes to `ios/Runner.xcodeproj/project.pbxproj`, `ios/Podfile` (if `pod install` updates it), and the new target's `Info.plist`. **Cannot be done via Edit alone — Xcode UI required.** **Operational follow-up (DEFERRED, before TestFlight)**: register the new bundle id in App Store Connect, create a matching distribution provisioning profile in the Apple Developer portal, add the App Group to both profiles, and update the CI build pipeline so it signs both targets. Without this, App Store / TestFlight uploads will fail.
- [X] T002 In the new `ios/ScreenShareBroadcast/SampleHandler.swift`, replace the boilerplate with LiveKit's `LKBroadcastSampleHandler` subclass per livekit_client iOS docs. Set `LK-App-Group-Identifier` in `Info.plist` of both the main app and the extension to `group.com.cirochat.shared`.
- [X] T003 [P] Update `android/app/src/main/AndroidManifest.xml`: add `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />` and `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />`. Add the LiveKit foreground-service `<service>` declaration with `android:foregroundServiceType="mediaProjection"` per livekit_client Android docs.
- [X] T004 [P] In `chat-app-backend/src/modules/chat/chat.gateway.ts`, add a `@SubscribeMessage('screenShareStateChanged')` handler implementing the Redis `SET NX screenshare:active:{chatRoomId} EX 21600` lock per [contracts/screen-share-socket-event.md](contracts/screen-share-socket-event.md). On `isSharing=true` + lock success → re-broadcast to all other sockets in the chat room and reply `screenShareAccepted` to emitter. On lock conflict → reply `screenShareRejected` ONLY to emitter with `{activeSharerUserId, activeSharerName, reason}`. On `isSharing=false` → verify ownership, `DEL` the key, re-broadcast.
- [X] T005 [P] In `chat-app-backend/src/modules/chat/chat.gateway.ts`, in the existing socket-disconnect / `leaveGroupCall` / `endCall` handlers, add a cleanup step: if the disconnecting user's id matches `GET screenshare:active:{theirChatRoomId}`, `DEL` the key and broadcast a synthetic `screenShareStateChanged` with `isSharing=false` so receivers can clear their tile (prevents zombie locks per quickstart Scenario 5).

**Checkpoint**: Both platforms and the backend now have the scaffolding the LiveKit API + new socket event need. No user-visible behavior yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the new Failure type, extend the SocketService API surface, extend the CallActive state shape, and add the side-event stream so stories can wire to existing infrastructure.

- [X] T006 [P] In `lib/core/error/failures.dart`, add `class ScreenShareDeniedFailure extends Failure { const ScreenShareDeniedFailure([super.message = 'Screen-share permission denied']); }`.
- [X] T007 [P] In `lib/core/network/socket_service.dart`, add three new typed callbacks (following the existing `void Function(...)?` pattern): `onScreenShareStateChanged(String chatRoomId, String userId, String userName, bool isSharing, bool withAudio)`, `onScreenShareAccepted(String chatRoomId)`, `onScreenShareRejected(String chatRoomId, String activeSharerUserId, String activeSharerName, String reason)`. Register `_socket?.on(...)` handlers for each event using the Map-type-safe pattern from IV-A.
- [X] T008 [US1+US2] In the same file, add an emitter `void emitScreenShareStateChanged({required String chatRoomId, required String userId, required String userName, required bool isSharing, required bool withAudio})` that wraps `_socket?.emit('screenShareStateChanged', payload)`.
- [X] T009 In `lib/features/video_call/domain/repositories/video_call_repository.dart`, extend the abstract `VideoCallRepository` with three methods per [data-model.md](data-model.md) "Repository contract": `Future<Either<Failure, void>> setScreenShareEnabled(bool enabled, {bool withDeviceAudio = false})`, `RemoteTrackPublication? screenShareVideoTrackOf(String participantIdentity)`, `RemoteTrackPublication? screenShareAudioTrackOf(String participantIdentity)`.
- [X] T010 In `lib/features/video_call/presentation/bloc/call_cubit.dart`, extend the `CallActive` state class with the six new fields per [data-model.md](data-model.md) "CallActive state extensions": `isLocallySharingScreen` / `localShareIncludesAudio` / `activeSharerUserId` / `activeSharerName` / `activeSharerHasAudio` / `mutedScreenAudioBySharerId`. Update the `copyWith` method, `props` list, and constructor defaults (all empty / false / empty set). Ensure equality semantics treat `Set<String>` correctly (use `UnmodifiableSetView` if needed).
- [X] T011 In the same file, declare a sealed `CallSideEvent` hierarchy at the top of the file (outside the cubit) with `CallScreenShareConflict(String activeSharerName)` and `CallScreenShareDenied()` variants. Add a `Stream<CallSideEvent> get sideEvents` getter backed by a `StreamController<CallSideEvent>.broadcast()` field that's closed in `close()`.

**Checkpoint**: Type surface and state shape are ready. No new behavior yet, but the cubit can now hold and emit screen-share information.

---

## Phase 3: User Story 1 - Start and stop sharing (Priority: P1) 🎯 MVP

**Goal**: Local user can tap an icon to start/stop a screen share, including choosing the audio mode. The sharer's icon flips state, the "you are sharing" banner appears, and a `screenShareStateChanged` socket event fires. Covers FR-001 (icon), FR-002 (permission flow), FR-003 (track publish), FR-005 (camera stays), FR-006 (sharer indicator), FR-007 (stop), FR-012 (conflict UX from the sharer's perspective), FR-013 (audio toggle), FR-015 (background continuity — verified in US4).

**Independent Test**: Join any call as user A. Tap share icon → sheet → "Share screen only" → grant OS permission → banner shows "You are sharing your screen", icon flips to ON, camera tile remains. Tap share icon again → banner and ON state clear within 2 s. Repeat with "Share screen + device audio" — banner text identical, but `localShareIncludesAudio == true` in cubit state. **iOS-only**: while sharing, tap the red recording banner at the top of the iOS screen → confirm Stop → in-app banner and ON state clear within 2 s, AND the `screenShareStateChanged` socket event with `isSharing: false` fires (verify in logs). **Android-only**: while sharing, expand the notification shade and tap the foreground-service notification's STOP action → same behaviour.

### Implementation for User Story 1

- [X] T012 [US1] In `lib/features/video_call/data/repositories/livekit_video_call_repository_impl.dart`, implement `setScreenShareEnabled(bool enabled, {bool withDeviceAudio = false})`. Call `_room!.localParticipant!.setScreenShareEnabled(enabled, screenShareCaptureOptions: ScreenShareCaptureOptions(captureScreenAudio: withDeviceAudio))`. Wrap in try/catch: on `TrackCreateException` or any LiveKit permission error, return `Left(ScreenShareDeniedFailure(error.toString()))`. On success return `Right(null)`. Guard with `_room?.localParticipant != null` check.
- [X] T012a [US1] **iOS Broadcast banner stop bridging (FR-008 iOS side).** In the same repo file and in `lib/features/video_call/domain/repositories/video_call_repository.dart`:
    1. In the domain interface, add `set onLocalScreenShareEndedExternally(void Function()? callback)` so the cubit can register a listener.
    2. In `LivekitVideoCallRepositoryImpl.connect(...)`, after the room is connected, register a LiveKit event subscription: `_room!.createListener().on<LocalTrackUnpublishedEvent>((e) { if (e.publication.source == TrackSource.screenShareVideo) { _onLocalScreenShareEndedExternally?.call(); } })`. Store the `EventsListener` so it can be cancelled in `disconnect()`.
    3. The same event fires when the user taps the iOS red recording banner OR the Android foreground-service STOP action — both OS-level stop paths route through the same LiveKit unpublish event, so this single listener covers both platforms.
    4. In `CallCubit` (added in T015), register `_repo.onLocalScreenShareEndedExternally = () { _handleExternalScreenShareStop(localUserId, localUserName); }` inside `_bindSocketListeners()` (or a separate `_bindRepoListeners()`). The handler runs the same cleanup as `stopScreenShare()` BUT skips the `_repo.setScreenShareEnabled(false)` call (the track is already unpublished by the OS) and DOES still emit the `screenShareStateChanged` socket event with `isSharing: false` and clear local state.
    5. Cancel the listener in `CallCubit.close()` to avoid stray callbacks during teardown.
- [X] T013 [P] [US1] Create `lib/features/video_call/presentation/widgets/screen_share_toggle_sheet.dart`: a `showModalBottomSheet`-compatible widget exposing two primary buttons (`Share screen only` / `Share screen + device audio`) plus Cancel. Returns the user's `bool? withAudio` selection (or null on cancel) when popped. Style with `AppColors` and `AppConstants` (no hardcoded values).
- [X] T014 [US1] In `call_cubit.dart`, add the private field `final VideoCallRepository _repo` injected in the constructor. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate the DI graph so `CallCubit` receives `VideoCallRepository` from `getIt`.
- [X] T015 [US1] In `call_cubit.dart`, add `Future<void> startScreenShare({required bool withDeviceAudio, required String localUserId, required String localUserName})`. Logic:
    1. Read `state`; bail if not `CallActive`.
    2. If `state.activeSharerUserId.isNotEmpty && state.activeSharerUserId != localUserId` → add `CallScreenShareConflict(state.activeSharerName)` to `sideEvents` controller and return (no LiveKit call).
    3. If `state.isLocallySharingScreen` → treat as no-op (already sharing).
    4. Call `_repo.setScreenShareEnabled(true, withDeviceAudio: withDeviceAudio)`. On `Left(ScreenShareDeniedFailure)` → add `CallScreenShareDenied()` to `sideEvents` and return.
    5. On success → call `_socketService.emitScreenShareStateChanged(chatRoomId: state.chatRoomId, userId: localUserId, userName: localUserName, isSharing: true, withAudio: withDeviceAudio)`.
    6. Emit `state.copyWith(isLocallySharingScreen: true, localShareIncludesAudio: withDeviceAudio, activeSharerUserId: localUserId, activeSharerName: localUserName, activeSharerHasAudio: withDeviceAudio)`.
- [X] T016 [US1] In `call_cubit.dart`, add `Future<void> stopScreenShare({required String localUserId, required String localUserName})`. Logic: bail if not `CallActive` or not currently locally sharing. Call `_repo.setScreenShareEnabled(false)` (errors here are swallowed with debugPrint — stopping should never fail loudly). Emit socket `isSharing: false`. Emit `state.copyWith(isLocallySharingScreen: false, localShareIncludesAudio: false, activeSharerUserId: '', activeSharerName: '', activeSharerHasAudio: false, mutedScreenAudioBySharerId: const {})`.
- [X] T017 [US1] In `call_cubit.dart`, also handle the rejected case: in `_bindSocketListeners()`, set `_socketService.onScreenShareRejected = (chatRoomId, sharerId, sharerName, reason) { … }`. Add `CallScreenShareConflict(sharerName)` to `sideEvents`. Do NOT change state (no share started).
- [X] T018 [US1] In `lib/features/video_call/presentation/pages/video_call_screen.dart`, add a screen-share icon button to the in-call toolbar (matching `AppColors` styling, sized consistent with existing toolbar icons). On tap:
    1. If `state.isLocallySharingScreen` → call `cubit.stopScreenShare(...)`.
    2. Otherwise → `showModalBottomSheet<bool>(builder: (_) => const ScreenShareToggleSheet())`; on non-null result call `cubit.startScreenShare(withDeviceAudio: result, ...)`.
    3. Subscribe to `cubit.sideEvents` via `BlocListener` / `StreamSubscription` and show a `SnackBar` for `CallScreenShareConflict` ("{name} is already sharing. Ask them to stop first.") and `CallScreenShareDenied` ("Permission required to share your screen. Enable it in device settings.").
- [X] T019 [US1] In `video_call_screen.dart`, add a persistent banner widget rendered above the camera grid when `state.isLocallySharingScreen == true`: solid `AppColors.brand` (or warning-orange) background, white text "You are sharing your screen", with a small "Stop sharing" inline button that calls `cubit.stopScreenShare(...)`. Hidden when not sharing.
- [X] T020 [P] [US1] Replicate T018 and T019 in `lib/features/video_call/presentation/pages/group_call_screen.dart`. UI changes are identical; the cubit/state used is the same `CallCubit`. Extract the share icon button + banner into a small private widget in this file (or a shared widget) to avoid drift.

**Checkpoint**: A single user can start and stop a share locally; the conflict and denial side-events show SnackBars correctly. Other devices do NOT yet see the share — that's US2.

---

## Phase 4: User Story 2 - See others' shared screens as separate tiles (Priority: P1)

**Goal**: When another participant starts sharing, every other client renders a new tile in the call grid bound to the screen-share video track, distinct from the sharer's camera tile. If the share includes audio, the tile shows a per-receiver mute toggle. Covers FR-004, FR-005 (camera unchanged), FR-008 (OS-stop propagates as the same `isSharing:false` socket event), FR-010 (cleanup on sharer leave), FR-011 (subtle notification), FR-013b (per-receiver mute), FR-013c (no audio toggle when sharer chose video-only).

**Independent Test**: With device A sharing (US1 complete), device B's grid shows a NEW tile labelled "{A's name} • Screen" alongside A's camera tile. Stop on A → tile disappears on B within 5 s. With A sharing+audio, the tile on B shows a speaker icon; tapping it locally mutes the audio on B without changing what device A sees.

### Implementation for User Story 2

- [X] T021 [US2] In `livekit_video_call_repository_impl.dart`, implement `screenShareVideoTrackOf(String participantIdentity)`: iterate `_room?.remoteParticipants[identity]?.videoTrackPublications` (and local participant for self-sharing), return the first publication where `pub.source == TrackSource.screenShareVideo`, else null. Implement `screenShareAudioTrackOf` similarly against `audioTrackPublications` and `TrackSource.screenShareAudio`.
- [X] T022 [US2] In `call_cubit.dart` `_bindSocketListeners()`, bind `_socketService.onScreenShareStateChanged = (chatRoomId, userId, userName, isSharing, withAudio) { … }`. Logic:
    1. Read `state`; bail if not `CallActive` or `state.chatRoomId != chatRoomId`.
    2. If `userId == localUserId` → ignore (state was already updated by our own start/stop path).
    3. If `isSharing == true` → emit `state.copyWith(activeSharerUserId: userId, activeSharerName: userName, activeSharerHasAudio: withAudio)`.
    4. If `isSharing == false` AND `state.activeSharerUserId == userId` → emit `state.copyWith(activeSharerUserId: '', activeSharerName: '', activeSharerHasAudio: false, mutedScreenAudioBySharerId: state.mutedScreenAudioBySharerId.where((id) => id != userId).toSet())`.
- [X] T023 [US2] In `call_cubit.dart`, add `void toggleReceivedScreenShareAudioMute(String sharerUserId)`. Logic: bail if state is not `CallActive`. Flip membership in the set; locate the audio track via `_repo.screenShareAudioTrackOf(sharerUserId)` and call `pub.muted ? pub.unmute() : pub.mute()`. Emit new state with the updated set.
- [X] T024 [P] [US2] Create `lib/features/video_call/presentation/widgets/screen_share_tile.dart`: a stateless widget with the following constructor parameters (no `getIt` calls inside the widget — per Constitution II, widgets MUST stay layer-pure): `VideoTrack? videoTrack`, `String participantName`, `bool hasAudio`, `bool isMutedLocally`, `VoidCallback onMuteToggle`. Body: full-bleed `VideoTrackRenderer(videoTrack)` (LiveKit widget) when `videoTrack != null`, else a placeholder ("Connecting…" with a spinner). Overlay: label "{participantName} • Screen" at top-left; if `hasAudio` is true, a speaker icon button at top-right that toggles between `Icons.volume_up` and `Icons.volume_off` and calls `onMuteToggle`.
- [X] T025 [US2] In `video_call_screen.dart`, when `state.activeSharerUserId.isNotEmpty && state.activeSharerUserId != localUserId`, resolve the screen-share video and audio tracks at the screen level by calling `getIt<VideoCallRepository>().screenShareVideoTrackOf(state.activeSharerUserId)?.track as VideoTrack?` (and analogously for audio). Render `ScreenShareTile` as an additional grid cell adjacent to that participant's existing camera tile. Pass `videoTrack: <resolved>`, `participantName: state.activeSharerName`, `hasAudio: state.activeSharerHasAudio`, `isMutedLocally: state.mutedScreenAudioBySharerId.contains(state.activeSharerUserId)`, `onMuteToggle: () => cubit.toggleReceivedScreenShareAudioMute(state.activeSharerUserId)`. The `getIt` lookup lives in the screen (presentation layer entry point), not in the widget.
- [X] T026 [P] [US2] Replicate the T025 grid integration in `group_call_screen.dart`, including the screen-level track resolution via `getIt<VideoCallRepository>()`. Take care that the grid layout (currently designed for camera tiles only) accommodates one extra cell when a share is active. If the existing grid is N×M, the share tile may grow it to N×(M+1); document the row/column logic inline.
- [X] T027 [P] [US2] In `video_call_screen.dart` (and `group_call_screen.dart`), when `state.activeSharerUserId` transitions from empty → non-empty, show a transient `SnackBar` "{name} started sharing their screen" via a `BlocListener` watching that field. Duration 2 s. This is FR-011's "subtle notification".

**Checkpoint**: Sharing is now end-to-end visible. Other participants see the new tile, can mute its audio independently, and the tile cleans up when the sharer stops.

---

## Phase 5: User Story 3 - First-time permission flow handled gracefully (Priority: P2)

**Goal**: The OS picker is the only thing the user sees on first share; deny / dismiss / grant all produce sensible UX without crashes. Covers FR-009, plus the deny/dismiss acceptance scenarios from Story 3.

**Independent Test**: Fresh install. Start a call. Tap share. OS picker appears. Test each of: Allow (US1 happy path), Deny (SnackBar appears, icon stays OFF, no crash, re-tap re-prompts), Dismiss-without-choosing (icon stays OFF, no error, no crash).

### Implementation for User Story 3

- [X] T028 [US3] In `livekit_video_call_repository_impl.dart`'s `setScreenShareEnabled` (T012), distinguish between cancellation/dismissal and outright denial in the catch block — both ultimately return `Left(ScreenShareDeniedFailure)`, but the message differentiates: `'cancelled'` vs `'denied'`. The presentation layer treats both as "OFF state restored, user-friendly SnackBar".
- [X] T029 [US3] In `video_call_screen.dart`'s `BlocListener` for `sideEvents` (T018), confirm the `CallScreenShareDenied` SnackBar message reads "Permission required to share your screen. Enable it in device settings." with an inline "Settings" action button that calls `AppSettings.openAppSettings()` (using the `app_settings` package, OR `permission_handler` if already present). If neither package is in pubspec, just show the SnackBar with no action button (still meets the FR).
- [ ] T030 [P] [US3] Manually verify Scenario 4 from [quickstart.md](quickstart.md) on both iOS and Android: install, sign in, start call, tap share, deny permission. Confirm app does not crash. Document any deviation here.

**Checkpoint**: Denial path is robust on both platforms; re-tap after deny re-prompts the OS dialog.

---

## Phase 6: User Story 4 - Sharing survives app backgrounding (Priority: P3)

**Goal**: Share continues when the sharer backgrounds the app, locks/unlocks the device, or switches to another app. Covers FR-015, Story 4 acceptance scenarios, and the Android foreground-service notification path.

**Independent Test**: With A sharing, A presses home + opens another app. B continues to see the new app's screen in real time on the share tile. A locks and unlocks the device: sharing continues. On Android, the foreground-service notification "Sharing your screen" is visible in the notification shade.

### Implementation for User Story 4

- [X] T031 [US4] In `lib/main.dart`'s `MainApp` state, the existing `WidgetsBindingObserver.didChangeAppLifecycleState` MUST NOT call `setScreenShareEnabled(false)` on `AppLifecycleState.paused` or `inactive` — only on `detached` (true app termination). Confirm or add this guard. (Existing socket disconnect logic on paused/detached must remain.)
- [X] T032 [US4] In Android: confirm that LiveKit's foreground service is started by livekit_client when `setScreenShareEnabled(true)` is called, and that the notification channel exists. If not, create the channel in `android/app/src/main/kotlin/.../MainActivity.kt` at app startup. The notification title must be "Sharing your screen" with a `STOP` action. **The STOP action does NOT need a custom intent → cubit bridge**: tapping it asks LiveKit's foreground service to stop the screen capture, which unpublishes the track, which fires `LocalTrackUnpublishedEvent` — already handled by the listener wired in T012a. Verify this flow end-to-end; only add a custom intent if LiveKit's default doesn't propagate the unpublish event.
- [ ] T033 [P] [US4] Manually verify Scenarios 6 and 7 from [quickstart.md](quickstart.md): A backgrounds the app while sharing, B continues to see live content. A taps the Android notification's STOP — share ends. Confirm same on iOS via the red recording banner.

**Checkpoint**: Sharing survives realistic app-switching usage; the OS-level stop path also works.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Teardown integration, automated tests, manual quickstart, and a backend smoke check.

- [X] T034 In `call_cubit.dart`, modify `endCall()`, `leaveGroupCall()`, and `reset()` so that BEFORE the existing socket/state cleanup, each method checks `state is CallActive && (state as CallActive).isLocallySharingScreen` and, if true, awaits `_repo.setScreenShareEnabled(false)` and emits the socket `isSharing: false` event. This satisfies the V-A logout sequence and prevents zombie iOS broadcasts.
- [ ] T035 [P] In `chat-app-backend/src/modules/chat/chat.gateway.ts`, double-check that the cleanup-on-disconnect logic from T005 actually catches all disconnect paths: `handleDisconnect()` (Socket.IO base), `leaveGroupCall`, `endCall`. Add a test in `chat.gateway.spec.ts` that simulates a sharer disconnecting without sending an explicit stop and asserts the Redis key is removed and a synthetic `screenShareStateChanged` (`isSharing: false`) is broadcast.
- [X] T036 [P] Create `test/features/video_call/presentation/bloc/call_cubit_screen_share_test.dart`: a `bloc_test` covering (a) startScreenShare happy path emits expected state and socket call, (b) startScreenShare when another sharer is active emits `CallScreenShareConflict` side-event and DOES NOT call repo, (c) startScreenShare with `ScreenShareDeniedFailure` from repo emits `CallScreenShareDenied` side-event, (d) stopScreenShare emits the cleanup state and socket event, (e) receiving a `screenShareStateChanged` for a remote user updates `activeSharer*` fields, (f) endCall while locally sharing calls `setScreenShareEnabled(false)` before disconnect.
- [ ] T037 Run all quickstart scenarios from [quickstart.md](quickstart.md) on two physical devices (one iOS, one Android ideally). For each scenario, **timestamp the relevant events** (icon-tap, OS-grant, first frame on receiver, in-app stop, tile removal) using either a stopwatch or `DateTime.now()` log lines. Verify:
    - **SC-001**: from icon-tap to "share active" requires ≤ 2 user taps on first use (icon → permission grant) and ≤ 1 tap after.
    - **SC-002**: receiver tile appears within ≤ **3 seconds** of sharer's grant. Fail the task if any run exceeds 3 s.
    - **SC-003**: receiver tile disappears within ≤ **5 seconds** of stop (tested via in-app tap, iOS banner Stop, AND Android notification Stop).
    - **SC-005 / FR-016 (performance)**: run Scenario 8 (newly added — see [quickstart.md](quickstart.md)) for explicit before/after camera frame-rate and call-audio quality comparison on identical device + network conditions. Visible degradation on the post-merge run blocks release.
    - **SC-006**: Scenario 6 runs for at least 5 continuous minutes with the sharer switching apps; no interruption.
    - **SC-007**: after force-kill of sharer (Scenario 5), receiver tile gone within 5 s AND `redis-cli GET screenshare:active:{room}` returns `(nil)`.
    
    Attach all timing measurements and log lines to the PR description. **DEFERRED to human runner — requires physical devices.**
- [ ] T038 [P] Backend smoke check: after each manual scenario run, execute `redis-cli KEYS 'screenshare:active:*'` and confirm no zombie locks remain. Document any leak.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: iOS T001-T002 are sequential (T002 depends on T001's target existing). T003 (Android), T004 (backend handler), T005 (backend cleanup) are independent.
- **Phase 2 (Foundational)**: Depends on nothing from Phase 1 except T004 (backend) needs to exist before the client can usefully emit. Phase 2 tasks T006, T007, T009 are parallel; T008 depends on T007; T010 depends on nothing; T011 depends on nothing.
- **Phase 3 (US1)**: Depends on Phase 2. Within: T012 (repo `setScreenShareEnabled`) → T012a (iOS/Android external-stop bridge — same file + domain interface) → T015/T016/T017 (cubit, T015 also registers the T012a callback) → T018-T020 (UI). T013 (sheet widget) parallel with T012.
- **Phase 4 (US2)**: Depends on Phase 3 (US1 already set up the cubit field + state + socket emitter). T021 (repo) → T022/T023 (cubit). T024 (tile widget) parallel with T021. T025/T026/T027 (UI) depend on T024.
- **Phase 5 (US3)**: Depends on Phase 3 (deny path lives inside the start flow). T028 → T029.
- **Phase 6 (US4)**: Depends on Phase 3 (need a share to background).
- **Phase 7 (Polish)**: T034 depends on Phase 3 + 4. T035 depends on T004. T036 depends on Phase 3 + 4. T037-T039 depend on everything.

### Parallel Opportunities

- T003 (Android manifest) ∥ T004 (backend handler) ∥ T005 (backend cleanup)
- T006 (failure type) ∥ T007 (socket callbacks) ∥ T009 (repo interface) ∥ T010 (state) ∥ T011 (side-events)
- T013 (sheet) ∥ T012 (repo impl)
- T020 (group call screen UI) ∥ T018/T019 (video call screen UI) — different files
- T024 (tile widget) ∥ T021 (repo)
- T026 (group grid) ∥ T025 (1:1 grid) ∥ T027 (notification snackbar)
- T035 (backend test) ∥ T036 (cubit test) ∥ T038 (Redis check)

---

## Parallel Example: User Story 1 implementation

```bash
# After T009/T010/T011 land, these can be wired in parallel:
Task: T012 — repo setScreenShareEnabled
Task: T013 — ScreenShareToggleSheet widget

# After T012-T017 land:
Task: T018 — video_call_screen icon + sheet wiring + side-event listener
Task: T020 — group_call_screen icon + sheet wiring (parallel; different file)
```

## Parallel Example: User Story 2 receive-side

```bash
Task: T024 — ScreenShareTile widget
Task: T021 — repo screenShareVideoTrackOf / AudioTrackOf
# Then:
Task: T025 — video_call_screen grid integration
Task: T026 — group_call_screen grid integration
Task: T027 — "X started sharing" SnackBar listener
```

---

## Implementation Strategy

### MVP Scope

**Phases 1 + 2 + 3 + 4 = MVP.** Both US1 (sharer side) and US2 (receive side) are P1 — without US2 the feature has no visible effect on other participants. Together they deliver "I can share, and everyone else sees it."

US3 (denial UX) and US4 (backgrounding) are robustness layers; the feature is demonstrable without them but not production-ready.

### Incremental Delivery Path

1. **Ship Phases 1-2 alone**: pure scaffolding, no user-visible change. Safe to merge to main as a separate PR.
2. **Ship Phases 3+4 (MVP)**: end-to-end screen share working on the happy path.
3. **Ship Phase 5 (US3)**: deny / dismiss UX hardened.
4. **Ship Phase 6 (US4)**: backgrounding + Android foreground service polish.
5. **Ship Phase 7 (Polish)**: teardown wiring, automated test, manual scenario evidence.

### Notes

- `[P]` tasks are different files with no in-flight dependency.
- Backend tasks (T001-T002 iOS, T003 Android, T004-T005 backend) sit in different repos / native targets and can ship to main independently of Flutter changes — they are backwards-compatible (the new socket event simply isn't used until clients call it).
- iOS T001 (target creation) requires Xcode UI interaction; commit the resulting `project.pbxproj` diff so other devs and CI inherit the new target.
- The bloc_test (T036) is the only automated coverage. Two-device manual verification (T037) is the gate for "feature complete."
