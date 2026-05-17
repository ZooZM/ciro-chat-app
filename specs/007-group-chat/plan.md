# Implementation Plan: Group Chat (with Group Calls and Shared Call Recording)

**Branch**: `007-group-chat` | **Date**: 2026-05-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/007-group-chat/spec.md`

> **Revision history**: First drafted 2026-05-14 (local-only recording). Revised 2026-05-16
> after spec update — recording is now auto-formatted by call type, uploaded as a group chat
> media message, and additionally saved to the device gallery/Downloads. A "Join Call" button
> is added to the group chat AppBar with active-call gating.

## Summary

Group chat for Ciro, in four layers:

1. **Messaging (core)**: Backend and Flutter domain/data layers are already group-aware
   (`ChatRoom` with type/participants/admins, `Message` with `deliveredTo`/`readBy`, SQLite v8
   schema, REST endpoints `/chat/group/*`, ChatCubit `createGroup`/`addParticipants`/
   `removeParticipant`). The actual work is **UI completion**: a real `GroupChatScreen`
   (currently a stub), an avatar picker in `CreateGroupPage`, name/photo edit in
   `GroupInfoPage`, a 1-line backend tweak to admin succession, and a backwards-compatible
   socket-payload field for group read receipts.

2. **Group calls (32-participant via SFU)**: The app **already uses LiveKit**
   (`livekit_client ^2.6.4` Flutter + `livekit-server-sdk ^2.15.1` backend) for 1-to-1 calls.
   LiveKit's SFU natively supports 32+ participants in a single room. The work is **signaling
   adaptation** (broadcast `incomingCall` to all group members instead of a single target,
   allow late join, allow per-member leave), **UI** (`GroupCallScreen` showing a participant
   grid), and a **"Join Call" AppBar action** in `GroupChatScreen` that is visible only while
   a call is in progress for that room (FR-038). The existing `CallCubit`, `CallOverlay`, and
   LiveKit token endpoint `POST /video/room/:roomId/join` are reused with minor extensions.

3. **Call recording with auto-format + gallery save**: Each participant who taps "Record"
   captures the call locally on their device. **Format auto-matches call type** (FR-032a):
   audio-only via `record: ^6.2.0` for voice calls; video via a screen-recording package
   (decision in research.md) for video calls. LiveKit emits a recording-state event so other
   participants show the universal REC indicator. On stop, the file is saved to the device
   gallery (video) or Downloads folder (audio) (FR-035a).

4. **Recording sharing to group chat**: After the recording is stopped, the file is uploaded
   via the existing media upload pipeline (`ChatRemoteDataSource.uploadFile`) and posted as a
   group chat media message visible to all current group members (FR-035b). All members can
   download or save the recording from the chat thread. The recorder additionally has a
   dedicated recordings-list page for managing their own recordings (FR-036).

The Clean Architecture, Cubit pattern, sqflite storage, and existing CallCubit/CallOverlay
flow are all preserved. No new SFU infrastructure is needed. No new socket transport is
needed. The recording **upload** reuses the existing media upload endpoint — no new file-
storage backend is introduced.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.x (mobile app); TypeScript / NestJS (backend)
**Primary Dependencies**:
- *Existing*: `flutter_bloc`, `sqflite`, `socket_io_client ^3.1.4`, `go_router`,
  `injectable/get_it`, `image_picker`, `cached_network_image`, `dio`, `livekit_client ^2.6.4`,
  `flutter_ringtone_player ^4.0.0+4`, `record ^6.2.0`, `permission_handler ^12.0.1`,
  `video_player`, `just_audio` (recording playback)
- *New (decision in research.md)*:
  - **Video screen recording**: candidate `flutter_screen_recording: ^2.0.0` or
    `ed_screen_recorder: ^0.4.0` (final selection in research.md decision RD-1)
  - **Gallery save**: `gal: ^2.3.0` (saves to Photos/Gallery on iOS/Android)
  - **Downloads folder save**: `path_provider` (existing) + Android Scoped Storage helper
    (`saver_gallery` or platform channel for `Downloads/`)
- *Backend*: NestJS, Mongoose, `socket.io`, `livekit-server-sdk ^2.15.1`. No new packages.
**Storage**:
- SQLite via `sqflite` (rooms, messages, contacts — already group-aware at v8)
- Local filesystem (recordings: temporary working file in app docs dir during capture; final
  file moved to OS gallery/Downloads; metadata in a new `recordings` SQLite table — see
  data-model.md)
- MongoDB (backend: chat rooms, messages — recording file URL stored as a normal media
  message attachment after upload)
- Existing media upload storage on the backend (already used for chat photos/videos)
**Testing**: `flutter_test` + `bloc_test`; Jest (backend); manual two-device test plan in
quickstart.md
**Target Platform**: iOS 15+ / Android 6+ (mobile only)
**Project Type**: Mobile app (Flutter) + NestJS backend with LiveKit Cloud SFU
**Performance Goals**:
- Group messages: visible to all online members within 2 s under normal network
- Group info changes propagate within 3 s
- Group call join: receiver-to-media-active within 4 s after tapping Accept (matches existing
  1-to-1 baseline)
- Recording start indicator visible to other participants within 2 s
- **Recording appears as media message for all participants within 30 s of stop** (SC-007)
- **"Join Call" button reflects active-call state within 5 s** (SC-008)
**Constraints**:
- Offline-first: all group state readable from SQLite when offline
- Socket payloads delivered as `Map<dynamic,dynamic>` — safe-cast pattern mandatory
  (Constitution §IV-A)
- No Hive
- All media URLs resolved via `UrlUtils.resolveMediaUrl()`
- Recording capture happens locally; the file is uploaded only after the recorder stops,
  using the existing media pipeline (no new server endpoint required)
- Gallery / Downloads write requires platform-specific permissions handled at recording-stop
  time
**Scale/Scope**:
- ≤ 256 members per group
- ≤ 32 concurrent participants per group call
- Recording file size budget: ≤ 500 MB for audio (≈ 14 h M4A) and ≤ 2 GB for video; longer
  recordings get a warning prompt before sharing
- Existing message and room volume unchanged

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Pre-design check (Phase 0 entry)**: PASS — see boxes below.
**Post-design check (Phase 1 exit, 2026-05-16)**: PASS — no new violations introduced by
the recording-sharing expansion. Specifically validated:
- §V-A logout sequence: `CallCubit.reset()` now also stops any active recording before
  LiveKit disconnect, preserving the mandated order.
- §VIII-C video rendering: `RecordingsListPage` playback branches on `hasVideo` and uses
  `VideoPlayerController.file` for video recordings.
- §IX message status: recording-as-chat-message follows the normal media-message status
  flow; no new status semantics.
- §III storage: no new credentials; new SQLite columns (`gallery_path`, `share_status`,
  `shared_message_id`) are non-sensitive metadata.

- [x] **I. Clean Architecture**: Group chat lives in `features/chat/`; group calls extend
  `features/video_call/`; recordings get a `features/call_recording/` slice (data layer +
  domain entity + cubit + list page + share-after-stop service). Each layer follows
  presentation/domain/data discipline.

- [x] **II. State Management**: `ChatCubit` (existing) handles messaging; `CallCubit`
  (existing) extended for group calls; new `CallRecordingCubit` manages start/stop/upload/
  list. All states extend `Equatable`. Dependencies are constructor-injected via `get_it`/
  `injectable`.

- [x] **III. Offline-First (corrected)**: Per Constitution §III, `sqflite` for relational
  data and `FlutterSecureStorage` for sensitive credentials — Hive is NOT used. The existing
  v8 schema covers groups; one new local SQLite table (`recordings`) is added for recording
  metadata. No new credentials are introduced (LiveKit token fetched per call via
  `Authorization: Bearer` header — never persisted). Recording upload reuses the existing
  authenticated media upload pipeline.

- [x] **IV. Socket.IO**: All new events go through the existing `SocketService` singleton;
  transport remains WebSocket; auth remains `setAuth({'token': token})`. Handlers use the
  `data is! Map` safe-cast pattern (§IV-A). The room-based broadcast keeps idempotency:
  receiving the same `incomingGroupCall` or `groupCallActive` twice does nothing if the call
  is already in `CallActive`.

- [x] **V. Teardown**: `CallCubit.reset()` (logout step 2) already disconnects LiveKit;
  extended to terminate any active group call session AND stop any active recording.
  `CallRecordingCubit.dispose()` stops the platform recorder, cancels the upload retry timer,
  and persists final file path. `PushNotificationService.dispose()` unchanged.

- [x] **Code Quality**: `snake_case` files; `PascalCase` classes; `flutter_lints` baseline;
  no `print`/`debugPrint` left in production paths besides existing logging.

- [x] **Error Handling**: All new REST/socket flows wrapped in repository methods returning
  `Either<Failure, T>`; LiveKit connect errors map to `ServerFailure`; recording permission
  errors surface as user-facing dialogs (not silent failures). Recording-upload failure does
  NOT discard the local file — it falls back to manual share from the recordings list.

**Group-Specific Constitution Notes**:
- **§IV-A (Socket Map safety)** — strictly observed for new events `incomingGroupCall`,
  `groupCallParticipantJoined`, `groupCallParticipantLeft`, `groupCallRecordingStateChanged`,
  `groupCallActive`, `groupCallEnded`.
- **§VIII (Media & URL resolution)** — group avatars use the existing upload pipeline;
  resolution via `UrlUtils.resolveMediaUrl()`. Recording media messages also flow through
  the same resolution path.
- **§VIII-C (Video rendering)** — recording playback for video files MUST use
  `VideoPlayerController.file` (via `DefaultCacheManager().getSingleFile(url)` for downloaded
  remote copies). The recordings list page differentiates playback by `hasVideo` field.
- **§IX (Message status flow)** — group read receipts gate on
  `readByCount >= participantCount - 1` (sender excluded) in
  `ChatCubit.handleMessageStatusUpdate`. Recording messages follow the standard media-
  message status flow.

## Project Structure

### Documentation (this feature)

```text
specs/007-group-chat/
├── plan.md              # this file
├── research.md          # decisions: video-recording pkg, gallery-save pkg, retry strategy
├── data-model.md        # entities: Recording, ActiveGroupCall (server-side)
├── quickstart.md        # two-device test plan (updated for sharing scenarios)
├── contracts/
│   ├── rest.md          # /chat/group/* + /video/room/* + media upload reuse
│   └── socket.md        # existing + new group + group-call + recording-state + active-call events
└── tasks.md             # generated by /speckit-tasks (not by this command)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── di/                              # no change
│   ├── network/
│   │   ├── socket_service.dart          # ADD: incomingGroupCall, groupCallParticipantJoined/Left,
│   │   │                                #      groupCallRecordingStateChanged, groupCallActive,
│   │   │                                #      groupCallEnded emit + on handlers
│   │   └── socket_events.dart           # ADD: new event name constants
│   └── theme/                           # no change
├── features/
│   ├── chat/                            # group messaging
│   │   ├── data/
│   │   │   ├── datasources/             # no change (group APIs already implemented;
│   │   │   │                            #             uploadFile reused by recording share)
│   │   │   └── models/                  # no change
│   │   ├── domain/                      # no change
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── chat_cubit.dart                  # MODIFY: gate group read receipts;
│   │       │                                        #         track active-call state per room;
│   │       │                                        #         expose `hasActiveCall(roomId)`
│   │       ├── pages/
│   │       │   ├── create_group_page.dart           # ADD: group-avatar image picker
│   │       │   ├── group_chat_screen.dart           # REWRITE: replace stub, reuse ChatCubit,
│   │       │   │                                    #         show sender name on inbound bubbles,
│   │       │   │                                    #         show "Join Call" AppBar action when
│   │       │   │                                    #         hasActiveCall(roomId) is true
│   │       │   └── group_info_page.dart             # MODIFY: name/photo edit, verify leave flow
│   │       └── widgets/
│   │           ├── group_sender_name.dart           # NEW: small label widget for inbound bubbles
│   │           └── join_call_app_bar_action.dart    # NEW: conditional AppBar action
│   ├── video_call/                      # group calls (extend existing 1-to-1 LiveKit flow)
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── livekit_video_call_repository_impl.dart   # MODIFY: support N participants
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       └── call_participant.dart            # NEW: id, name, avatar, isMuted, isVideoOn
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── call_cubit.dart                  # MODIFY: add isGroupCall + participants +
│   │       │                                        #         recordingState on CallActive
│   │       └── pages/
│   │           ├── group_call_screen.dart           # NEW: participant grid + controls + REC banner
│   │           └── incoming_group_call_screen.dart  # NEW: variant of incoming for groups
│   └── call_recording/                  # local capture + share (new slice)
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── recordings_local_data_source.dart    # NEW: sqflite + filesystem
│       │   │   ├── gallery_saver_service.dart           # NEW: wraps `gal` and Downloads helper
│       │   │   └── recording_capture_service.dart       # NEW: wraps `record` (audio) +
│       │   │                                            #      `flutter_screen_recording` (video)
│       │   └── models/
│       │       └── recording_model.dart             # NEW
│       ├── domain/
│       │   ├── entities/
│       │   │   └── recording.dart                   # NEW: id, callRoomId, filePath, durationMs,
│       │   │                                        #     hasVideo, sizeBytes, createdAt,
│       │   │                                        #     displayName, sharedMessageId?,
│       │   │                                        #     shareStatus (idle|uploading|shared|failed)
│       │   └── repositories/
│       │       └── recordings_repository.dart       # NEW (abstract)
│       └── presentation/
│           ├── bloc/
│           │   └── call_recording_cubit.dart        # NEW: start/stop, save to gallery, upload,
│           │                                        #     post-as-message, retry on failure
│           └── pages/
│               └── recordings_list_page.dart        # NEW: my recordings (browse, play, rename,
│                                                    #     delete, re-share if upload failed)
└── main.dart                                          # no change

backend: src/modules/
├── chat/
│   ├── chat.service.ts             # MODIFY (small):
│   │                               #   - leaveGroup() → promote participants[0] (earliest joiner)
│   │                               #   - markMessagesRead() → include readByCount + participantCount
│   │                               #     for GROUP rooms
│   ├── chat.gateway.ts             # MODIFY:
│   │                               #   - on 'requestGroupCall': fan-out incomingGroupCall to all
│   │                               #     participants in the chatRoomId (excluding caller),
│   │                               #     PLUS broadcast `groupCallActive { chatRoomId }` to room
│   │                               #   - on 'leaveGroupCall': decrement participant count,
│   │                               #     auto-end + broadcast `groupCallEnded { chatRoomId }`
│   │                               #     when last leaves
│   │                               #   - new event handlers: groupCallParticipantJoined/Left,
│   │                               #     groupCallRecordingStateChanged
│   │                               #   - on connection, emit `groupCallActive` for any rooms
│   │                               #     the user is in that have an active call (FR-038
│   │                               #     hydration after reconnect / app open)
│   │                               #   - track activeGroupCalls Map<chatRoomId, Set<userId>>
│   │                               #   - on `acceptGroupCall`, include `currentRecorders: string[]`
│   │                               #     in the response so late joiners can show REC immediately
│   └── chat.controller.ts          # no change (existing /chat/group/* endpoints sufficient;
│                                   #  recording is posted via the existing media-message endpoint)
└── video/
    └── video.controller.ts         # MODIFY: tighten POST /video/room/:roomId/join to verify
                                    # caller is a current participant of the chat room (FR-027 hardening)
```

**Structure Decision**: Four feature slices — `chat` (existing, completed), `video_call`
(existing, extended), `call_recording` (new, slightly expanded vs. original "local-only"
scope: now also handles gallery save + chat upload), plus a small widget addition to chat
presentation for the conditional Join Call AppBar action. No changes to `core/di/` — `get_it`
/ `injectable` annotations on the new cubits/repositories/services are picked up by the
existing build runner.

## Complexity Tracking

No constitution violations. All architectural rules from the constitution are honored. Two
justified deviations from minimalism:

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| New `call_recording` feature slice | Recording lifecycle (start/stop/save-to-gallery/upload/persist metadata/list/play/delete/re-share) has its own state, multiple platform integrations, and storage. Placing it inside `video_call/` would entangle three unrelated concerns and inflate `CallCubit`. | Embedding inside `CallCubit` rejected because (a) `CallCubit` is already large and stateful, (b) recordings outlive a single call and need their own list/playback UI, (c) sharing pipeline (upload → post-as-message → retry) is independent of WebRTC state, (d) Clean Architecture §I prefers single-responsibility cubits. |
| Two capture services (audio + video) wrapped behind one `RecordingCaptureService` | Audio recording (`record`) and video screen recording (`flutter_screen_recording`) have fundamentally different APIs and platform behaviors. The wrapper exposes a uniform `start(includeVideo: bool)` / `stop()` to `CallRecordingCubit`. | A single multipurpose package was sought (RD-1 in research.md) but no Flutter package cleanly captures both audio AND video screen with sufficient stability. Wrapping is simpler than forcing the cubit to know both APIs. |

---

## Implementation Phases (Reference for /speckit-tasks)

This section is **descriptive** — `/speckit-tasks` produces the actionable task list.

### Phase A: Group Messaging Completion (P1 from spec)

1. Add avatar image picker to `create_group_page.dart` (calls existing `uploadFile`, passes
   `avatarUrl` to `createGroup`).
2. Rewrite `group_chat_screen.dart` as a real ChatCubit-driven screen; reuse the same message
   list, input bar, typing indicator, scroll controller, and media gallery widgets as the
   1-to-1 chat screen. The only group-specific additions are the `GroupSenderName` widget
   above inbound bubbles and the conditional `JoinCallAppBarAction` in the AppBar.
3. Verify/complete `group_info_page.dart` — admin-gated name edit, photo edit, leave-group
   dialog. Add an explicit "You are no longer a participant" banner state for removed/left
   members (FR-030).
4. Backend: `chat.service.ts` `leaveGroup()` → `participants[0]` succession.
5. Backend: `chat.service.ts` `markMessagesRead()` → include `readByCount`+`participantCount`
   in the `messageRead` socket payload for GROUP rooms.
6. Flutter: `ChatCubit.handleMessageStatusUpdate` → gate `delivered → read` on the new counts
   (backwards-compatible: when counts absent, fall back to existing behavior).
7. Routing: ensure `/group/create`, `/group/:roomId/chat`, `/group/:roomId/info` are wired in
   `app_router.dart`.

### Phase B: Group Calls + Join Call Button (P2 from spec — US6, FR-038)

1. Socket events (Flutter `socket_service.dart` + backend `chat.gateway.ts`):
   - `requestGroupCall { chatRoomId, isVideo }` — caller → server → fan-out incomingGroupCall
     to all room participants except caller, AND broadcast `groupCallActive { chatRoomId }`
     to every participant (including caller). The active state is what FR-038 keys on.
   - `incomingGroupCall { chatRoomId, callerId, callerName, isVideo, currentParticipantCount }`
     — server → invited members.
   - `acceptGroupCall { chatRoomId }` — joinee → server → fetch LiveKit token, broadcast
     `groupCallParticipantJoined` to room. Server response includes `currentRecorders: string[]`
     so the joinee can render REC banner if recording is in progress (closes FR-033 late-
     joiner gap).
   - `declineGroupCall { chatRoomId }` — joinee → server (does NOT end call for others).
   - `leaveGroupCall { chatRoomId }` — participant → server → broadcast
     `groupCallParticipantLeft`; auto-end when count reaches 1, broadcasting
     `groupCallEnded { chatRoomId }`.
   - `groupCallActive` / `groupCallEnded` are also emitted to a user on socket connect for
     each of their rooms with an active call (server replay on reconnect).
2. Backend `video.controller.ts` already exposes `POST /video/room/:roomId/join` returning a
   LiveKit token; reused for group calls with `roomId = chatRoomId`. Token issuer verifies
   the caller is a current participant of the group (T008 in tasks).
3. `CallCubit` extension:
   - Extend `CallActive` with `List<CallParticipant> participants`, `bool isGroupCall`, and
     `Set<String> activeRecorders`.
   - On `groupCallParticipantJoined` / `groupCallParticipantLeft`, update the participant
     list.
   - On `groupCallRecordingStateChanged`, update `activeRecorders`.
4. `ChatCubit` active-call tracking (NEW for FR-038):
   - Maintain `Set<String> _activeCallRoomIds` in cubit state.
   - On `groupCallActive { chatRoomId }`: add → emit state.
   - On `groupCallEnded { chatRoomId }`: remove → emit state.
   - Expose `bool hasActiveCall(String roomId)` used by `GroupChatScreen` AppBar.
5. New `GroupCallScreen`:
   - Participant grid (auto-layout: 1-2 → big tiles; 3-6 → grid; 7+ → scrollable carousel
     with active speaker pinned).
   - Existing mute/camera/end-call controls reused.
   - REC indicator banner at top when `activeRecorders.isNotEmpty`.
6. New `IncomingGroupCallScreen`: variant of the existing incoming-call screen showing
   "Caller X is calling Group Y (3 already joined)" with Accept/Decline.
7. `CallOverlay` routing: when state becomes `CallIncoming` with `isGroupCall: true`, push
   the new group incoming screen; when `CallActive` with `isGroupCall: true`, push
   `GroupCallScreen`.
8. Enforce 32-participant cap server-side (reject `acceptGroupCall` if already at 32 with
   `callError`); Flutter handles the error toast.
9. `JoinCallAppBarAction` widget in `GroupChatScreen` AppBar:
   - Reads `chatCubit.state.hasActiveCall(roomId)`.
   - If true → render a green "Join Call" pill; on tap, calls
     `CallCubit.acceptGroupCall(roomId)` and routes to `GroupCallScreen`.
   - If false → renders nothing (zero-height).

### Phase C: Call Recording — Capture + Format Selection (P2 — FR-032, FR-032a, FR-033/034)

1. Permissions:
   - Microphone (existing) for audio recording.
   - On Android, `RECORD_AUDIO` + `FOREGROUND_SERVICE` (microphone) — already declared.
   - For video recording (video call only): `MediaProjection`/
     `FOREGROUND_SERVICE_MEDIA_PROJECTION` on Android; iOS uses ReplayKit (no extra
     permission, but the package handles its own prompt).
   - On Android 10+, gallery write uses scoped storage via `gal`; older Android needs
     `WRITE_EXTERNAL_STORAGE`.
2. New `RecordingCaptureService` (data layer):
   - `startAudio(filePath)`: uses `record: ^6.2.0` with AAC/M4A encoding.
   - `startVideo(filePath)`: uses the package selected in research.md RD-1 (default
     candidate: `flutter_screen_recording`).
   - `stop()`: returns the final file path and duration.
   - Selection happens in `CallRecordingCubit` based on `CallActive.isVideo`.
3. New `CallRecordingCubit`:
   - States: `Idle`, `Starting`, `Recording { startedAt, callRoomId, hasVideo }`, `Stopping`,
     `Saved { Recording, shareStatus }`, `Failure { message }`.
   - `start({callRoomId, callRoomName, hasVideo})`:
     - Request mic (+ screen-record) permission.
     - Create temp file `<app-docs-dir>/recordings/<uuid>.{m4a|mp4}`.
     - Call `RecordingCaptureService.startAudio` or `.startVideo` based on `hasVideo`.
     - Emit `groupCallRecordingStateChanged { isRecording: true, recorderId, chatRoomId }`
       via `SocketService`.
   - `stop()`:
     - Stop the recorder; compute duration & size.
     - Save metadata via `RecordingsRepository.save`.
     - Trigger Phase D (save-to-gallery + upload-and-share) as a background job.
     - Emit `groupCallRecordingStateChanged { isRecording: false }`.
4. Add a "Record" toggle button to `group_call_screen.dart` toolbar; tapping calls
   `CallRecordingCubit.start(callRoomId, callRoomName, hasVideo: callActive.isVideo)` or
   `.stop()` based on current state.
5. REC banner in `GroupCallScreen` shows when `callActive.activeRecorders.isNotEmpty`.

### Phase D: Call Recording — Save-to-Gallery + Share-as-Message (NEW for FR-035, FR-036)

1. New `GallerySaverService` (data layer):
   - `saveVideoToGallery(filePath)`: uses `gal: ^2.3.0` → Photos (iOS) / Gallery (Android).
   - `saveAudioToDownloads(filePath)`: writes to `Downloads/CiroRecordings/` (Android via
     scoped storage; iOS via Files app sharing). Implementation choice in research.md RD-2.
   - Returns the public path on success; throws on permission denial.
2. `CallRecordingCubit.stop()` continued flow (after metadata save):
   - **a. Save to gallery/Downloads**: call `GallerySaverService` based on `hasVideo`. On
     failure, surface a non-blocking snackbar but proceed.
   - **b. Upload via existing media pipeline**: call `ChatRemoteDataSource.uploadFile(file)`
     to get a `fileUrl`. On failure, mark `shareStatus = failed` and persist; do NOT delete
     the local file (user can retry from recordings list).
   - **c. Post as group chat message**: call `ChatCubit.sendMediaMessage(roomId, fileUrl,
     mediaType: hasVideo ? video : audio)`. The message uses the normal media-message flow
     so all current group members receive it. On success, mark `shareStatus = shared` and
     persist the resulting `clientMessageId` on the recording row.
3. SQLite schema: extend `recordings` table (migration v9) with two additional columns
   beyond the original design:
   - `share_status TEXT NOT NULL DEFAULT 'idle'`
   - `shared_message_id TEXT` (nullable; references `messages.client_message_id`)
4. New `RecordingsListPage`:
   - List of recordings ordered by `createdAt DESC`.
   - Each row shows display name, duration, file size, formatted date, and a `shareStatus`
     icon (✓ shared / ⟳ uploading / ⚠ failed).
   - Tap: play (audio via `just_audio`; video via `VideoPlayerController.file` per
     Constitution §VIII-C).
   - Long-press: Rename, Delete, **Retry share** (when `shareStatus = failed`).
5. Register `/recordings` route; add navigation entry in the group settings menu and a
   quick-access button in `group_call_screen.dart`.
6. Orphan-recording recovery on app start: in `RecordingsLocalDataSource.list()`, scan
   `<docs>/recordings/` for files with no DB row; insert default rows with mtime-based
   `createdAt`.
7. Auto-stop on call end: in `CallCubit`, when the call ends (any path), if
   `CallRecordingCubit.state is Recording`, auto-call `CallRecordingCubit.stop()` so the
   recording is finalized cleanly and the share pipeline runs.

### Phase E: Verification (no regression)

- Manual smoke test of all existing 1-to-1 flows (see quickstart.md):
  - Send/receive text, image, video, voice
  - Status promotion: pending → sent → delivered → read
  - 1-to-1 voice/video call
  - Typing indicator
  - Logout teardown sequence (with active call/recording — confirms Constitution §V-A still
    holds)
- All existing socket event handlers continue to use the safe-cast pattern (§IV-A).
- New events added to `socket_events.dart` constants — no string literals scattered.
- Recording lifecycle: capture → gallery save → upload → message → all-member access.
- "Join Call" button: appears within 5 s of a call starting, disappears within 5 s of it
  ending, hydrates correctly after reconnect.
- Removed/left member behavior: read-only state in conversations list, no new events
  received (FR-029, FR-030, FR-031).

**End of plan.md.** See `research.md`, `data-model.md`, and `contracts/` for design
specifics.
