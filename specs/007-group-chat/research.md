# Research: Group Chat + Group Calls + Shared Call Recording

**Phase 0 output** | Generated: 2026-05-14 | Revised: 2026-05-16

> **Revision note (2026-05-16)**: Recording scope expanded from local-only to (a) auto-format
> by call type, (b) save to device gallery / Downloads, and (c) share via group chat.
> Decisions C1, C2, C4 below have been superseded by RD-1 through RD-5 in §5.

## 1. Group Messaging (Existing Infrastructure)

### Backend (NestJS + MongoDB)

| Component | Status | Path |
|-----------|--------|------|
| `ChatRoom` schema with `type: PRIVATE \| GROUP`, `participants[]`, `admins[]`, `name`, `avatarUrl` | ✅ Complete | `src/modules/chat/schemas/chat-room.schema.ts` |
| `Message` schema with `deliveredTo[]`, `readBy[]` per-member arrays | ✅ Complete | `src/modules/chat/schemas/message.schema.ts` |
| `POST /chat/group/create`, `/add`, `/remove`, `/leave` | ✅ Complete | `chat.controller.ts` + `chat.service.ts` |
| `POST /chat/upload` (20 MB cap, multipart) | ✅ Complete | same |
| Room-based socket broadcasting | ✅ Complete | `chat.gateway.ts` |

### Flutter (Domain + Data + Cubit)

| Component | Status | Path |
|-----------|--------|------|
| `ChatRoomType` enum + `ChatSession` participants/admins fields | ✅ Complete | `domain/entities/chat_session.dart` |
| SQLite v8 (`type`, `participants`, `admins`) | ✅ Complete | `data/datasources/chat_local_data_source.dart` |
| `ChatCubit.createGroup` / `addParticipants` / `removeParticipant` | ✅ Complete | `presentation/bloc/chat_cubit.dart` |
| Contact selection UI for group creation | ✅ Complete | `features/contacts/...` |

### Flutter Presentation — Gaps

| Component | Status |
|-----------|--------|
| `CreateGroupPage` (name + member multi-select) | ⚠️ Missing avatar picker |
| `GroupChatScreen` | ❌ Hardcoded stub — full rewrite |
| `GroupInfoPage` | ⚠️ Add/remove works; needs name/photo edit and verified leave flow |
| Sender-name label above inbound bubbles | ❌ Not implemented |

### Decisions for Phase A

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|------------------------|
| A1 | Replace `GroupChatScreen` stub completely | Stub has no ChatCubit integration; replacement is cleaner than patching | Adding `isGroup` flag to `ChatScreen` — entangles two screens; violates SRP |
| A2 | Inline `GroupSenderName` widget above inbound bubbles only | FR-008 (sender label not on own messages); minimal UI surface | Embedding inside the bubble — harder to style, breaks alignment with existing bubble widget |
| A3 | Read-receipt gating: `readByCount >= participantCount - 1` (sender excluded) | Spec resolution (blue ticks = all read) | Per-member overlay UI — out of v1 scope; the binary state matches sender expectations |
| A4 | Backend admin succession via `participants[0]` (insertion-ordered) | MongoDB `$pull` preserves array order, so index 0 = earliest joiner; spec Q2 resolution | Storing explicit `joinedAt` per participant — requires schema migration for zero added correctness |
| A5 | Backwards-compatible `messageRead` socket payload | Adding `readByCount`/`participantCount` fields is additive; private chats omit them, existing behavior preserved | Separate `groupMessageRead` event — duplicates logic; harder to maintain |

---

## 2. Group Calls (Existing LiveKit Infrastructure)

### Critical Finding: LiveKit Is Already In Use

The app **already operates as a LiveKit client/server pair** for 1-to-1 calls:

| Layer | Package | Version | Path |
|-------|---------|---------|------|
| Flutter | `livekit_client` | 2.6.4 | `pubspec.yaml` |
| Backend | `livekit-server-sdk` | 2.15.1 | `package.json` |

**LiveKit server**: managed cloud — `wss://ciro-chat-qc2pe2cz.livekit.cloud` (hardcoded in `video_call_cubit.dart:18` — flagged for env-config improvement).

**Token endpoint**: `POST /video/room/:roomId/join` (returns `{ token }`). Implemented in `video.controller.ts` + `video.service.ts`. The token grants `roomJoin: true, canPublish: true, canSubscribe: true` for the specified `room` name.

**1-to-1 call flow** (current):
1. Caller emits `requestCall { targetUserId, isVideo }` → backend
2. Backend emits `incomingCall` → target socket
3. Target emits `acceptCall { callerId }` → backend
4. Backend generates LiveKit tokens for both, emits `callAccepted { livekitUrl, livekitToken }` → both
5. Both clients connect to LiveKit room `call_{callerId}_{receiverId}`
6. Either emits `endCall` → backend → `callEnded` → partner

