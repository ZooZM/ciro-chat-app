# Data Model: Group Chat + Group Calls + Local Recording

**Phase 1 output** | Generated: 2026-05-14

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

## 3. Recording Entities (NEW — local-only)

### Recording (Flutter domain — NEW)

```
Recording
├── id: String                    — UUID generated client-side
├── callRoomId: String            — chatRoomId where the call took place
├── callRoomName: String          — group name at time of recording (denormalized for listing)
├── filePath: String              — absolute path inside app documents
├── durationMs: int               — final duration after stop
├── hasVideo: bool                — false in v1 (audio-only narrowing)
├── sizeBytes: int
├── createdAt: DateTime
└── displayName: String           — user-editable; defaults to "Recording <YYYY-MM-DD HH:mm>"
```

### SQLite — NEW migration v9

```sql
CREATE TABLE recordings (
  id              TEXT PRIMARY KEY,
  call_room_id    TEXT NOT NULL,
  call_room_name  TEXT NOT NULL,
  file_path       TEXT NOT NULL,
  duration_ms     INTEGER NOT NULL DEFAULT 0,
  has_video       INTEGER NOT NULL DEFAULT 0,    -- 0 = audio-only, 1 = video
  size_bytes      INTEGER NOT NULL DEFAULT 0,
  created_at      INTEGER NOT NULL,              -- epoch millis
  display_name    TEXT NOT NULL
);

CREATE INDEX idx_recordings_created_at ON recordings(created_at DESC);
CREATE INDEX idx_recordings_call_room ON recordings(call_room_id);
```

**Migration order** (Constitution §III):
- v8 → v9: `CREATE TABLE recordings ...` (no drop, no data migration).
- The migration runner in `chat_local_data_source.dart` already supports versioned upgrades.

### State Transitions — Recording

```
[idle]
   │  user taps "Record" in GroupCallScreen
   │  request mic permission (if not granted)
   ▼
[recording]
   │  emit groupCallRecordingStateChanged { isRecording: true, recorderId }
   │  start `record` package capture into <docs>/recordings/<uuid>.m4a
   ▼
   │  user taps "Stop" OR call ends OR app paused
   ▼
[stopping]
   │  finalize file; read size; compute duration
   │  INSERT INTO recordings ...
   │  emit groupCallRecordingStateChanged { isRecording: false }
   ▼
[idle] (Recording row visible in RecordingsListPage)
```

**Failure handling**:
- Permission denied → show dialog, return to [idle].
- Disk full → catch IOException, show snackbar, attempt to finalize partial file (if size > 0, keep; else delete).
- App killed mid-recording → on next launch, scan `<docs>/recordings/` for orphan files (file exists but no DB row), import them with default display name and best-effort `createdAt` from file mtime.

---

## 4. Invariants

| # | Invariant | Enforced In |
|---|-----------|-------------|
| INV-1 | Message.status only moves forward | `ChatCubit.handleMessageStatusUpdate` (existing) |
| INV-2 | Group read receipts gate on `readByCount >= participantCount - 1` | Same function (new check) |
| INV-3 | Group admin succession picks `participants[0]` | `chat.service.ts` `leaveGroup()` |
| INV-4 | Group call participant cap = 32 | `chat.gateway.ts` `handleAcceptGroupCall` |
| INV-5 | Group call auto-ends when participant count drops to 1 | `chat.gateway.ts` `handleLeaveGroupCall` |
| INV-6 | Recording media never leaves the device | `CallRecordingCubit` — no upload code path exists |
| INV-7 | REC indicator visible to all participants when any one records | Socket broadcast of `groupCallRecordingStateChanged` |
| INV-8 | All Socket payloads cast via `Map<String,dynamic>.from(data)` after `is! Map` guard | Constitution §IV-A — applies to every new handler |
| INV-9 | LiveKit token issuance verifies caller is a participant of the requested room | `video.service.ts` (small new check) |
