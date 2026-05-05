# Tasks: Comprehensive Refactoring & Bug Fix Batch

**Input**: Design documents from `/specs/005-refactor-bugfix-batch/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md

**Tests**: Not requested — manual verification only.

**Organization**: Tasks are grouped by user story mapped from the spec's 10 functional requirements across 5 plan groups.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Core Logic**: `lib/core/`
- **Chat Feature**: `lib/features/chat/`
- **Video Call Feature**: `lib/features/video_call/`
- **Auth Feature**: `lib/features/auth/`
- **Splash Feature**: `lib/features/splash/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create new files and constants that multiple user stories depend on.

- [ ] T001 Create `SocketEvents` constants class with all 24 socket event strings in `lib/core/network/socket_events.dart`
- [ ] T002 [P] Create `resolveMediaUrl()` utility function in `lib/core/utils/url_utils.dart` — reads base URL from `String.fromEnvironment('API_URL')` with same default as `DioClient`
- [ ] T003 [P] Add `GlobalKey<NavigatorState> globalNavigatorKey` at top level in `lib/core/routing/app_router.dart` and inject into `GoRouter(navigatorKey: globalNavigatorKey)`

**Checkpoint**: Foundation constants and keys are in place. All user stories can now proceed.

---

## Phase 2: User Story 1 – Crash-Free Call Initiation (Priority: P1) 🎯 MVP

**Goal**: Eliminate the "No GoRouter found in context" crash when initiating or receiving calls from overlays.

**Independent Test**: Initiate a video/voice call from `ChatRoomScreen` → no crash. Receive an incoming call on any screen → `CallOverlay` navigates correctly.

### Implementation for User Story 1

- [ ] T004 [US1] Replace hardcoded route strings in `redirect` block with `AppRouterName.*` constants and remove debug `/video` route in `lib/core/routing/app_router.dart`
- [ ] T005 [US1] Replace hardcoded `'/voice_call'` with `AppRouterName.voiceCall` in `lib/features/chat/presentation/widgets/call_overlay.dart` and use `globalNavigatorKey.currentContext!` for navigation
- [ ] T006 [P] [US1] Replace `'/home'` and `'/auth'` with `AppRouterName.*` constants in `lib/features/splash/presentation/pages/splash_screen.dart`
- [ ] T007 [P] [US1] Replace `'/home'` with `AppRouterName.home` in `lib/features/video_call/presentation/pages/video_call_screen.dart`
- [ ] T008 [P] [US1] Replace `'/video_call'` and `'/home'` with `AppRouterName.*` in `lib/features/video_call/presentation/pages/voice_call_screen.dart`
- [ ] T009 [P] [US1] Replace `'/video_call'` and `'/voice_call'` with `AppRouterName.*` in `lib/features/video_call/presentation/pages/outgoing_call_screen.dart`
- [ ] T010 [P] [US1] Replace `'/video_call'` and `'/voice_call'` with `AppRouterName.*` in `lib/features/video_call/presentation/pages/incoming_call_screen.dart`
- [ ] T011 [P] [US1] Replace `'/home'` with `AppRouterName.home` in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [ ] T012 [P] [US1] Replace `'/auth'` and `'/chat_room'` with `AppRouterName.*` in `lib/features/chat/presentation/pages/chat_list_screen.dart`
- [ ] T013 [P] [US1] Replace `'/home'` with `AppRouterName.home` in `lib/features/chat/presentation/pages/group_info_page.dart`
- [ ] T014 [P] [US1] Replace `'/home'` with `AppRouterName.home` in `lib/features/chat/presentation/pages/create_group_page.dart`
- [ ] T015 [P] [US1] Replace `'/video_call'` with `AppRouterName.videoCall` in `lib/features/auth/presentation/pages/auth_screen.dart`
- [ ] T016 [US1] Run `grep -rn "'/home'\|'/auth'\|'/video_call'\|'/voice_call'\|'/chat_room'" lib/` and verify zero hardcoded route strings remain outside `AppRouterName`

**Checkpoint**: All navigation uses `AppRouterName.*` constants. Call initiation from overlays uses `globalNavigatorKey` — zero crashes.

---

## Phase 3: User Story 2 – Reliable Typing Indicators (Priority: P1)

**Goal**: Typing indicators appear/disappear reliably in both chat room and chat list, with auto-expire safety net.