### Decisions for Phase B (Group Calls)

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|------------------------|
| B1 | Reuse LiveKit (no new SFU) | Already in production for 1-to-1; supports 32+ participants natively; zero new infrastructure | Janus / Mediasoup / self-hosted LiveKit OSS — replacing a working managed SFU adds operational burden for no scope benefit |
| B2 | Use the **chatRoomId** as the LiveKit room name for group calls | Single source of truth; no separate call-session ID; backend can verify participant membership by querying ChatRoom | Synthetic `groupcall_{uuid}` IDs — requires extra tracking table; complicates rejoin |
| B3 | New socket events for group call signaling rather than overloading 1-to-1 events | 1-to-1 events take a single `targetUserId`/`callerId`; group calls need fan-out and per-participant join/leave; separate events keep payloads typed | Overloading `requestCall` with optional `chatRoomId` — breaks the existing simple semantics, increases regression risk |
| B4 | New events: `requestGroupCall`, `incomingGroupCall`, `acceptGroupCall`, `declineGroupCall`, `leaveGroupCall`, `groupCallParticipantJoined`, `groupCallParticipantLeft`, `groupCallRecordingStateChanged` | Each event has a single responsibility; matches existing naming style; all carry `chatRoomId` for room routing | A monolithic `groupCallSignal` envelope with a `type` field — harder to type-check, fights the existing per-event callback pattern in `SocketService` |
| B5 | Auto-end group call when participant count drops to 1 (FR-026) | Matches WhatsApp/Telegram; prevents abandoned 1-person rooms | Auto-end when all leave (count = 0) — leaves UI in a weird half-state if last person closes app |
| B6 | 32-participant cap enforced server-side in `acceptGroupCall` | Defense in depth; client-side check is advisory | Client-only enforcement — easily bypassed by a modified client |
| B7 | Group call screen shows participant tiles in a responsive grid; existing mute/camera/end-call controls reused unchanged | Constitution §I (preserve what works); muting/camera state is per-participant via LiveKit local-participant API | Custom new control panel — duplicates working code |
| B8 | Late-join supported (FR-025) — late joiner gets the existing LiveKit room state via standard SFU subscription | LiveKit's protocol handles this natively; nothing to implement | Reject late-join — fails FR-025 |
| B9 | LiveKit server URL moves from hardcoded to `AppConstants.liveKitWsUrl` (read from `.env` like `apiBaseUrl`) | Constitution §VIII-B (env-driven config); avoids prod/dev drift | Leave hardcoded — fails Constitution rule and creates regression risk |

### Backend Token Issuer — Group Authorization

The token endpoint `POST /video/room/:roomId/join` currently issues a token for any authenticated user. For group calls, it MUST verify the requesting user is a current participant of the chat room with that ID. **Small change in `video.service.ts`**: cross-reference `ChatRoom.participants` before issuing the token.

---

## 3. Local-Only Call Recording

### Existing Capabilities

| Capability | Package | Available? |
|------------|---------|-----------|
| Audio recording | `record: ^6.2.0` | ✅ Already in pubspec |
| Microphone permission | `permission_handler: ^12.0.1` | ✅ Already in pubspec |
| Local audio playback | `just_audio: ^0.10.5`, `audioplayers: ^6.1.0` | ✅ Already in pubspec |
| Local video playback | `video_player: ^2.11.1` | ✅ Already in pubspec |
| **Screen / video recording** | **none** | ❌ Need to add |

