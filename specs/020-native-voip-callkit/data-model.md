# Phase 1 Data Model: Native VoIP CallKit Integration

## Entity: CallHistoryRecord (domain entity + sqflite row)

Represents one completed/attempted call surfaced in the in-app Calls screen.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (PK) | Local UUID; also the CallKit `callId` for 1:1 calls (correlation key, R10). |
| `contactUserId` | `String` | Remote user id (1:1) or chat room id (group). |
| `contactName` | `String` | Display name; falls back to "Unknown". |
| `avatarUrl` | `String?` | Optional; resolved via `UrlUtils.resolveMediaUrl` when rendering (§VIII-A). |
| `avatarColorSeed` | `int` | Deterministic color seed for the initials avatar (derived from name/id). |
| `direction` | `CallDirection` enum | `incoming` \| `outgoing`. |
| `outcome` | `CallOutcome` enum | `answered` \| `missed` \| `declined`. |
| `callType` | `CallType` enum | `voice` \| `video`. |
| `isGroup` | `bool` | True for group calls (in-app presentation). |
| `startedAt` | `int` (epoch ms) | Sort key (DESC). |
| `durationSeconds` | `int` | 0 for missed/declined. |

### Enums

```dart
enum CallDirection { incoming, outgoing }
enum CallOutcome { answered, missed, declined }
enum CallType { voice, video }
```

### Derived UI fields (computed, not stored)

- `initials`: first letters of `contactName` words (max 2).
- `isMissed`: `outcome == missed` → red name + red direction arrow (FR-VoIP-04).
- `directionIcon`: `incoming+answered → ↙`, `outgoing+answered → ↗`, `missed → ↙ (red)`, `declined → ↗/↙ (red)`.
- `typeIcon`: `video → Icons.videocam`, `voice → Icons.call` (trailing).
- `subtitleTime`: relative label — "Today 1:10 AM", "Yesterday 2:12 PM", else date.

### Validation rules

- `id`, `contactUserId`, `contactName` non-empty.
- `outcome == answered` ⇒ `durationSeconds >= 0`; `outcome != answered` ⇒ `durationSeconds == 0`.
- A row is written exactly once per call at its terminal transition (idempotent on `id` via `INSERT OR REPLACE`, mirroring §III dedup).

## sqflite schema (`call_history` table)

```sql
CREATE TABLE IF NOT EXISTS call_history (
  id TEXT PRIMARY KEY,
  contact_user_id TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  avatar_url TEXT,
  avatar_color_seed INTEGER NOT NULL DEFAULT 0,
  direction TEXT NOT NULL,        -- 'incoming' | 'outgoing'
  outcome TEXT NOT NULL,          -- 'answered' | 'missed' | 'declined'
  call_type TEXT NOT NULL,        -- 'voice' | 'video'
  is_group INTEGER NOT NULL DEFAULT 0,
  started_at INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_call_history_started_at ON call_history(started_at DESC);
```

> Added as a new table in the existing app database via the standard migration/`onCreate` path used for other tables (Constitution §III — sqflite is the single UI source).

## Transient state: AudioRoute (in-call, not persisted)

Held in `AudioRouteService` and mirrored onto `CallActive` for rendering.

| Field | Type | Notes |
|---|---|---|
| `activeRoute` | `AudioOutputRoute` | `earpiece` \| `speaker` \| `bluetooth`. |
| `availableRoutes` | `List<AudioOutputDevice>` | From `Hardware.instance.audioOutputs`. |
| `bluetoothName` | `String?` | Display name of connected BT device, if any. |

```dart
enum AudioOutputRoute { earpiece, speaker, bluetooth }
```

- Speaker button icon: `earpiece → Icons.volume_up_outlined (off)`, `speaker → Icons.volume_up (on)`, `bluetooth → Icons.bluetooth_audio` (FR-VoIP-08).

## State transitions → history outcome mapping

| `CallCubit` terminal path | direction | outcome |
|---|---|---|
| Outgoing answered then ended | outgoing | answered |
| Outgoing rejected by remote (`onCallRejected`) | outgoing | declined |
| Outgoing no-answer / cancelled before connect | outgoing | missed |
| Incoming answered then ended | incoming | answered |
| Incoming declined locally (`rejectCall`/`declineGroupCall`) | incoming | declined |
| Incoming timed out / not answered (`CallEnded(reason:'missed')`) | incoming | missed |

`durationSeconds` = `endedAt - connectedAt` for `answered`, else 0.