**Independent Test**: Two-device test — User A types, User B sees "typing…" in chat room + chat list. User A stops → indicator clears within 5s.

**Depends on**: T001 (SocketEvents)

### Implementation for User Story 2

- [ ] T017 [US2] Add per-user auto-expire `Timer` map (`_typingExpireTimers`) in `ChatCubit._initServices()` `onUserTyping` handler — start/reset a 5s timer on `isTyping: true`, clear user from set on fire — in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [ ] T018 [US2] In `ChatCubit.closeRoom()`, clear `_typingUsersByRoom[_activeRoomId]` and cancel all active typing expire timers for that room in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [ ] T019 [US2] Cancel all typing expire timers in `ChatCubit.close()` override to prevent post-dispose timer callbacks in `lib/features/chat/presentation/bloc/chat_cubit.dart`

**Checkpoint**: Typing indicators are reliable with a client-side auto-expire safety net.

---

## Phase 4: User Story 3 – Accurate Online/Offline Presence (Priority: P1)

**Goal**: Online/offline status updates propagate reactively to the UI within seconds.

**Independent Test**: Two-device test — User B goes offline → User A sees status change in chat room header and chat list within 5s.

### Implementation for User Story 3

- [ ] T020 [US3] In `ChatCubit._initServices()` `onUserStatusChanged` handler, after calling `_localDataSource.updateUserOnlineStatus()`, check if the changed `userId` matches the active room's participant and emit a `ChatRoomActive` state update with refreshed online status in `lib/features/chat/presentation/bloc/chat_cubit.dart`

**Checkpoint**: Presence indicator updates reactively without needing to close/reopen the room.

---

## Phase 5: User Story 4 – Consistent Route Navigation (Priority: P2)

**Goal**: All hardcoded route strings are eliminated. Only `AppRouterName.*` constants are used.

**Independent Test**: `grep -rn` for hardcoded route strings returns zero results outside `AppRouterName`.

> **Note**: This user story is already fully implemented by T004–T016 in Phase 2. No additional tasks needed.

**Checkpoint**: Already verified at T016.

---

## Phase 6: User Story 5 – Centralized Socket Event Constants (Priority: P2)

**Goal**: All socket event strings in `SocketService` reference `SocketEvents.*` constants.

**Independent Test**: `grep -rn` for hardcoded event strings in `socket_service.dart` returns zero results.

**Depends on**: T001 (SocketEvents class)

### Implementation for User Story 5

- [ ] T021 [US5] Import `socket_events.dart` and replace all hardcoded event strings in `_socket?.on(...)` calls with `SocketEvents.*` constants in `lib/core/network/socket_service.dart`
- [ ] T022 [US5] Replace all hardcoded event strings in `_socket?.emit(...)` calls with `SocketEvents.*` constants in `lib/core/network/socket_service.dart`
- [ ] T023 [US5] Run `grep -rn "'messageSent'\|'receiveMessage'\|'typing'\|'joinRoom'" lib/core/network/socket_service.dart` and verify zero hardcoded socket strings remain

**Checkpoint**: All socket events are centralized. Typo risk eliminated.

---

## Phase 7: User Story 6 – Correct Block User Payload (Priority: P2)

**Goal**: Block user API sends user ID, not phone number.

**Independent Test**: Block a user from `ChatInfoScreen` → inspect network payload confirms user ID in path.

### Implementation for User Story 6

- [ ] T024 [US6] Audit block user call chain from `chat_info_screen.dart` → `ChatCubit.blockUser()` → `ChatRepository.blockUser()` → `ChatRemoteDataSource.blockUser()` and verify `targetUserId` (not phone) is passed at every level. Fix `ChatInfoScreen._blockUser()` if it resolves the wrong identifier from `chatData` in `lib/features/chat/presentation/pages/chat_info_screen.dart`

**Checkpoint**: Block API is verified to send the correct identifier.

---

## Phase 8: User Story 7 – Correct Media Image Display (Priority: P2)

**Goal**: All shared images in `ChatInfoScreen` load correctly with fully qualified URLs.

**Independent Test**: Open `ChatInfoScreen` with shared media → all images display correctly, no broken placeholders.

**Depends on**: T002 (url_utils.dart)

### Implementation for User Story 7