### Decisions for Phase C (Recording)

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|------------------------|
| C1 | Audio-only recording in v1 via `record: ^6.2.0` capturing the **device's mic output mix** | Simplest; works on both platforms identically; no new plugin; no foreground service needed on Android | Capture LiveKit decoded audio tracks — requires deep LiveKit SDK hooks not exposed by `livekit_client` Dart bindings |
| C2 | Video recording deferred to a fast-follow if user demands (note: spec FR-032 says "local recording") | Screen-capture plugins (`flutter_screen_recording`) require Android `FOREGROUND_SERVICE_MEDIA_PROJECTION`, iOS ReplayKit setup, and an entire consent UX flow that exceeds the simple "REC indicator" spec | Force video recording into v1 — doubles implementation surface for marginal user value |
| C3 | Recording state broadcast via socket event `groupCallRecordingStateChanged { chatRoomId, recorderId, isRecording }` | Universal REC indicator (FR-033) requires all participants to know when any one of them is recording; LiveKit data channels could carry this but socket.io is already the project's signaling backbone | LiveKit data channel for recording state — adds a parallel signaling path; harder to test |
| C4 | Recordings stored in app documents directory (`getApplicationDocumentsDirectory()/recordings/`) | Standard iOS/Android private storage; survives app restarts; not visible to system gallery (good for privacy) | External storage / system camera roll — leaks recordings into Photos app without explicit user opt-in |
| C5 | New SQLite table `recordings` (id, callRoomId, filePath, durationMs, hasVideo, createdAt) at migration v9 | Allows the new `RecordingsListPage` to query/filter; relational consistency with chat schema | Filesystem-only with directory listing — slower (must stat each file), no efficient sort/filter |
| C6 | "Universal REC indicator" UI: persistent red badge at top of `GroupCallScreen` while *any* participant is recording, with text "Recording in progress" and recorder's name | FR-033; matches user expectation that recording is consent-by-notification | Per-participant red dot on each tile only — easily missed; doesn't satisfy "clearly displayed" wording in FR-033 |
| C7 | Stop recording does NOT end the call; ending the call auto-stops any active recording | Decoupled lifecycles; matches spec FR-035..037 wording | Stop = end call — surprises user, loses other participants' calls |

### Recording Adjustment to Spec (Historical — 2026-05-14)

Originally narrowed to audio-only per C2 (v1 implementation narrowing). This narrowing has
been **superseded** by the 2026-05-16 spec update (FR-032a, FR-035, FR-036). See §5 for
revised decisions.

---

## 4. Open Items Flagged for Implementation Phase

These are not blockers for planning but should be addressed during `/speckit-tasks` / implementation:

1. **TURN configuration** — currently relies on LiveKit's managed infrastructure. If self-hosting LiveKit later, an explicit TURN cluster is needed for restrictive networks.
2. **Push notification for incoming group calls** when target is offline — backend has `PushService` but call signaling does not currently push (only chat messages do). For groups this becomes more relevant since members may have inconsistent online state.
3. **LiveKit server URL** — move from hardcoded to `.env`-driven (decision **B9**).

---

## 5. Revised Recording Decisions (2026-05-16)

The spec was updated 2026-05-16 to require (a) recording format auto-selected by call type,
(b) save to device gallery / Downloads, and (c) share to all group members via the group
chat thread. The following decisions supersede C1, C2, and C4 above.

### Affected Spec Requirements

- **FR-032a** (new): Audio-only for voice calls; video for video calls — no manual format.
- **FR-035** (revised): Saved to gallery (video) / Downloads (audio) AND posted as a group
  chat media message.
- **FR-036** (revised): All group members access the recording via the chat message.
- **FR-038** (new): Active-call awareness for Join Call AppBar action.
- **SC-007** (new): Recording in chat within 30 s of stop.
- **SC-008** (new): Join Call button within 5 s of state change.

