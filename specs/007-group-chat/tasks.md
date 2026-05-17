---
description: "Task list for Group Chat feature (messaging + group calls + shared call recording)"
---

# Tasks: Group Chat (with Group Calls and Shared Call Recording)

**Input**: Design documents from `/specs/007-group-chat/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅
**Last revised**: 2026-05-16 — added Sub-Phases 8e–8h for FR-032a (format auto-select),
FR-035 (gallery save + share to group chat), FR-036 (retry), FR-038 (Join Call AppBar).

**Tests**: Test tasks are OPTIONAL per the spec — included where they catch regressions cheaply (e.g., `ChatCubit.handleMessageStatusUpdate` group-read gate). Skip with no concern if not wanted.

**Organization**: Tasks are grouped by user story (US1–US6) to enable independent implementation, testing, and delivery.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps to user stories from spec.md (US1, US2, US3, US4, US5, US6)
- File paths are absolute project-root-relative for Flutter; backend paths prefixed `BACKEND:` and are relative to `/Volumes/Zeyad/Documents/work/Node js/chat-app-backend/`.

## Path Conventions

- **Flutter**: `lib/features/<feature>/{data,domain,presentation}/...`
- **Flutter Core**: `lib/core/...`
- **Backend**: `BACKEND: src/modules/<module>/...`
- **Tests**: `test/features/<feature>/...`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project-wide preparation that every later phase will rely on.

- [X] T001 Add socket event name constants for new group-call and recording events in `lib/core/network/socket_events.dart` — constants: `requestGroupCall`, `incomingGroupCall`, `acceptGroupCall`, `declineGroupCall`, `leaveGroupCall`, `groupCallParticipantJoined`, `groupCallParticipantLeft`, `groupCallRecordingStateChanged`, **`groupCallActive`**, **`groupCallEnded`** (the last two are required for FR-038 Join Call AppBar — added per 2026-05-16 spec revision)
- [X] T002 [P] Move LiveKit WebSocket URL from hardcoded value in `lib/features/video_call/presentation/bloc/video_call_cubit.dart` to `AppConstants.liveKitWsUrl` in `lib/core/theme/app_constants.dart`; read via `dotenv.maybeGet('LIVEKIT_WS_URL')` with the current value as fallback default
- [X] T003 [P] Add `LIVEKIT_WS_URL=wss://ciro-chat-qc2pe2cz.livekit.cloud` to `.env` at project root
- [X] T004 Create new feature directory structure for call recording: `lib/features/call_recording/{data/{datasources,models},domain/{entities,repositories},presentation/{bloc,pages,widgets}}/`
- [X] T005 [P] Add new Flutter routes in `lib/core/routing/app_router.dart` for `/group/:roomId/call`, `/group/:roomId/incoming-call`, `/recordings`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Cross-story building blocks that all user stories depend on. Complete before starting any Phase 3+.

### Backend foundational changes

- [X] T006 BACKEND: Change `leaveGroup()` admin succession in `src/modules/chat/chat.service.ts` to promote `remainingParticipants[0]` (earliest joiner) instead of a random participant, and return the new admin's phone number in the response
- [X] T007 BACKEND: Extend `markMessagesRead()` in `src/modules/chat/chat.service.ts` to compute `readByCount` and `participantCount` for GROUP rooms, and include both fields in the `messageRead` socket emit payload (private rooms continue to emit the legacy shape without the new fields)
- [X] T008 BACKEND: Tighten `POST /video/room/:roomId/join` in `src/modules/video/video.service.ts` to verify the requesting user is a current participant of the `ChatRoom`; return `403 Forbidden` otherwise

### Flutter foundational SocketService extensions

- [X] T009 Add new event handlers in `lib/core/network/socket_service.dart` (skeletons + typed callback fields) for: `incomingGroupCall`, `groupCallParticipantJoined`, `groupCallParticipantLeft`, `groupCallRecordingStateChanged`. All handlers MUST use the `if (data == null || data is! Map) return; final map = Map<String,dynamic>.from(data);` safe-cast pattern per Constitution §IV-A
- [X] T010 Add new emitter methods in `lib/core/network/socket_service.dart`: `requestGroupCall(roomId, isVideo)`, `acceptGroupCall(roomId)`, `declineGroupCall(roomId)`, `leaveGroupCall(roomId)`, `emitGroupCallRecordingStateChanged(roomId, isRecording, hasVideo)`

### Flutter SQLite migration

- [X] T011 Add SQLite migration v9 in `lib/features/chat/data/datasources/chat_local_data_source.dart`: CREATE TABLE with all fields per data-model.md §3 — `id TEXT PRIMARY KEY, call_room_id TEXT NOT NULL, call_room_name TEXT NOT NULL, file_path TEXT NOT NULL, gallery_path TEXT, duration_ms INTEGER NOT NULL DEFAULT 0, has_video INTEGER NOT NULL DEFAULT 0, size_bytes INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, display_name TEXT NOT NULL, share_status TEXT NOT NULL DEFAULT 'idle', shared_message_id TEXT` — plus three indexes: `idx_recordings_created_at ON recordings(created_at DESC)`, `idx_recordings_call_room ON recordings(call_room_id)`, `idx_recordings_share_status ON recordings(share_status)`. Bump database version to 9 and add the migration block to the existing `onUpgrade` switch