- [ ] T025 [US7] In `_buildMediaSection()` of `ChatInfoScreen`, import `url_utils.dart` and wrap image URLs with `resolveMediaUrl()` before passing to `CachedNetworkImage` in `lib/features/chat/presentation/pages/chat_info_screen.dart`

**Checkpoint**: All media images resolve correctly regardless of relative/absolute URL format.

---

## Phase 9: User Story 8 – Clean Codebase Without Dead Code (Priority: P3)

**Goal**: Remove vestigial `connect()`, `disconnect()`, `sendMessage()` methods from the chat data layer.

**Independent Test**: Build the app — zero compilation errors. Grep confirms dead methods are gone.

### Implementation for User Story 8

- [ ] T026 [P] [US8] Remove `connect()`, `disconnect()`, `sendMessage(String text)` from abstract class in `lib/features/chat/data/datasources/chat_remote_data_source.dart` and remove their empty implementations from `ChatRemoteDataSourceImpl`
- [ ] T027 [P] [US8] Remove `connect()`, `disconnect()`, `sendMessage(String text)` from abstract interface in `lib/features/chat/domain/repositories/chat_repository.dart`
- [ ] T028 [US8] Remove `connect()`, `disconnect()`, `sendMessage(String text)` overrides from `ChatRepositoryImpl` in `lib/features/chat/data/repositories/chat_repository_impl.dart`
- [ ] T029 [US8] Run `grep -rn "Future<void> connect\|Future<void> disconnect\|Future<void> sendMessage(String" lib/features/chat/` and verify zero dead method signatures remain

**Checkpoint**: Data layer is clean. No dead code. Build passes.

---

## Phase 10: User Story 9 – Media & Waveform Optimization (Priority: P1)

**Goal**: Eliminate media reloading on scroll, slow image opens, and waveform recalculation.

**Independent Test**: Scroll a voice note out and back → waveform renders instantly (no spinner). Scroll an image out and back → image appears from cache instantly. 60fps smooth scroll with 50+ media messages.

### Implementation for User Story 9

- [ ] T030 [US9] Add `AutomaticKeepAliveClientMixin` to `_VoiceBubbleState` with `wantKeepAlive => true` so voice note state (player, waveform, playback position) survives ListView recycling in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [ ] T031 [US9] Decouple waveform rendering from player readiness — in `_VoiceBubbleState.initState()`, synchronously populate `_cachedWaveformData` from `message.metadata['waveformSamples']` and render static waveform bars immediately (no spinner) while `_preparePlayer()` runs in background in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [ ] T032 [P] [US9] Add `cacheKey: message.id` to all `CachedNetworkImage` instances in `_ImageBubble` and `_VideoBubble` to stabilize disk cache keying in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [ ] T033 [US9] Add `cacheExtent: 500.0` and explicit `addAutomaticKeepAlives: true` to the `ListView.builder` in `lib/features/chat/presentation/pages/chat_room_screen.dart`

**Checkpoint**: Media scrolling is WhatsApp-smooth. No reload flicker. No waveform spinners on scroll-back.

---

## Phase 11: User Story 10 – Zero Loading Time Room Entry (Priority: P1)

**Goal**: Opening a chat room shows messages instantly from SQLite with zero loading state.

**Independent Test**: Open a chat with cached messages → content appears in <50ms with zero `CircularProgressIndicator`. Open while offline → cached messages display normally.

### Implementation for User Story 10

- [ ] T034 [US10] In `ChatCubit.openRoom()`, remove `emit(ChatLoading())` (line 335). Before subscribing to `watchRoomMessages`, do `await getRoomMessages(roomId)` and immediately `emit(ChatRoomActive(roomId, cachedMessages))` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [ ] T035 [US10] In `ChatRoomScreen` `BlocConsumer`, replace `ChatLoading` → `CircularProgressIndicator` (line 344-348) with an empty state widget (e.g., "Start a conversation…") for empty `ChatRoomActive`. Remove `ChatLoading` from `listenWhen` in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [ ] T036 [US10] Optimize `ChatLocalDataSourceImpl.watchRoomMessages()` to emit initial batch synchronously via `StreamController.onListen` callback instead of awaiting the async `getRoomMessages()` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [ ] T037 [US10] In `ChatCubit.loadMoreMessages()`, add fallback: if `getRoomMessages` returns fewer than `_pageSize` results, trigger background `fetchRoomMessages(roomId)` API call to fetch deeper history from server — save to SQLite and let stream auto-update in `lib/features/chat/presentation/bloc/chat_cubit.dart`