### Decisions

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|------------------------|
| RD-1 | **Video recording package**: use [`flutter_screen_recording`](https://pub.dev/packages/flutter_screen_recording) (v3.x). Captures the device screen with system audio (Android: MediaProjection; iOS: ReplayKit). | Mature, actively maintained, supports both platforms with the same API surface, returns a file path matching our needs. Captures whatever is rendered (LiveKit video tiles), so it works regardless of LiveKit internals. | `ed_screen_recorder` — less mature, fewer downloads. Custom platform channel — too much surface for one feature. Capturing LiveKit's decoded tracks directly — Dart bindings don't expose them. |
| RD-2 | **Gallery save**: use [`gal`](https://pub.dev/packages/gal) (v2.x). For video files, calls `Gal.putVideo(path)` → Photos/Gallery. | Single API for both platforms; correctly handles iOS Photos permission and Android scoped storage on Android 10+. | `gallery_saver` — unmaintained. `image_gallery_saver` — abandoned. Custom platform channel — reinventing the wheel. |
| RD-3 | **Downloads folder save** (for audio): on Android, use `path_provider`'s `getDownloadsDirectory()` (Android 11+) or write to `/storage/emulated/0/Download/CiroRecordings/` via scoped storage helper. On iOS, write to the app's `Documents/Recordings/` directory and expose via the Files app (`UIFileSharingEnabled` already set in Info.plist for the app). | iOS has no "Downloads" equivalent — Files app exposure is the platform-idiomatic option. Android Downloads dir is the standard location for non-media user files. | Save audio to gallery — Gallery on Android is for media (photos/videos); audio doesn't appear there. Force users to use share sheet — fails FR-035 ("MUST automatically save"). |
| RD-4 | **Active-call tracking** (FR-038): backend maintains the existing `activeGroupCalls: Map<chatRoomId, Set<userId>>` and emits new socket events `groupCallActive { chatRoomId }` when a call starts, `groupCallEnded { chatRoomId }` when it ends. On socket connect, the gateway replays `groupCallActive` for each of the user's rooms that currently has an active call. | Adds the hydration semantics needed by FR-038 with zero new persistence (in-memory map already exists). Replay-on-connect handles app cold-start. | Polling `GET /chat/group/:id/active-call` — extra network traffic, no real-time update. Storing active-call state in MongoDB — overkill for ephemeral data. |
| RD-5 | **Late-joiner recording state** (FR-033 plug): on `acceptGroupCall`, the server response includes `currentRecorders: string[]` so the joining client immediately knows whether recording is active and can render the REC banner without waiting for the next state-change event. | Closes the late-joiner gap identified in `/speckit-analyze` finding M2. Server already tracks recording state per active call. | Re-broadcast `groupCallRecordingStateChanged` to all on every join — wasteful and emits to clients that already have the state. |
| RD-6 | **Sharing pipeline**: after `stop()`, run sequentially: (1) save to gallery/Downloads (best-effort, snackbar on fail), (2) upload via existing `POST /chat/upload`, (3) send media message via existing `sendMessage` socket event with the returned `fileUrl`. The recording row tracks `share_status` ∈ {idle, uploading, shared, failed}. | Reuses the existing media pipeline — zero new backend endpoints; works offline (queues via existing offline-queue infrastructure for messaging); audit trail in `recordings` table. | Direct file post to a new `/recordings/share` endpoint — duplicates existing media flow. Skipping the media-message step and using a custom in-app notification — recordings would not appear in chat history (fails FR-036's "access from chat"). |
| RD-7 | **Retry-on-failure UX**: failed shares persist in the `recordings` table with `share_status = failed`. The recordings list page surfaces a "Retry share" action via long-press. Manual retry reruns the upload + send-message steps; on success, updates `share_status = shared` and persists `shared_message_id`. | Spec FR-035 says auto-share but does not require immediate success on poor networks. Manual retry from a visible list matches user expectation for media uploads. | Infinite background retry — wastes battery; could resurface a recording days later, surprising the user. Discard on first failure — fails the "MUST share" intent of FR-035. |
| RD-8 | **Recording file size policy**: warn-on-stop if file > 100 MB (audio) or > 500 MB (video) but proceed with both gallery save and chat share. Hard reject only above the existing media upload cap (currently 20 MB — needs lift; see RD-9). | Recordings can legitimately be long; per the plan's 500 MB / 2 GB envelope. Hard rejection at 20 MB would make most recordings unshareable. | No size limit — risks bricked uploads on poor networks. |
| RD-9 | **Increase media upload cap** for recording media: lift the backend `POST /chat/upload` `MAX_FILE_SIZE` from 20 MB to 500 MB **only when** the request includes a `category: 'recording'` form field; otherwise the existing 20 MB cap stands. | Avoids relaxing limits for arbitrary uploads; recordings have a clear category marker; protects existing flows. | Single global lift to 500 MB — abuse risk and storage cost. Separate `/chat/upload/recording` endpoint — code duplication. |
| RD-10 | **REC banner shows recorder names (plural)** when multiple participants record simultaneously | FR-033 says "clearly displayed" — surfacing every recorder's name communicates the situation accurately. | Single-recorder text only — misleads when 2+ are recording. |

### Updated Invariants (replaces INV-6 in data-model.md)

- **INV-6 (revised)**: Recording media is captured locally and additionally saved to the
  device gallery (video) or Downloads (audio). The recording file is uploaded to the
  existing media upload endpoint AND posted as a media message in the originating group
  chat thread so all current group members can access it. The recording file itself is
  never delivered via the LiveKit data channel or any non-standard transport.

### Open Items (revised)

1. **iOS audio Downloads save** — `gal` does not save audio. Implementation will write to
   `Documents/Recordings/` and rely on `UIFileSharingEnabled = YES` in `Info.plist` so users
   see the files in the iOS Files app. Verify this flag is present (check `ios/Runner/
   Info.plist`).
2. **Storage permission on older Android** — Android 9 and earlier need
   `WRITE_EXTERNAL_STORAGE`. Android 10+ uses scoped storage. The `gal` package handles
   gallery writes; Downloads writes need a small platform branch.
3. **iOS ReplayKit caveat** — system-level ReplayKit recording shows an iOS-managed banner
   in addition to our in-app REC banner. This is acceptable — actually reinforces consent.
4. **Recording during reconnect** — if socket drops while recording, the state-change emit
   on stop will be buffered by `SocketService`'s existing reconnect logic. Test that the
   buffered emit is sent after reconnect; if not, add an explicit replay.