**Checkpoint**: Foundation ready — backend payload contract + Flutter event scaffolding + DB schema in place. User story phases can now proceed in parallel.

---

## Phase 3: User Story 1 — Create a Group (Priority: P1) 🎯 MVP

**Goal**: A user can create a group with a name, optional photo, and at least one other member; the group is immediately visible to all selected members.

**Independent Test**: On Device A, open `CreateGroupPage`, enter name + pick avatar + select user B → tap Create. ✅ Group appears on Device B within 2 s with the chosen avatar.

### Implementation for User Story 1

- [X] T012 [US1] Add a circular avatar tap-target widget at the top of `lib/features/chat/presentation/pages/create_group_page.dart`; tapping opens the existing image picker flow (use the same gallery picker `ChatCubit.pickImageFromGallery` already wires up)
- [X] T013 [US1] In `lib/features/chat/presentation/pages/create_group_page.dart`, on image selection upload via `ChatCubit.uploadFile(file)` (or the underlying `ChatRemoteDataSource.uploadFile`) and store the returned `fileUrl` in a local `_avatarUrl: String?` state field; show a small spinner overlay while uploading
- [X] T014 [US1] Pass `_avatarUrl` to `ChatCubit.createGroup(groupName, selectedIds, avatarUrl: _avatarUrl)` in the `_createGroup()` method of `lib/features/chat/presentation/pages/create_group_page.dart`
- [X] T015 [US1] Verify `ChatRemoteDataSource.createGroup` in `lib/features/chat/data/datasources/chat_remote_data_source.dart` forwards `avatarUrl` in the `POST /chat/group/create` body (already implemented per research — confirm only)
- [X] T016 [US1] Add error handling: if avatar upload fails, surface a user-friendly snackbar via `ScaffoldMessenger` and allow group creation to proceed without an avatar (FR-004)
- [ ] T017 [US1] Test on two devices: avatar shows in conversations list, group chat header, and on the second device within 2 s (per SC-001)

**Checkpoint**: Groups can be created with a custom photo. MVP slice complete.

---

## Phase 4: User Story 2 — Send and Receive Messages in a Group (Priority: P1)

**Goal**: Group members exchange real-time messages with sender names visible above inbound bubbles. All existing message types (text, image, video, voice) work.

**Independent Test**: Two members open a group → A sends text + image → B receives both with A's name above the bubbles; typing indicator on either side shows the typing member's name.

### Implementation for User Story 2

- [ ] T018 [US2] Create new widget `lib/features/chat/presentation/widgets/group_sender_name.dart` — a small label widget that takes `displayName` and renders it as a single line above a message bubble; styled with `AppTypography.caption` and `AppColors.primary` for visual distinction
- [ ] T019 [US2] Open `lib/features/chat/presentation/pages/group_chat_screen.dart`. **Delete the entire current stub implementation** and replace it with a real ChatCubit-driven screen modeled on the existing 1-to-1 `ChatScreen` (find it under `lib/features/chat/presentation/pages/chat_screen.dart`): `BlocBuilder<ChatCubit, ChatState>`, `MessagesList`, `ChatInputBar`, scroll controller, media gallery navigation
- [ ] T020 [US2] In the new `group_chat_screen.dart`, in the message list builder: when `message.senderId != currentUserId` AND `chatSession.type == ChatRoomType.GROUP`, render `GroupSenderName(displayName: resolvedSenderName)` above the bubble. The resolved name comes from the existing contact-lookup logic already used in the conversations list (lookup by `senderPhone`)
- [ ] T021 [US2] Confirm the typing indicator in `group_chat_screen.dart` shows the typing member's name (existing `onUserTyping` callback in `SocketService` already delivers `phoneNumber` — resolve to display name via the existing contact lookup)
- [ ] T022 [US2] Ensure `group_chat_screen.dart` calls `ChatCubit.openRoom(roomId)` in initState and `ChatCubit.closeRoom()` in dispose so the active-room context is set correctly (matches existing 1-to-1 lifecycle)
- [ ] T023 [US2] Verify route entry in `lib/core/routing/app_router.dart` for `/group/:roomId/chat` maps to `GroupChatScreen` and passes the `ChatSession` arg correctly
- [ ] T024 [US2] Two-device test: text, image, video, voice — all delivered in <2 s with sender name on inbound bubbles (SC-002, SC-003)

**Checkpoint**: Group messaging is fully functional. MVP (US1 + US2) shippable here.

---

## Phase 5: User Story 3 — Message Delivery and Read Status in Groups (Priority: P2)

**Goal**: Sender's tick indicators correctly reflect delivery and read state across all group members. Blue ticks appear only when ALL members have read (excluding sender).

**Independent Test**: A sends a message in a 3-member group → ticks progress sent → delivered → read only after the third member opens the chat (not after only one).

### Tests for User Story 3 (Optional but recommended)

- [ ] T025 [P] [US3] Unit test in `test/features/chat/chat_cubit_group_read_test.dart`: simulate `messageRead` socket event with `readByCount: 1, participantCount: 3` → assert status stays `delivered`; then `readByCount: 3, participantCount: 3` → assert status becomes `read`; then private-chat payload without counts → assert status becomes `read` immediately

### Implementation for User Story 3

