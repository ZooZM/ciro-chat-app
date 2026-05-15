# Research: Group Chat + Group Calls + Local Recording

**Phase 0 output** | Generated: 2026-05-14

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

### Recording Adjustment to Spec

Spec FR-032 says "start a **local** recording" without specifying media tracks. Per decision **C2**, v1 implements **audio-only** local recording. This is a documented narrowing — the universal REC indicator (FR-033/034) and on-device storage (FR-035) still apply. A note will be added to the spec's Assumptions section reflecting this scope:
> *Spec note (v1 implementation narrowing)*: Local recording in v1 captures audio only. Local video recording is deferred pending a follow-up scope decision. The REC indicator semantics (FR-033/034) are unchanged.

---

## 4. Open Items Flagged for Implementation Phase

These are not blockers for planning but should be addressed during `/speckit-tasks` / implementation:

1. **`flutter_screen_recording` decision** — only relevant if/when video recording is brought into scope (deferred per C2).
2. **TURN configuration** — currently relies on LiveKit's managed infrastructure. If self-hosting LiveKit later, an explicit TURN cluster is needed for restrictive networks.
3. **Push notification for incoming group calls** when target is offline — backend has `PushService` but call signaling does not currently push (only chat messages do). For groups this becomes more relevant since members may have inconsistent online state.
4. **LiveKit server URL** — move from hardcoded to `.env`-driven (decision **B9**).