**Checkpoint**: Chat rooms open instantly. Zero loading spinners. Background sync is transparent.

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across all groups.

- [ ] T038 Run full `flutter build apk --debug` to verify zero compilation errors after all dead code removal and refactoring
- [ ] T039 Run grep verification suite: hardcoded routes (zero), hardcoded socket events (zero), dead methods (zero), ChatLoading in chat_room_screen (zero), AutomaticKeepAliveClientMixin in message_bubble_widget (present)
- [ ] T040 Manual smoke test: initiate call → no crash, typing indicator → appears/clears, presence → updates, block user → correct payload, media images → load, voice note scroll → no spinner, room open → instant

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (US1 Routing)**: Depends on T003 — then all route replacements are parallelizable
- **Phase 3 (US2 Typing)**: Depends on T001 (SocketEvents) — independent of US1
- **Phase 4 (US3 Presence)**: Independent — can run parallel with US1/US2
- **Phase 5 (US4 Routes)**: Already completed by Phase 2
- **Phase 6 (US5 Socket Constants)**: Depends on T001 — can run parallel with US2
- **Phase 7 (US6 Block Payload)**: Independent — can run anytime
- **Phase 8 (US7 Media URLs)**: Depends on T002 — can run parallel with other phases
- **Phase 9 (US8 Dead Code)**: Independent — can run anytime
- **Phase 10 (US9 Media Perf)**: Independent — modifies different files
- **Phase 11 (US10 Zero Load)**: Independent — modifies `chat_cubit.dart` (same file as US2/US3, so serialize after them)
- **Phase 12 (Polish)**: Depends on all phases complete

### User Story Dependencies

- **US1 (Routing/Crash)**: Depends on T003 only. All route replacements T004-T015 are parallel.
- **US2 (Typing)**: Independent of US1. Modifies `chat_cubit.dart` (shared file).
- **US3 (Presence)**: Independent. Also modifies `chat_cubit.dart` — serialize with US2.
- **US5 (Socket Constants)**: Depends on T001. Independent of all other stories.
- **US6 (Block Payload)**: Fully independent.
- **US7 (Media URLs)**: Depends on T002. Independent.
- **US8 (Dead Code)**: Fully independent. All 3 files are parallel.
- **US9 (Media Perf)**: Independent. Modifies `message_bubble_widget.dart` + `chat_room_screen.dart`.
- **US10 (Zero Load)**: Modifies `chat_cubit.dart` + `chat_room_screen.dart` + `chat_local_data_source.dart`. Serialize after US2/US3 (shared cubit file).

### Parallel Opportunities

```
After T001 + T002 + T003 complete (Setup):

Parallel track A: T004-T016 (US1 route constants — all files independent)
Parallel track B: T021-T023 (US5 socket constants)
Parallel track C: T024 (US6 block payload)
Parallel track D: T025 (US7 media URLs)
Parallel track E: T026-T029 (US8 dead code — 3 files parallel)

Sequential track (shared chat_cubit.dart):
T017-T019 (US2) → T020 (US3) → T034, T037 (US10)

Sequential track (shared chat_room_screen.dart):
T011, T033 (US1+US9 cacheExtent) → T035 (US10 remove loading)
```

---

## Implementation Strategy

### MVP First (US1 + US9 + US10)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: US1 Routing/Crash (T004-T016)
3. Complete Phase 10: US9 Media Performance (T030-T033)
4. Complete Phase 11: US10 Zero Loading (T034-T037)
5. **STOP and VALIDATE**: Test call initiation, media scroll, room open
6. App is crash-free with WhatsApp-level performance

### Full Delivery

1. Setup → US1 (routing) → US2 (typing) → US3 (presence) → US5 (socket constants) → US6 (block) → US7 (media URLs) → US8 (dead code) → US9 (media perf) → US10 (zero load) → Polish

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- `chat_cubit.dart` is modified by US2, US3, and US10 — execute these sequentially
- `chat_room_screen.dart` is modified by US1, US9, and US10 — execute these sequentially
- No unit tests — verification is manual device testing + grep assertions
- Commit after each phase checkpoint
