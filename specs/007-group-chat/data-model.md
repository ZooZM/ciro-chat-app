# Data Model: Group Chat + Group Calls + Shared Call Recording

**Phase 1 output** | Generated: 2026-05-14 | Revised: 2026-05-16

> **Revision (2026-05-16)**: Recording entity gains `share_status` and `shared_message_id`
> fields. INV-6 revised. Active-call tracking entity formalized.

## 1. Messaging Entities (Existing — no schema change required)

### ChatSession (Flutter domain)

```
ChatSession
├── id: String
├── name: String
├── type: ChatRoomType            — PRIVATE | GROUP
├── participants: List<String>    — phone numbers
├── admins: List<String>          — phone numbers (size ≥ 1 for GROUP)
├── description: String
├── avatarUrl: String?
├── lastMessage: String?
├── lastMessageTime: DateTime?
├── unreadCount: int
└── isOnline: bool                — PRIVATE only
```

### Message (Flutter domain) — no field change; status-update logic gated for groups

```
Message
├── id: String
├── clientMessageId: String       — dedup key
├── roomId: String                — agnostic for PRIVATE/GROUP
├── senderId: String
├── senderPhone: String           — used to display sender name in groups
├── content: String
├── type: MessageType
├── fileUrl: String?
├── metadata: Map<String,dynamic>?
├── status: MessageStatus         — pending(0) → sent(1) → delivered(2) → read(3)
├── createdAt: DateTime
└── isDeleted: bool
```

**Group read-receipt rule** (enforced in `ChatCubit.handleMessageStatusUpdate`, no schema change):
- `delivered → read` only when incoming socket payload has `readByCount >= participantCount - 1`
- For private chats, payload omits these counts; fall back to existing immediate promotion.

### ChatRoom (Backend MongoDB) — no schema change

```
ChatRoom
├── _id: ObjectId
├── type: 'PRIVATE' | 'GROUP'
├── participants: ObjectId[]      — insertion-ordered; index 0 = earliest joiner
├── admins: String[]              — phone numbers
├── name: String?
├── avatarUrl: String?
├── description: String?
├── lastMessage: ObjectId?
└── updatedAt: Date
```

### Message (Backend MongoDB) — no schema change

```
Message
├── _id: ObjectId
├── chatRoomId: ObjectId
├── senderId: ObjectId
├── content: String
├── messageType: String
├── fileUrl: String?
├── metadata: Object?
├── clientMessageId: String       — unique index
├── status: String
├── deliveredTo: String[]
└── readBy: String[]
```

### SQLite (Flutter, v8 — no migration for messaging)

```sql
CREATE TABLE rooms (
  id            TEXT PRIMARY KEY,
  name          TEXT,
  type          TEXT DEFAULT 'PRIVATE',
  participants  TEXT DEFAULT '[]',         -- JSON List<String>
  admins        TEXT DEFAULT '[]',         -- JSON List<String>
  description   TEXT DEFAULT '',
  avatar_url    TEXT,
  last_message  TEXT,
  last_msg_time INTEGER,
  unread_count  INTEGER DEFAULT 0
);
```

---

## 2. Call Entities (Group Calls — extend existing CallCubit state)

### CallParticipant (Flutter domain — NEW)

```
CallParticipant
├── userId: String                — backend user id
├── phoneNumber: String           — contact lookup key
├── displayName: String           — resolved from contacts
├── avatarUrl: String?
├── isMicMuted: bool              — per-participant LiveKit track state
├── isVideoOn: bool
├── isSpeaking: bool              — LiveKit active-speaker signal (for UI highlight)
└── joinedAt: DateTime
```

### CallSession (Flutter — internal to CallCubit state, NOT persisted)

```
CallSession (extends existing CallActive payload)
├── chatRoomId: String            — the group room being called; for 1-to-1, the inferred 1:1 room
├── isGroupCall: bool             — flag to drive UI routing
├── isVideo: bool
├── participants: List<CallParticipant>
├── recordingState: RecordingState
└── livekitRoomName: String       — same as chatRoomId for groups
```

```
RecordingState
├── isRecording: bool
├── recorderUserId: String?       — null when no one is recording
└── recorderName: String?         — displayed in REC banner
```

**Backend tracking** (NOT a Mongo document — in-memory in `chat.gateway.ts`):
- `activeGroupCalls: Map<chatRoomId, Set<userId>>` — currently joined participants per group call.
- Used to enforce 32-participant cap (FR-027) and to auto-end calls (FR-026).
- Cleared on backend restart; calls in-progress at restart would orphan. Acceptable for v1 — restart is rare and clients will see `callError` on next event attempt.

### State Transitions — Group Call