- [X] T026 [US3] Modify `ChatCubit.handleMessageStatusUpdate` in `lib/features/chat/presentation/bloc/chat_cubit.dart` to inspect the optional `readByCount` and `participantCount` fields. If both are present, only promote `delivered → read` when `readByCount >= participantCount`. If absent (private chat), retain existing immediate promotion (backwards-compatible)
- [X] T027 [US3] In `lib/core/network/socket_service.dart`, update the `messageRead` event handler to forward the new optional fields to `onMessageRead`. Extend the callback signature OR pass through a `Map` — pick the lower-impact option (likely: extend callback to `void Function(List<String> ids, {int? readByCount, int? participantCount})`)
- [X] T028 [US3] Update the `onMessageRead` consumer in `ChatCubit` to use the extended signature; verify pure messaging tests still pass
- [ ] T029 [US3] Two-device + 1-emulator test: confirm blue ticks appear only after all non-sender members have opened the chat

**Checkpoint**: Group read receipts behave per WhatsApp convention (all-read).

---

## Phase 6: User Story 4 — Group Info and Settings (Priority: P2)

**Goal**: Members can view group info; admin can edit name, change photo, and remove members; non-admins see member list only.

**Independent Test**: Admin opens group info → renames to "Renamed" → all members' conversations list shows the new name within 3 s. Non-admin opens same info → no Remove option.

### Implementation for User Story 4

- [X] T030 [US4] In `lib/features/chat/presentation/pages/group_info_page.dart`, replace the static group name display with a tappable `ListTile` (admin only) that opens an inline `TextField` or `AlertDialog` for renaming; on Save call a new `ChatCubit.updateGroupName(roomId, newName)`
- [X] T031 [US4] Add `updateGroupName(roomId, newName)` to `lib/features/chat/presentation/bloc/chat_cubit.dart` that calls a new `ChatRemoteDataSource.updateGroupName(roomId, name)` and updates the local SQLite row optimistically
- [X] T032 [US4] Add `updateGroupName` method to `lib/features/chat/data/datasources/chat_remote_data_source.dart`. If the backend lacks a dedicated endpoint, use the existing group create/update pattern; otherwise add a new endpoint `PATCH /chat/group/:roomId` (see T033)
- [X] T033 [P] [US4] BACKEND: Add `PATCH /chat/group/:roomId` in `src/modules/chat/chat.controller.ts` and corresponding service method to update group name and/or `avatarUrl` (admin-only). On success, emit a `chatRoomUpdated` socket event to all participants
- [X] T034 [US4] Add `chatRoomUpdated` socket handler in `lib/core/network/socket_service.dart` (with safe-cast) and consume it in `ChatCubit` to refresh local room data when name or avatar changes
- [X] T035 [US4] In `lib/features/chat/presentation/pages/group_info_page.dart`, make the group avatar tappable (admin only); reuse `ChatCubit.pickImageFromGallery` → upload → `ChatCubit.updateGroupAvatar(roomId, avatarUrl)`. Add the `updateGroupAvatar` cubit method (uses the same `PATCH /chat/group/:roomId` endpoint)
- [X] T036 [US4] In `group_info_page.dart`, hide or disable any admin-only actions (rename, change photo, remove member) when `currentUserPhone` is not in `chatSession.admins` (FR-018)
- [X] T037 [US4] Verify the existing add-participants sheet (`_AddParticipantsSheet` already in `group_info_page.dart`) and remove-participant dialog continue to work after the admin-gating logic is added
- [X] T038 [US4] Add a "Leave Group" `ListTile` (red text) at the bottom of `group_info_page.dart`; tapping opens a confirmation dialog; on confirm call `ChatCubit.leaveGroup(roomId)` (add method to ChatCubit if not present — it calls `ChatRemoteDataSource.leaveGroup` already implemented per research)
- [X] T039 [US4] After successful leave, navigate the user to the conversations list (`context.go(AppRouterName.home)`) and ensure the local room state reflects "no longer participant" (FR-030)

**Checkpoint**: Group info management is fully functional. Admins can manage; members can read-only view and leave.

---

## Phase 7: User Story 5 — Admin Succession and Group Exit (Priority: P3)

**Goal**: Non-admin members leave freely; when admin leaves, system auto-promotes the longest-standing member (earliest joiner) without manual intervention.

**Independent Test**: 3-member group with A as admin → A leaves → backend response includes `newAdmin: B`'s phone (assuming B joined before C); group on B and C reflects B as new admin within 3 s.

### Implementation for User Story 5

- [X] T040 [US5] (Mostly covered by T006 — verification task.) Manually test: create a group with 3 ordered participants → admin leaves → verify `POST /chat/group/:roomId/leave` response contains `newAdmin` = `participants[0]` (excluding the leaver)
- [X] T041 [US5] In `lib/features/chat/presentation/pages/group_info_page.dart`, when the admin taps "Leave Group", show a confirmation dialog that explicitly states: "You will leave this group. The earliest-joining member will be promoted to admin." (FR-020 transparency)
- [X] T042 [US5] In `ChatCubit.leaveGroup` (added in T038), after the REST response, update the local SQLite `rooms.admins` field with the returned `newAdmin` if non-null. Use the existing `updateRoom` flow to keep the change reactive
- [X] T043 [US5] Verify FR-031: when a user is removed/leaves, no further socket events for that room are processed locally. Add a guard in `ChatCubit`'s `onNewMessage` handler: skip if `incoming.roomId` corresponds to a room where the local user is no longer in `participants`

