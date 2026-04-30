# Data Model: Optimize Chat Lifecycle (P2P Focus Update)

**Date**: April 30, 2026 (Updated)

## Entity Changes

### Message (Extended)

| Field | Type | Change | Notes |
|-------|------|--------|-------|
| type | MessageType | **MODIFY** | Add `video` variant |
| isDeleted | bool | **NEW** | Default `false`. When `true`, bubble shows "🚫 This message was deleted" |
| metadata | Map<String, dynamic>? | **EXTEND** | Add `waveformSamples`, `thumbnailUrl`, poll/event keys |

**New MessageType variant**:
```
video → 'video' (wire format)
```

**New metadata keys by type**:
| MessageType | New Key | Type | Description |
|-------------|---------|------|-------------|
| voiceNote | waveformSamples | List<double> | 50 cached waveform samples (extracted at record time) |
| video | duration | int | Duration in seconds |
| video | mimeType | String | e.g. "video/mp4" |
| video | thumbnailUrl | String | CDN path to generated thumbnail |
| poll | question | String | Poll question text |
| poll | options | List<Map> | `[{text, votes: int}]` |
| poll | allowMultiple | bool | Whether multi-select is allowed |
| event | title | String | Event name |
| event | description | String | Event description (max 2048 chars) |
| event | startDate | String | ISO 8601 start date-time |
| event | endDate | String? | ISO 8601 end date-time (optional) |
| event | location | String? | Optional location |
| event | reminder | String? | Reminder setting |

### ChatSession / rooms (Extended)

| Field | Type | Change | Notes |
|-------|------|--------|-------|
| lastMessageId | String | **NEW** | SQLite column `last_message_id TEXT DEFAULT ''`. Tracks the actual latest message for scoped status updates. |
| lastMessageSenderId | String | **NEW** | SQLite column `last_message_sender_id TEXT DEFAULT ''`. Used by `ChatTileWidget` to determine tick icon visibility. |

### BlockedUser (Existing — Backend Only)

Stored as an array field on the existing User schema (not a separate collection).

| Field | Type | Location | Notes |
|-------|------|----------|-------|
| blockedUsers | ObjectId[] | User schema | Array of blocked user IDs |

**Relationships**:
- User → blockedUsers: One-to-many (self-referential)
- Block check performed in socket gateway before message delivery

### SearchResult (Frontend — Transient)

Not persisted. Returned by `ChatLocalDataSource.searchMessages()`.

| Field | Type | Notes |
|-------|------|-------|
| message | Message | The matching message entity |
| matchIndex | int | Index position in the full message list (for scroll-to) |

## State Transitions

### Message Status (Monotonic Promotion — FR-019)

```
pending (rank 0) → sent (rank 1) → delivered (rank 2) → read (rank 3)
                                                          ↑
                                              NEVER goes backward

error → [user taps resend] → pending → sent → delivered → read
                                ↓ (failure)
                              error (user can retry again)
```

**Status rank guard**: `_statusRank(status) → int`
- `pending = 0`, `sent = 1`, `delivered = 2`, `read = 3`
- Update is rejected if `incomingRank <= currentRank`

### Message Deletion States (FR-022)

```
normal → [Delete for Me] → removed from local SQLite (hard delete)
normal → [Delete for Everyone] → isDeleted=true (soft delete, all participants)
```

- "Delete for Everyone" only available if:
  - `message.senderId == currentUserId`
  - `DateTime.now() - message.createdAt < 1 hour`

### Block State

```
unblocked → [POST /chat/block/:id] → blocked
blocked → [DELETE /chat/block/:id] → unblocked
```

## SQLite Schema Changes

### messages table — Add `is_deleted` column

```sql
ALTER TABLE messages ADD COLUMN is_deleted INTEGER DEFAULT 0;
```

### rooms table — Add tracking columns

```sql
ALTER TABLE rooms ADD COLUMN last_message_id TEXT DEFAULT '';
ALTER TABLE rooms ADD COLUMN last_message_sender_id TEXT DEFAULT '';
```

### Migration strategy

Both `ALTER TABLE` statements are idempotent-safe — wrap in try/catch in `initDB()` to handle already-migrated databases.

## Backend Schema Changes

### message.schema.ts

Add to `MessageType` enum:
```
VIDEO = 'video'
```

Add field:
```
isDeleted: { type: Boolean, default: false }
```

### user.schema.ts (or users collection)

Add field:
```
blockedUsers: [{ type: Schema.Types.ObjectId, ref: 'User', default: [] }]
```

## Pagination Model (FR-018)

### Query Contract

```sql
-- Initial load (newest 30 messages)
SELECT * FROM messages WHERE room_id = ? ORDER BY timestamp DESC LIMIT 30 OFFSET 0;

-- Load more (next 30 older messages)
SELECT * FROM messages WHERE room_id = ? ORDER BY timestamp DESC LIMIT 30 OFFSET 30;
```

### Cubit Pagination State

| Field | Type | Description |
|-------|------|-------------|
| _messageOffset | int | Current offset, starts at 0 |
| _hasMoreMessages | bool | False when a batch returns <30 items |
| _isLoadingMore | bool | Prevents concurrent load requests |