```
[no call]
   │  user taps "Start Group Call" → emit requestGroupCall
   ▼
CallOutgoing (caller side)        ──╮
                                    │  cancel → endCall
                                    ▼
                              [no call]

CallIncoming (invited member)
   │  acceptGroupCall → fetch token → connect
   ▼
CallConnecting (LiveKit handshake)
   │  on connected → emit groupCallParticipantJoined
   ▼
CallActive { participants: [...], recordingState: {...} }
   │  participant joins   → add to list
   │  participant leaves  → remove from list
   │  recording toggles   → update recordingState
   │  count drops to 1    → backend ends call → all clients see CallEnded
   ▼
CallEnded { reason: 'last-participant' | 'self-leave' | 'declined' | 'error' }
```

---

## 3. Recording Entities (revised 2026-05-16 — capture + gallery save + chat share)

### Recording (Flutter domain — NEW)

```
Recording
├── id: String                    — UUID generated client-side
├── callRoomId: String            — chatRoomId where the call took place
├── callRoomName: String          — group name at time of recording (denormalized for listing)
├── filePath: String              — absolute path inside app documents (working copy)
├── galleryPath: String?          — public path after gallery/Downloads save (null on failure)
├── durationMs: int               — final duration after stop
├── hasVideo: bool                — true for video calls, false for voice calls (FR-032a)
├── sizeBytes: int
├── createdAt: DateTime
├── displayName: String           — user-editable; defaults to "Recording <YYYY-MM-DD HH:mm>"
├── shareStatus: ShareStatus      — idle | uploading | shared | failed
└── sharedMessageId: String?      — clientMessageId of the chat message once shared (FR-035)
```

```
enum ShareStatus { idle, uploading, shared, failed }
```

### SQLite — NEW migration v9

```sql
CREATE TABLE recordings (
  id                 TEXT PRIMARY KEY,
  call_room_id       TEXT NOT NULL,
  call_room_name     TEXT NOT NULL,
  file_path          TEXT NOT NULL,
  gallery_path       TEXT,                          -- nullable
  duration_ms        INTEGER NOT NULL DEFAULT 0,
  has_video          INTEGER NOT NULL DEFAULT 0,    -- 0 = audio-only, 1 = video
  size_bytes         INTEGER NOT NULL DEFAULT 0,
  created_at         INTEGER NOT NULL,              -- epoch millis
  display_name       TEXT NOT NULL,
  share_status       TEXT NOT NULL DEFAULT 'idle',  -- idle | uploading | shared | failed
  shared_message_id  TEXT                           -- nullable; FK by value to messages.client_message_id
);

CREATE INDEX idx_recordings_created_at ON recordings(created_at DESC);
CREATE INDEX idx_recordings_call_room ON recordings(call_room_id);
CREATE INDEX idx_recordings_share_status ON recordings(share_status);
```

**Migration order** (Constitution §III):
- v8 → v9: `CREATE TABLE recordings ...` (no drop, no data migration).
- The migration runner in `chat_local_data_source.dart` already supports versioned upgrades.

### State Transitions — Recording

```
[idle]
   │  user taps "Record" in GroupCallScreen
   │  request mic permission (audio) or screen-record permission (video)
   ▼
[recording { hasVideo }]
   │  emit groupCallRecordingStateChanged { isRecording: true, recorderId }
   │  audio: start `record` capture into <docs>/recordings/<uuid>.m4a
   │  video: start screen recorder into <docs>/recordings/<uuid>.mp4
   ▼
   │  user taps "Stop" OR call ends OR app paused
   ▼
[stopping]
   │  finalize file; read size; compute duration
   │  INSERT INTO recordings (..., share_status='idle')
   │  emit groupCallRecordingStateChanged { isRecording: false }
   ▼
[saving-to-gallery]
   │  video: gal.putVideo(filePath) → galleryPath
   │  audio: write to Downloads/CiroRecordings/ (Android) or Documents/Recordings/ (iOS)
   │  UPDATE recordings SET gallery_path = ?
   │  on failure: snackbar; gallery_path remains null; proceed
   ▼
[uploading]
   │  UPDATE recordings SET share_status = 'uploading'
   │  call ChatRemoteDataSource.uploadFile(filePath, category='recording') → fileUrl
   │  on failure: UPDATE share_status = 'failed'; user can retry from RecordingsListPage
   ▼
[sharing]
   │  call ChatCubit.sendMediaMessage(callRoomId, fileUrl, type=hasVideo?video:audio)
   │  on success: UPDATE share_status='shared', shared_message_id = clientMessageId
   │  on failure: UPDATE share_status = 'failed'
   ▼
[idle] (Recording row visible in RecordingsListPage with status icon)
```

