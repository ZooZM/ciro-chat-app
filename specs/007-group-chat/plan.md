# Implementation Plan: Group Chat (with Group Calls and Local Recording)

**Branch**: `007-group-chat` | **Date**: 2026-05-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/007-group-chat/spec.md`

## Summary

Group chat for Ciro, in three layers:

1. **Messaging (core)**: Backend and Flutter domain/data layers are already group-aware (ChatRoom with type/participants/admins, Message with deliveredTo/readBy, SQLite v8 schema, REST endpoints `/chat/group/*`, ChatCubit `createGroup`/`addParticipants`/`removeParticipant`). The actual work is **UI completion**: a real `GroupChatScreen` (currently a stub), an avatar picker in `CreateGroupPage`, name/photo edit in `GroupInfoPage`, plus a 1-line backend tweak to admin succession and a backwards-compatible socket-payload field for group read receipts.

2. **Group calls (32-participant via SFU)**: The app **already uses LiveKit** (`livekit_client ^2.6.4` Flutter + `livekit-server-sdk ^2.15.1` backend) for 1-to-1 calls. LiveKit's SFU natively supports 32+ participants in a single room. The work is **signaling adaptation** (broadcast `incomingCall` to all group members instead of a single target, allow late join, allow per-member leave) and **UI** (`GroupCallScreen` showing a participant grid). The existing `CallCubit`, `CallOverlay`, and LiveKit token endpoint `POST /video/room/:roomId/join` are reused with minor extensions.

3. **Local-only call recording**: Each participant who taps "Record" captures the call locally on their device. Audio via existing `record: ^6.2.0` package; for video, add `flutter_screen_recording` (or equivalent platform channel). LiveKit emits a recording-state event so other participants can show the universal REC indicator. Nothing is uploaded.

No new SFU infrastructure is needed. No new socket transport is needed. The Clean Architecture, Cubit pattern, sqflite storage, and existing CallCubit/CallOverlay flow are all preserved.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.x (mobile app); TypeScript / NestJS (backend)
**Primary Dependencies**:
- *Existing*: `flutter_bloc`, `sqflite`, `socket_io_client ^3.1.4`, `go_router`, `injectable/get_it`, `image_picker`, `cached_network_image`, `dio`, `livekit_client ^2.6.4`, `flutter_ringtone_player ^4.0.0+4`, `record ^6.2.0`, `permission_handler ^12.0.1`, `video_player`
- *New (for video recording only)*: `flutter_screen_recording` (or `ed_screen_recorder` / platform channel — to be confirmed in implementation)
- *Backend*: NestJS, Mongoose, `socket.io`, `livekit-server-sdk ^2.15.1`
**Storage**:
- SQLite via `sqflite` (rooms, messages, contacts — already group-aware at v8)
- Local filesystem (recordings: stored in app documents directory; metadata in a new `recordings` SQLite table — see data-model.md)
- MongoDB (backend: chat rooms, messages)
**Testing**: `flutter_test` + `bloc_test`; Jest (backend); manual two-device test plan in quickstart.md
**Target Platform**: iOS 15+ / Android 6+ (mobile only)
**Project Type**: Mobile app (Flutter) + NestJS backend with LiveKit Cloud SFU
**Performance Goals**:
- Group messages: visible to all online members within 2 s under normal network
- Group info changes propagate within 3 s
- Group call join: receiver-to-media-active within 4 s after tapping Accept (matches existing 1-to-1 baseline)
- Recording start indicator visible to other participants within 2 s
**Constraints**:
- Offline-first: all group state readable from SQLite when offline
- Socket payloads delivered as `Map<dynamic,dynamic>` — safe-cast pattern mandatory (Constitution §IV-A)
- No Hive
- All media URLs resolved via `UrlUtils.resolveMediaUrl()`
- Recording media MUST stay on-device (Spec FR-035)
**Scale/Scope**:
- ≤ 256 members per group
- ≤ 32 concurrent participants per group call
- Existing message and room volume unchanged

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Group chat lives in `features/chat/`; group calls extend `features/video_call/`; recordings get a small `features/call_recording/` slice (data layer + domain entity + simple list page). Each layer follows presentation/domain/data discipline.
- [x] **II. State Management**: `ChatCubit` (existing) handles messaging; `CallCubit` (existing) extended for group calls; a new `CallRecordingCubit` manages start/stop/list. All states extend `Equatable`. Dependencies are constructor-injected via `get_it`/`injectable`.
- [x] **III. Offline-First (corrected)**: Per Constitution §III, `sqflite` for relational data and `FlutterSecureStorage` for sensitive credentials — Hive is NOT used. The existing v8 schema covers groups; one new local SQLite table (`recordings`) is added for recording metadata. No new credentials are introduced (LiveKit token is fetched per call via `Authorization: Bearer` header — never persisted).
- [x] **IV. Socket.IO**: All new events go through the existing `SocketService` singleton; transport remains WebSocket; auth remains `setAuth({'token': token})`. Handlers use the `data is! Map` safe-cast pattern (§IV-A). The room-based broadcast keeps idempotency: receiving the same `incomingGroupCall` twice does nothing if the call is already in `CallActive`.
- [x] **V. Teardown**: `CallCubit.reset()` (logout step 2) already disconnects LiveKit; extended to terminate any active group call session. `CallRecordingCubit.dispose()` stops the platform recorder and persists final file path. `PushNotificationService.dispose()` unchanged.
- [x] **Code Quality**: `snake_case` files; `PascalCase` classes; `flutter_lints` baseline; no `print`/`debugPrint` left in production paths besides existing logging.
- [x] **Error Handling**: All new REST/socket flows wrapped in repository methods returning `Either<Failure, T>`; LiveKit connect errors map to `ServerFailure`; recording permission errors surface as user-facing dialogs (not silent failures).

**Group-Specific Constitution Notes**:
- **§IV-A (Socket Map safety)** — strictly observed for new events `incomingGroupCall`, `groupCallParticipantJoined`, `groupCallParticipantLeft`, `groupCallRecordingStateChanged`.
- **§VIII (Media & URL resolution)** — group avatars use the existing upload pipeline; resolution via `UrlUtils.resolveMediaUrl()`.
- **§IX (Message status flow)** — group read receipts gate on `readByCount >= participantCount - 1` (sender excluded) in `ChatCubit.handleMessageStatusUpdate`.

## Project Structure

### Documentation (this feature)

```text
specs/007-group-chat/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── rest.md       # /chat/group/* + /video/room/* + recordings (no new endpoints, but documented)
│   └── socket.md     # existing + new group + group-call + recording-state events
└── tasks.md          # generated by /speckit-tasks (not by this command)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── di/                        # no change
│   ├── network/
│   │   ├── socket_service.dart    # ADD: incomingGroupCall, groupCallParticipantJoined/Left,
│   │   │                          #      groupCallRecordingStateChanged emit + on handlers
│   │   └── socket_events.dart     # ADD: new event name constants
│   └── theme/                     # no change
├── features/
│   ├── chat/                      # group messaging
│   │   ├── data/
│   │   │   ├── datasources/       # no change (group APIs already implemented)
│   │   │   └── models/            # no change
│   │   ├── domain/                # no change
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── chat_cubit.dart                # MODIFY: gate group read receipts on
│   │       │                                      #         readByCount/participantCount
│   │       ├── pages/
│   │       │   ├── create_group_page.dart         # ADD: group-avatar image picker
│   │       │   ├── group_chat_screen.dart         # REWRITE: replace stub, reuse ChatCubit,
│   │       │   │                                  #         show sender name on inbound bubbles
│   │       │   └── group_info_page.dart           # MODIFY: name/photo edit, verify leave flow
│   │       └── widgets/
│   │           └── group_sender_name.dart         # NEW: small label widget for inbound bubbles
│   ├── video_call/                # group calls (extend existing 1-to-1 LiveKit flow)
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── livekit_video_call_repository_impl.dart  # MODIFY: support N participants
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       └── call_participant.dart          # NEW: id, name, avatar, isMuted, isVideoOn
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── call_cubit.dart                # MODIFY: add CallActive variant with
│   │       │                                      #         List<CallParticipant>
│   │       └── pages/
│   │           ├── group_call_screen.dart         # NEW: participant grid + controls + REC indicator
│   │           └── incoming_group_call_screen.dart # NEW: variant of incoming for groups
│   └── call_recording/            # local recording (new slice)
│       ├── data/
│       │   ├── datasources/
│       │   │   └── recordings_local_data_source.dart  # NEW: sqflite + filesystem
│       │   └── models/
│       │       └── recording_model.dart           # NEW
│       ├── domain/
│       │   ├── entities/
│       │   │   └── recording.dart                 # NEW: id, callRoomId, filePath, durationMs,
│       │   │                                      #     hasVideo, createdAt
│       │   └── repositories/
│       │       └── recordings_repository.dart     # NEW (abstract)
│       └── presentation/
│           ├── bloc/
│           │   └── call_recording_cubit.dart      # NEW: start/stop, persist metadata
│           └── pages/
│               └── recordings_list_page.dart      # NEW: my recordings (browse, play, rename, delete)
└── main.dart                                       # no change

backend: src/modules/
├── chat/
│   ├── chat.service.ts             # MODIFY (small):
│   │                               #   - leaveGroup() → promote participants[0] (earliest joiner)
│   │                               #     instead of random
│   │                               #   - markMessagesRead() → include readByCount + participantCount
│   │                               #     when broadcasting messageRead for GROUP rooms
│   ├── chat.gateway.ts             # MODIFY:
│   │                               #   - on 'requestGroupCall': fan-out incomingGroupCall to all
│   │                               #     participants in the chatRoomId (excluding caller)
│   │                               #   - on 'leaveGroupCall': decrement participant count,
│   │                               #     auto-end when last leaves
│   │                               #   - new event handlers: groupCallParticipantJoined/Left,
│   │                               #     groupCallRecordingStateChanged
│   └── chat.controller.ts          # no change (existing /chat/group/* endpoints are sufficient)
└── video/
    └── video.controller.ts         # no change (POST /video/room/:roomId/join works for group rooms
                                    # — the roomId becomes the chatRoomId for group calls)
```

**Structure Decision**: Three feature slices — `chat` (existing, completed), `video_call` (existing, extended), `call_recording` (new). No changes to `core/` aside from `socket_service.dart` adding new event handlers and `socket_events.dart` adding event-name constants. No new modules in `core/di/` — get_it/injectable annotations on the new cubits/repositories are picked up by the existing build runner.

## Complexity Tracking

No constitution violations. All architectural rules from the constitution are honored. One justified deviation from minimalism:

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| New `call_recording` feature slice | Recording lifecycle (start/stop/persist metadata/list/play/delete) has its own state and storage; placing it inside `video_call/` would entangle two unrelated concerns and inflate `CallCubit` | Embedding inside `CallCubit` rejected because (a) `CallCubit` is already large and stateful, (b) recordings outlive a single call and need their own list/playback UI, (c) Clean Architecture §I prefers single-responsibility cubits |

---

## Implementation Phases (Reference for /speckit-tasks)

This section is **descriptive** — `/speckit-tasks` will produce the actionable task list.

### Phase A: Group Messaging Completion (P1 from spec)
1. Add avatar image picker to `create_group_page.dart` (calls existing `uploadFile`, passes `avatarUrl` to `createGroup`).
2. Rewrite `group_chat_screen.dart` as a real ChatCubit-driven screen; reuse the same message list, input bar, typing indicator, scroll controller, and media gallery widgets as the 1-to-1 chat screen. The only group-specific addition is the `GroupSenderName` widget above inbound bubbles.
3. Verify/complete `group_info_page.dart` — admin-gated name edit, photo edit, leave-group dialog.
4. Backend: `chat.service.ts` `leaveGroup()` → `participants[0]` succession.
5. Backend: `chat.service.ts` `markMessagesRead()` → include `readByCount`+`participantCount` in the `messageRead` socket payload for GROUP rooms.
6. Flutter: `ChatCubit.handleMessageStatusUpdate` → gate `delivered → read` on the new counts (backwards-compatible: when counts absent, fall back to existing behavior).
7. Routing: ensure `/group/create`, `/group/:roomId/chat`, `/group/:roomId/info` are wired in `app_router.dart`.

### Phase B: Group Calls (P2 from spec — US6)
1. Socket events (Flutter `socket_service.dart` + backend `chat.gateway.ts`):
   - `requestGroupCall { chatRoomId, isVideo }` — caller → server → all room participants except caller.
   - `incomingGroupCall { chatRoomId, callerId, callerName, isVideo, currentParticipantCount }` — server → invited members.
   - `acceptGroupCall { chatRoomId }` — joinee → server → fetch LiveKit token, broadcast `groupCallParticipantJoined` to room.
   - `declineGroupCall { chatRoomId }` — joinee → server (does NOT end call for others).
   - `leaveGroupCall { chatRoomId }` — participant → server → broadcast `groupCallParticipantLeft`; auto-end when count reaches 1.
2. Backend `video.controller.ts` already exposes `POST /video/room/:roomId/join` returning a LiveKit token; reused for group calls with `roomId = chatRoomId`. Token issuer must verify the caller is a current participant of the group.
3. `CallCubit` extension:
   - New state variant `CallActive` already exists; extend it with `List<CallParticipant> participants` and `bool isGroupCall`.
   - On `groupCallParticipantJoined` / `groupCallParticipantLeft`, update the participant list.
   - On `groupCallRecordingStateChanged`, surface a flag for the UI.
4. New `GroupCallScreen`:
   - Participant grid (auto-layout: 1-2 → big tiles; 3-6 → grid; 7+ → scrollable carousel with active speaker pinned).
   - Existing mute/camera/end-call controls reused.
   - REC indicator banner at top when ANY participant has recording enabled.
5. New `IncomingGroupCallScreen`: variant of the existing incoming-call screen showing "Caller X is calling Group Y (3 already joined)" with Accept/Decline.
6. `CallOverlay` routing: when state becomes `CallIncoming` with `isGroupCall: true`, push the new group incoming screen; when `CallActive` with `isGroupCall: true`, push `GroupCallScreen`.
7. Enforce 32-participant cap server-side (reject `acceptGroupCall` if already at 32 with `callError`); Flutter handles the error toast.

### Phase C: Local Call Recording (P2 from spec — FR-032..037)
1. Permissions: ensure microphone (existing) and on Android, `MediaProjection`/`FOREGROUND_SERVICE_MEDIA_PROJECTION` is requested when recording video.
2. New `CallRecordingCubit`:
   - `startRecording(callRoomId, includeVideo)` → emit start state, kick off platform recorder, broadcast `groupCallRecordingStateChanged { isRecording: true, recorderId }`.
   - `stopRecording()` → stop recorder, save file to app docs dir, insert `Recording` row, broadcast `groupCallRecordingStateChanged { isRecording: false }`.
3. Plugin selection: audio-only via existing `record: ^6.2.0`; video via `flutter_screen_recording` (or `ed_screen_recorder`) — final choice in tasks.md.
4. New `recordings` SQLite table (see data-model.md). Migration v9.
5. New `RecordingsListPage`: list, play (existing `video_player`/`just_audio`), rename, delete.
6. `GroupCallScreen` toolbar: "Record" toggle button; while recording, persistent REC banner (red dot) visible to all on the call.
7. Recording outlives the call: stopping the recording does NOT end the call; ending the call auto-stops recording if still running.

### Phase D: Verification (no regression)
- Manual smoke test of all existing 1-to-1 flows (see quickstart.md):
  - Send/receive text, image, video, voice
  - Status promotion: pending → sent → delivered → read
  - 1-to-1 voice/video call
  - Typing indicator
  - Logout teardown sequence
- All existing socket event handlers continue to use the safe-cast pattern (§IV-A).
- New events added to `socket_events.dart` constants — no string literals scattered.

**End of plan.md.** See `research.md`, `data-model.md`, and `contracts/` for design specifics.