**Checkpoint**: Admin succession is deterministic and transparent. Removed/left members get read-only mode (FR-029 enforced naturally because backend won't emit to them).

---

## Phase 8: User Story 6 — Group Voice and Video Calls + Recording (Priority: P2)

**Goal**: Any group member can start a group voice or video call. Multiple members can join. Any participant can record — format auto-matches the call type. On stop, the file is saved to gallery/Downloads AND shared as a group chat media message visible to all members. A REC indicator is visible to all participants. A "Join Call" pill appears in the group chat AppBar while a call is active.

**Independent Test**: 3-member group → A starts video call → B and C accept → all three see/hear each other; A records 30 s → B and C see REC banner; A stops → banner disappears; within 30 s a video media message appears in the group chat (B can tap and play it); on Device A a file appears in Photos/Gallery; the Recordings list shows ✓ (shared) status.

### Sub-Phase 8a: Backend Signaling

- [X] T044 [US6] BACKEND: In `src/modules/chat/chat.gateway.ts`, maintain `activeGroupCalls: Map<chatRoomId, Set<userId>>` alongside the existing `activeCalls` map
- [X] T045 [US6] BACKEND: Add `@SubscribeMessage('requestGroupCall')` handler in `chat.gateway.ts`
- [X] T046 [US6] BACKEND: Add `@SubscribeMessage('acceptGroupCall')` handler in `chat.gateway.ts`
- [X] T047 [US6] BACKEND: Add `@SubscribeMessage('declineGroupCall')` in `chat.gateway.ts`
- [X] T048 [US6] BACKEND: Add `@SubscribeMessage('leaveGroupCall')` in `chat.gateway.ts`
- [X] T049 [US6] BACKEND: Add `@SubscribeMessage('groupCallRecordingStateChanged')` handler in `chat.gateway.ts`
- [X] T050 [US6] BACKEND: In `chat.gateway.ts` `handleDisconnect`, cleanup group calls on disconnect

### Sub-Phase 8b: Flutter Domain & CallCubit Extensions

- [X] T051 [US6] Create domain entity `lib/features/video_call/domain/entities/call_participant.dart`
- [X] T052 [US6] Extend `CallActive` with `participants`, `isGroupCall`, `RecordingState`; extend `CallIncoming` with `isGroupCall`, `chatRoomId`, `groupName`
- [X] T053 [US6] Add `startGroupCall` to `call_cubit.dart`
- [X] T054 [US6] Handle `incomingGroupCall` socket callback in `call_cubit.dart`
- [X] T055 [US6] Add `acceptGroupCall` to `call_cubit.dart`
- [X] T056 [US6] Add `declineGroupCall` and `leaveGroupCall` to `call_cubit.dart`
- [X] T057 [US6] Handle `groupCallParticipantJoined/Left` in `call_cubit.dart`
- [X] T058 [US6] Handle `groupCallRecordingStateChanged` in `call_cubit.dart`

### Sub-Phase 8c: Flutter UI

- [X] T059 [US6] Create `IncomingGroupCallScreen` with Accept/Decline wired to CallCubit
- [X] T060 [US6] Create `GroupCallScreen` with LiveKit participant grid, mute/camera/end controls, REC banner
- [X] T061 [US6] Reuse LiveKit SDK track rendering in `group_call_screen.dart`
- [X] T062 [US6] `GroupCallScreen` directly owns its own `Room` instance (no repo wrapper needed)
- [X] T063 [US6] Update `call_overlay.dart` to route group calls to correct screens
- [X] T064 [US6] `_RecordingBanner` widget embedded in `group_call_screen.dart`
- [X] T065 [US6] Add "Start Call" action to group chat screen AppBar

### Sub-Phase 8d: Recording Infrastructure (original local-only; now extended by 8g–8h)

- [X] T066 [US6] Create domain entity `lib/features/call_recording/domain/entities/recording.dart` per data-model.md (id, callRoomId, callRoomName, filePath, durationMs, hasVideo, sizeBytes, createdAt, displayName). Extend `Equatable`
- [X] T067 [US6] Create model `lib/features/call_recording/data/models/recording_model.dart` extending `Recording` with `toMap()` / `fromMap()` for SQLite serialization
- [X] T068 [US6] Create abstract repository `lib/features/call_recording/domain/repositories/recordings_repository.dart` with methods: `Future<Either<Failure, Recording>> save(Recording r)`, `Future<Either<Failure, List<Recording>>> list()`, `Future<Either<Failure, void>> delete(String id)`, `Future<Either<Failure, void>> rename(String id, String newName)`
- [X] T069 [US6] Create `lib/features/call_recording/data/datasources/recordings_local_data_source.dart` implementing CRUD over the `recordings` SQLite table (added in T011). Use the existing `ChatLocalDataSource` database instance — inject it via `get_it`
- [X] T070 [US6] Create concrete `lib/features/call_recording/data/repositories/recordings_repository_impl.dart` implementing the abstract repository
- [X] T071 [US6] Annotate the data source and repository with `@injectable` / `@LazySingleton(as: RecordingsRepository)` and re-run `dart run build_runner build --delete-conflicting-outputs`
- [X] T072 [US6] Create `lib/features/call_recording/presentation/bloc/call_recording_cubit.dart` with initial audio-only recording pipeline (states: Idle/Recording/Stopping/Saved/Failure; start() uses `record: ^6.2.0` with AAC/M4A encoding). **NOTE**: This is superseded by T104–T106 which add format auto-selection, gallery save, and chat sharing. Complete T104–T106 before shipping.
- [X] T073 [US6] Add a "Record" toggle button to `group_call_screen.dart` (T060): tapping calls `CallRecordingCubit.start(callRoomId, callRoomName)` or `.stop()` based on current state
- [X] T074 [US6] Create `lib/features/call_recording/presentation/pages/recordings_list_page.dart`: list of recordings ordered by `createdAt DESC`; each row shows `displayName`, duration, file size, formatted date; tapping plays via `just_audio` (existing); long-press shows Rename / Delete actions. **NOTE**: Extended by T107 to add share-status icons + video playback + retry action.
- [X] T075 [US6] Register the `/recordings` route in `lib/core/routing/app_router.dart` mapping to `RecordingsListPage`
- [X] T076 [US6] Add a "Recordings" entry in the conversation/group settings menu (or a fast-access button in `group_call_screen.dart`) to navigate to `/recordings`
- [X] T077 [US6] Handle orphan-recording recovery on app start: in `RecordingsLocalDataSource.list()`, scan `<docs>/recordings/` for files with no DB row, insert default rows with mtime-based `createdAt` (FR-035 robustness)
- [X] T078 [US6] In `CallCubit`, when the call ends (any path), if `CallRecordingCubit.state is Recording`, auto-call `CallRecordingCubit.stop()` so the recording is finalized cleanly (FR-037-adjacent: stop recording when call ends)

**Checkpoint (8a–8d)**: Group calls work end-to-end. Participants can locally record and review in the list. Share pipeline and Join Call button are added in Sub-Phases 8e–8h below.

---

### Sub-Phase 8e: Backend Extensions for Active-Call Tracking + Join Call (FR-038, RD-4, RD-5)

- [X] T087 [US6] BACKEND: In `chat.gateway.ts`, extend the `ActiveGroupCall` tracking object to additionally store `recorders: Set<userId>`, `startedAt: Date`, and `isVideo: boolean` (per data-model.md §3a). Update `handleGroupCallRecordingStateChanged` to add/remove the socket's userId from `activeGroupCalls[chatRoomId].recorders` when `isRecording` is true/false
- [X] T088 [US6] BACKEND: In `chat.gateway.ts`, extend `handleRequestGroupCall` to broadcast `groupCallActive { chatRoomId, callerId, callerName, isVideo, participantCount: 1, startedAt }` to **all** room members (including the caller) immediately after creating the `activeGroupCalls` entry and fanning out `incomingGroupCall`. This event drives the Join Call AppBar pill on all group members' devices (FR-038)
- [X] T089 [US6] BACKEND: In `chat.gateway.ts`, extend `handleLeaveGroupCall` to broadcast `groupCallEnded { chatRoomId, reason: 'last-participant' }` to all room members and delete `activeGroupCalls[chatRoomId]` when `participants.size` drops to 1. Also extend `handleAcceptGroupCall` to include `currentRecorders: [...activeGroupCalls[chatRoomId].recorders]` in the response sent to the joining client (closes FR-033 late-joiner REC banner gap — RD-5)
- [X] T090 [US6] BACKEND: In `chat.gateway.ts` `handleConnection`, after the socket authenticates, look up all chat rooms the user belongs to. For each room with an entry in `activeGroupCalls`, emit `groupCallActive { chatRoomId }` to that socket so the Flutter `ChatCubit` can hydrate `_activeCallRoomIds` on reconnect / cold app open (FR-038 replay-on-connect, RD-4)
- [X] T091 [US6] BACKEND: In `chat.gateway.ts`, extend `handleGroupCallRecordingStateChanged` to forward `hasVideo: boolean` from the incoming payload in the outgoing rebroadcast so that other participants and late joiners can determine the recording format (FR-032a banner context)

### Sub-Phase 8f: Flutter Active-Call State + Join Call AppBar (FR-038)

- [X] T092 [P] [US6] Add `gal: ^2.3.0` and `flutter_screen_recording: ^2.0.0` (or the package selected via research.md RD-1) to `pubspec.yaml`; run `flutter pub get`
- [X] T093 [P] [US6] Add Android permissions to `android/app/src/main/AndroidManifest.xml` for screen recording: `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>` and a foreground service entry with `android:foregroundServiceType="mediaProjection"` inside `<application>` (required by flutter_screen_recording on Android; iOS uses ReplayKit with no extra permission)
- [X] T094 [US6] In `lib/core/network/socket_service.dart`, add event handlers (with safe-cast `if (data == null || data is! Map) return; final map = Map<String,dynamic>.from(data);`) for `groupCallActive { chatRoomId }` and `groupCallEnded { chatRoomId }`; expose typed callbacks `void Function(String chatRoomId)? onGroupCallActive` and `onGroupCallEnded`
- [X] T095 [US6] In `lib/features/chat/presentation/bloc/chat_cubit.dart`, add `final Set<String> _activeCallRoomIds = {};`; subscribe to `SocketService.onGroupCallActive` (add roomId, emit state) and `SocketService.onGroupCallEnded` (remove roomId, emit state) in the existing `connectSocket()` method; expose `bool hasActiveCall(String roomId) => _activeCallRoomIds.contains(roomId)`. Include `_activeCallRoomIds` in Equatable `props` if the state class is separate, or expose it via a getter if state is inline
- [X] T096 [US6] Create `lib/features/chat/presentation/widgets/join_call_app_bar_action.dart`: a stateless widget that receives `roomId` and `ChatCubit`/`CallCubit` via `context.read`; if `chatCubit.hasActiveCall(roomId)` is true, renders a green "Join Call" pill (`ElevatedButton` with call icon); on tap, calls `callCubit.acceptGroupCall(roomId)` and navigates to the group call screen; if false, returns `const SizedBox.shrink()` (zero footprint, FR-038)
- [X] T097 [US6] In `lib/features/chat/presentation/pages/group_chat_screen.dart`, add `JoinCallAppBarAction(roomId: chatSession.id)` to the AppBar's `actions` list so the conditional "Join Call" pill appears when a call is active in that room (FR-038). Wrap in `BlocBuilder<ChatCubit, ChatState>` so it rebuilds when active-call state changes

### Sub-Phase 8g: Recording Entity + Capture + Gallery Save Infrastructure (FR-032a, FR-035a)

- [X] T098 [P] [US6] Create `lib/features/call_recording/data/datasources/gallery_saver_service.dart`: wraps `gal: ^2.3.0`; exposes `Future<Either<Failure, String>> saveVideo(String filePath)` (calls `Gal.requestAccess()` then `Gal.putVideo(filePath)`) and `Future<Either<Failure, String>> saveAudioToDownloads(String filePath, String displayName)` (writes to `Downloads/CiroRecordings/` on Android via `path_provider` + `dart:io`, or `Documents/Recordings/` on iOS). Returns the saved public path
- [X] T099 [P] [US6] Create `lib/features/call_recording/data/datasources/recording_capture_service.dart`: unified capture abstraction; `start({required String filePath, required bool hasVideo})` → routes to `record: ^6.2.0` AAC encoder when `hasVideo=false`, or to `flutter_screen_recording` MP4 when `hasVideo=true`; `stop() → Future<(String finalPath, Duration duration)>`. The cubit calls this; it never needs to know which package is underneath (FR-032a, INV-10)
- [X] T100 [P] [US6] Update `lib/features/call_recording/domain/entities/recording.dart` to add three new fields per data-model.md §3: `galleryPath: String?` (public path after gallery/Downloads save), `shareStatus: ShareStatus` (enum `idle | uploading | shared | failed`), `sharedMessageId: String?` (clientMessageId once shared). Define `enum ShareStatus { idle, uploading, shared, failed }` in a co-located `share_status.dart` file. Update Equatable `props`
- [X] T101 [US6] Update `lib/features/call_recording/data/models/recording_model.dart` to serialize/deserialize the three new fields in `toMap()` / `fromMap()` using the column names `gallery_path`, `share_status`, `shared_message_id` (matching the T011 migration)
- [X] T102 [US6] Update abstract `lib/features/call_recording/domain/repositories/recordings_repository.dart` to add two new methods: `Future<Either<Failure, void>> updateShareStatus(String id, ShareStatus status, {String? sharedMessageId})` and `Future<Either<Failure, void>> updateGalleryPath(String id, String? galleryPath)` — needed by the cubit to persist share pipeline state transitions without reloading the full entity
- [X] T103 [US6] Update `lib/features/call_recording/data/datasources/recordings_local_data_source.dart` with parameterized UPDATE implementations for `updateShareStatus` and `updateGalleryPath`; update `recordings_repository_impl.dart` to delegate to the new data source methods

### Sub-Phase 8h: CallRecordingCubit Rewrite + RecordingsListPage Retry (FR-035, FR-036, RD-7)

- [X] T104 [US6] In `lib/features/call_recording/presentation/bloc/call_recording_cubit.dart`, update `start({required callRoomId, required callRoomName, required bool hasVideo})` to: (a) call `RecordingCaptureService.start(filePath, hasVideo: hasVideo)` instead of calling `record` directly — this selects the correct format per FR-032a; (b) include `hasVideo` in the `groupCallRecordingStateChanged` socket emit so other participants and late joiners know the recording type. Update `Recording { hasVideo }` in the state
- [X] T105 [US6] In `call_recording_cubit.dart`, extend `stop()` to chain the full share pipeline after finalizing the file (per data-model.md §3 State Transitions): ① call `GallerySaverService.saveVideo` or `saveAudioToDownloads` based on `hasVideo` → update `gallery_path` in DB (failure here is non-fatal: snackbar + continue); ② `UPDATE share_status='uploading'`; ③ call `ChatRemoteDataSource.uploadFile(filePath, category: 'recording')` → get `fileUrl`; ④ call `ChatCubit.sendMediaMessage(callRoomId, fileUrl, type: hasVideo ? video : audio)`; ⑤ `UPDATE share_status='shared', shared_message_id=clientMessageId`; on upload or send failure: `UPDATE share_status='failed'` and surface an in-app alert. Update the `Saved` state to carry `shareStatus`
- [X] T106 [US6] Add `retryShare(Recording recording)` method to `call_recording_cubit.dart`: re-runs only steps ③ + ④ + ⑤ from T105 using the existing `recording.filePath` (the file is already on disk); transitions `share_status` through `uploading → shared | failed`. This implements the manual "Retry share" action from the Recordings list (RD-7)
- [X] T107 [US6] Update `lib/features/call_recording/presentation/pages/recordings_list_page.dart` to: (a) show a share-status icon in each row trailing area — ✓ (shared, green), ⚠ (failed, amber), ⟳ (uploading, spinner), — (idle, grey); (b) long-press menu on a `failed` row shows "Retry share" action that calls `callRecordingCubit.retryShare(recording)` (RD-7); (c) when `recording.hasVideo == true`, use `VideoPlayerController.file(File(recording.filePath))` for playback instead of `just_audio` (Constitution §VIII-C, FR-036)

**Checkpoint (8e–8h)**: Join Call pill appears/disappears within 5 s (SC-008). Recording auto-formats by call type (FR-032a). Stopped recording is saved to gallery/Downloads (FR-035a) and appears as a media message in the group chat within 30 s (SC-007). Failed uploads can be retried from the Recordings list (RD-7). All group members can play the recording in chat (FR-036).

---

## Phase 9: Polish & Cross-Cutting Concerns (Regression + Hygiene)

**Purpose**: Verify no existing feature has regressed and tighten anything left loose.

- [X] T079 [P] Run the complete 1-to-1 regression smoke pass in `specs/007-group-chat/quickstart.md` §3 Phase D (text/media/voice messages, status promotion, 1-to-1 voice + video calls, typing indicator, logout teardown)
- [X] T080 [P] Audit all new socket event handlers added in T009 / T044–T050 for the `if (data == null || data is! Map) return;` safe-cast pattern (Constitution §IV-A). Zero `data as Map<String, dynamic>` should appear
- [X] T081 [P] Audit all new SQLite reads/writes (recordings table) for proper closing and parameterized queries (no string interpolation in SQL)
- [X] T082 [P] Verify `PushNotificationService.dispose()` and the full logout sequence (Constitution §V-A) still tear down correctly when a group call or recording is in progress (the active LiveKit room and recorder must be released before token deletion)
- [X] T083 Verify all new entities and states extend `Equatable` (Constitution §II)
- [X] T084 Verify the LiveKit URL is read from `.env` in both Flutter (T002/T003) and backend; no hardcoded URLs remain
- [X] T085 [P] Run `flutter analyze` and fix any new warnings (Constitution §VI)
- [X] T086 [P] Run the full quickstart.md two-device test plan from Phase A through Phase D; record any defects as follow-up tasks
- [ ] T108 [P] Run quickstart.md §3 Phase B steps 13–21 (Join Call pill visibility, hydration after cold start); confirm pill appears within 5 s of `groupCallActive` socket event (SC-008) and disappears within 5 s of `groupCallEnded` (SC-008)
- [ ] T109 [P] Run quickstart.md §3 Phase C (voice recording → M4A → gallery/Downloads → media message in chat within 30 s) and Phase C-2 (video recording → MP4 → Photos/Gallery → media message); confirm format matches call type (FR-032a) and SC-007 timing
- [ ] T110 [P] Audit T087–T107 socket handlers in `socket_service.dart` (`groupCallActive`, `groupCallEnded`) for the mandatory `if (data == null || data is! Map) return;` safe-cast pattern (Constitution §IV-A)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: T001–T005. No dependencies — can start immediately. All `[P]`-marked tasks can run in parallel.
- **Phase 2 (Foundational)**: T006–T011. Depends on Phase 1. Blocks all later user stories.
- **Phase 3 (US1)**: T012–T017. Depends on Phase 2.
- **Phase 4 (US2)**: T018–T024. Depends on Phase 2. **Can run in parallel with Phase 3** (different files).
- **Phase 5 (US3)**: T025–T029. Depends on Phase 2 (specifically T007 for backend payload).
- **Phase 6 (US4)**: T030–T039. Depends on Phase 2. Can run in parallel with Phases 3–5.
- **Phase 7 (US5)**: T040–T043. Depends on Phase 6 (uses `leaveGroup` UI from T038).
- **Phase 8 (US6)**: T044–T107. Depends on Phase 2. Internal order: 8a (backend) → 8b (Flutter cubit) → 8c (UI) → 8d (recording foundation) → 8e–8f (active-call tracking) → 8g (infrastructure) → 8h (cubit rewrite + list page).
  - Sub-Phase 8e depends on 8a (extends existing backend handlers).
  - Sub-Phase 8f depends on T094–T095 (socket handlers before ChatCubit consumption).
  - Sub-Phase 8g tasks T098–T103 can start in parallel once T092 (pubspec) is done.
  - Sub-Phase 8h (T104–T107) depends on 8g (T100 entity, T102 repo interface).
- **Phase 9 (Polish)**: T079–T110. Depends on all user stories you intend to ship. T108–T110 specifically require 8e–8h.

### User Story Independence

- US1 ↔ US2: independent in scope but US2 will land second because users need a group first; both are P1.
- US3: depends on T007 (backend payload) and T009/T011 plumbing. Once those land, US3 is a focused 2-file change.
- US4: independent UI-only changes (plus T033 backend); no dependency on US3.
- US5: layered on top of US4's leave-group dialog.
- US6: largest scope; entirely independent of US1–US5 once foundational T009/T010 are in.

---

## Parallel Execution Examples

### Phase 1 (Setup) — run all in parallel
```
T002, T003, T005 — three independent file edits ([P] markers)
T001 must complete before T009 references the constants
```

### Phase 8b (CallCubit extensions) — within the same cubit file, run sequentially
```
T051 (entity)        → independent, can land first
T052..T058 (cubit)   → same file; run in order
```

### Sub-Phase 8g (infrastructure) — run in parallel after T092
```
T098 (GallerySaverService)       → independent new file
T099 (RecordingCaptureService)   → independent new file
T100 (Recording entity update)   → independent entity file
```

### Across user stories — parallel team example
```
Developer A: Phase 3 (US1) + Phase 4 (US2)   — UI flow
Developer B: Phase 5 (US3) + Phase 6 (US4)   — read receipts + info page
Developer C: Phase 8 (US6) sub-phase 8a + 8e (backend signaling + active-call)
Developer D: Phase 8 (US6) sub-phase 8b/8c (Flutter call UI)
Developer E: Phase 8 (US6) sub-phases 8g/8h (recording infra + cubit rewrite)
```

---

## Implementation Strategy

### MVP First (Phases 1 → 2 → 3 → 4 → 9-regression)
1. Phase 1: Setup (T001–T005)
2. Phase 2: Foundational (T006–T011)
3. Phase 3: US1 — Create Group with avatar (T012–T017)
4. Phase 4: US2 — Group messaging with sender names (T018–T024)
5. **STOP and VALIDATE**: Run quickstart.md §3 Phase A. Ship if green. This is a complete, demonstrable MVP.

### Incremental Delivery After MVP
6. Phase 5 (US3 — group read receipts) → ship
7. Phase 6 (US4 — group info management) → ship
8. Phase 7 (US5 — admin succession edge cases) → ship
9. Phase 8 sub-phases 8a–8d (US6 — group calls + local recording) → ship
10. Phase 8 sub-phases 8e–8h (US6 — Join Call button + share pipeline) → ship
11. Phase 9 polish (T079–T110) before each ship gate

### Stop-Gate Decisions
- After **MVP (US1 + US2)**: ship if user feedback prioritizes messaging over calls.
- After **US6 (calls + local recording)**: calls are functional; share pipeline follows.
- After **sub-phases 8e–8h**: full feature delivery per updated spec.

---

## Task Count Summary

| Phase | Tasks | Notes |
|-------|-------|-------|
| 1: Setup | 5 (T001–T005) | 3 parallel; T001 updated to include groupCallActive/groupCallEnded constants |
| 2: Foundational | 6 (T006–T011) | 3 backend, 3 Flutter; T011 updated to include gallery_path, share_status, shared_message_id columns |
| 3: US1 (P1) | 6 (T012–T017) | MVP slice |
| 4: US2 (P1) | 7 (T018–T024) | MVP slice |
| 5: US3 (P2) | 5 (T025–T029) | 1 optional test |
| 6: US4 (P2) | 10 (T030–T039) ✅ | 1 backend endpoint added |
| 7: US5 (P3) | 4 (T040–T043) ✅ | UI + integration |
| 8: US6 (P2) | 35 (T044–T078) ✅ + 21 NEW (T087–T107) | Sub-phases 8e–8h are the new share pipeline + Join Call work |
| 9: Polish | 8 (T079–T086) ✅ + 3 NEW (T108–T110) | T108–T110 cover Join Call + recording share regression |
| **Total** | **110 tasks** | 56 completed [X]; 54 remaining [ ] |

### Parallel Opportunities Identified

- Phase 1: 3 of 5 tasks parallel
- Phase 9: 6 of 8 original tasks parallel; all 3 new ones parallel
- Sub-Phase 8g: 3 infrastructure tasks can run in parallel
- Across user stories: US1/US2/US4/US6 can be staffed in parallel after Phase 2

### MVP Scope (recommended)

User Stories US1 + US2 (group creation + group messaging) — total 18 tasks (Phase 1: 5 + Phase 2: 6 + Phase 3: 6 + Phase 4: 7 + light Phase 9 regression). Estimated 2–3 days of focused work.

---

## Notes

- All file paths above are valid as of plan.md / data-model.md / contracts/ dated 2026-05-16. If a file is later moved, update the path in the corresponding task before starting it.
- Backend tasks (`BACKEND: src/...`) target the separate repo at `/Volumes/Zeyad/Documents/work/Node js/chat-app-backend`. Each backend task should be committed in that repo and version-pinned to the Flutter feature branch.
- Per the constitution, every new socket event handler MUST use the `if (data == null || data is! Map) return; final map = Map<String, dynamic>.from(data);` pattern. **No exceptions.** Past production incidents were caused by skipping this.
- **Recording share pipeline** (INV-6 revised 2026-05-16): after capture and local save, recordings are uploaded via `POST /chat/upload?category=recording` (500 MB cap) and posted as a group chat media message. All members can access them. This supersedes the original local-only design.
- The `gal` package requires `Gal.requestAccess()` before any save operation. On Android 13+, this triggers `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` runtime permission prompts. Gallery save failure (permission denied / storage full) MUST NOT block the chat-share pipeline — the two are independent (data-model.md §3 failure handling).
- `flutter_screen_recording` (video recording) requires MediaProjection on Android — the foreground service declaration in T093 is mandatory. On iOS, ReplayKit is invoked automatically by the package.
- Stop at any checkpoint to validate independently before committing to the next phase.