**Failure handling**:
- Permission denied → show dialog, return to [idle].
- Disk full → catch IOException, show snackbar, attempt to finalize partial file (if size > 3 s of audio or 5 s of video, keep; else delete).
- App killed mid-recording → on next launch, scan `<docs>/recordings/` for orphan files (file exists but no DB row), import them with default display name and best-effort `createdAt` from file mtime; status set to `failed` so the user is prompted to retry the share.
- Gallery save fails (permission denied / Photos full) → snackbar; recording row's `gallery_path` stays null; the chat-share pipeline still runs (these failures are independent).
- Upload fails → `share_status = 'failed'`; recording remains in list; long-press → Retry share.
- Send-message fails (after successful upload) → `share_status = 'failed'`; retry runs only the send-message step (the uploaded `fileUrl` is preserved on the recording row — add a `pending_file_url` column in a future migration if recovery is needed; v1 simply re-uploads on retry).

---

## 3a. Active Call Tracking (Server-Side, formalized 2026-05-16)

This was previously an implicit in-memory map. Formalized here as a first-class entity to
support FR-038 (Join Call button).

### ActiveGroupCall (Backend — in-memory; not persisted)

```
ActiveGroupCall
├── chatRoomId: string
├── participants: Set<userId>     — currently joined
├── recorders: Set<userId>        — currently recording
├── startedAt: Date
└── isVideo: boolean              — set by the initiating requestGroupCall
```

Maintained in `chat.gateway.ts` as `Map<chatRoomId, ActiveGroupCall>`. Cleared on restart;
acceptable for v1 — restart is rare and clients re-discover state via `acceptGroupCall`
error responses or the next `groupCallActive` emit.

### Lifecycle Events

```
[no entry]
   │  requestGroupCall received
   ▼
   │  create entry with caller as first participant
   │  emit incomingGroupCall to room members (except caller)
   │  emit groupCallActive { chatRoomId } to room members (including caller)
   ▼
[active call]
   │  acceptGroupCall received → participants.add(userId); emit groupCallParticipantJoined
   │  leaveGroupCall received   → participants.delete(userId); emit groupCallParticipantLeft
   │  groupCallRecordingStateChanged → update recorders set; rebroadcast
   ▼
   │  participants.size drops to 1
   ▼
[ending]
   │  emit callEnded to last participant
   │  emit groupCallEnded { chatRoomId } to room members
   │  delete entry
   ▼
[no entry]
```

### Replay-on-Connect

When a user's socket connects (`handleConnection`):
1. Look up the user's chat rooms.
2. For each room with an entry in `activeGroupCalls`, emit `groupCallActive { chatRoomId }`
   to that user so the Flutter `ChatCubit` can hydrate `_activeCallRoomIds`.
3. This drives FR-038's "Join Call button visible across app restarts."

---

## 4. Invariants

| # | Invariant | Enforced In |
|---|-----------|-------------|
| INV-1 | Message.status only moves forward | `ChatCubit.handleMessageStatusUpdate` (existing) |
| INV-2 | Group read receipts gate on `readByCount >= participantCount - 1` | Same function (new check) |
| INV-3 | Group admin succession picks `participants[0]` | `chat.service.ts` `leaveGroup()` |
| INV-4 | Group call participant cap = 32 | `chat.gateway.ts` `handleAcceptGroupCall` |
| INV-5 | Group call auto-ends when participant count drops to 1 | `chat.gateway.ts` `handleLeaveGroupCall` |
| INV-6 (revised) | Recording media is captured locally, saved to OS gallery (video) or Downloads (audio), and posted as a media message in the originating chat thread; the recording file itself never travels via the LiveKit data channel or any non-standard transport | `CallRecordingCubit` — uses `ChatRemoteDataSource.uploadFile` + `ChatCubit.sendMediaMessage` (existing media pipeline) |
| INV-7 | REC indicator visible to all participants when any one records, **including late joiners** | Socket broadcast of `groupCallRecordingStateChanged` + `currentRecorders` field in `acceptGroupCall` response |
| INV-8 | All Socket payloads cast via `Map<String,dynamic>.from(data)` after `is! Map` guard | Constitution §IV-A — applies to every new handler |
| INV-9 | LiveKit token issuance verifies caller is a participant of the requested room | `video.service.ts` (small new check) |
| INV-10 (new) | Format auto-matches call type: voice call → audio recording (M4A/AAC); video call → video recording (MP4) | `CallRecordingCubit.start` reads `CallActive.isVideo` and routes to the matching `RecordingCaptureService` method (FR-032a) |
| INV-11 (new) | `groupCallActive` / `groupCallEnded` socket events are the single source of truth for the "Join Call" AppBar action; on socket reconnect, the server replays `groupCallActive` for every room of the user with an active call | `chat.gateway.ts.handleConnection` replay + `ChatCubit._activeCallRoomIds` set (FR-038) |
| INV-12 (new) | A failed recording share remains in the local `recordings` table with `share_status = 'failed'` and is never silently deleted; user must explicitly delete or retry from `RecordingsListPage` | `RecordingsRepository` + `RecordingsListPage` long-press menu |
