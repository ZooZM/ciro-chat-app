# Data Model: Optimize Chat Lifecycle (Expanded)

**Date**: April 27, 2026

## Entity Changes

### Message (Extended)

| Field | Type | Change | Notes |
|-------|------|--------|-------|
| type | MessageType | **MODIFY** | Add `video` variant |
| metadata | Map<String, dynamic>? | **EXTEND** | Add `waveformSamples`, `thumbnailUrl` keys |

**New MessageType variant**:
```
video → 'video' (wire format)
```

**New metadata keys by type**:
| MessageType | New Key | Type | Description |
|-------------|---------|------|-------------|
| voiceNote | waveformSamples | List<double> | Cached waveform data (100-200 samples) |
| video | duration | int | Duration in seconds |
| video | mimeType | String | e.g. "video/mp4" |
| video | thumbnailUrl | String | CDN path to generated thumbnail |

### BlockedUser (New — Backend Only)

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

### Message Status (Resend Flow)

```
error → [user taps resend] → pending → [socket emit] → sent → delivered → read
                                          ↓ (failure)
                                        error (user can retry again)
```

### Block State

```
unblocked → [POST /chat/block/:id] → blocked
blocked → [DELETE /chat/block/:id] → unblocked
```

## SQLite Schema Changes

No new tables required. Existing `messages` table `metadata` column stores new keys as JSON.

## Backend Schema Changes

### message.schema.ts

Add to `MessageType` enum:
```
VIDEO = 'video'
```

### user.schema.ts (or users collection)

Add field:
```
blockedUsers: [{ type: Schema.Types.ObjectId, ref: 'User', default: [] }]
```
