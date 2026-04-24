# Data Model: Optimize Chat Lifecycle

**Branch**: `003-optimize-chat-lifecycle` | **Date**: 2026-04-25

## Entities

### 1. Message (Flutter: `lib/features/chat/domain/entities/message.dart`)

| Field | Type | SQLite Column | Notes |
|-------|------|---------------|-------|
| `id` | `String` | `id TEXT PK` | MongoDB `_id` |
| `clientMessageId` | `String` | `client_message_id TEXT` | Client-generated UUID for idempotency |
| `roomId` | `String` | `room_id TEXT` | FK to rooms.id |
| `senderId` | `String` | `sender_id TEXT` | MongoDB User `_id`. System messages use sentinel `000000000000000000000000` |
| `text` | `String` | `text TEXT` | Message body / event text / caption |
| `timestamp` | `DateTime` | `timestamp INTEGER` | Millis since epoch |
| `status` | `MessageStatus` | `status TEXT` | `pending`, `sent`, `delivered`, `read`, `error` |
| `type` | `MessageType` | `type TEXT DEFAULT 'text'` | See MessageType enum below |
| `fileUrl` | `String?` | `file_url TEXT` | CDN-relative path from `/chat/upload` |
| `metadata` | `Map<String,dynamic>?` | `metadata TEXT` | JSON blob — keys vary by type |

#### MessageType Enum (Flutter)

| Value | Wire String | Backend Enum | Usage |
|-------|-------------|--------------|-------|
| `text` | `'text'` | `TEXT` | Default text messages |
| `image` | `'image'` | `IMAGE` | Photo messages (Gallery/Camera) |
| `file` | `'file'` / `'document'` | `FILE` | Document/file messages |
| `voiceNote` | `'voice_note'` | `VOICE_NOTE` | Recorded voice messages |
| `contact` | `'contact'` | `CONTACT` | Shared contact cards |
| **`system`** | **`'system'`** | **`SYSTEM`** | **[NEW] Group event messages** |
| **`location`** | **`'location'`** | **`LOCATION`** | **[NEW] Map location messages** |
| **`audio`** | **`'audio'`** | **`AUDIO`** | **[NEW] Audio file messages** |
| **`poll`** | **`'poll'`** | **`POLL`** | **[NEW] Poll messages (group-only)** |
| **`event`** | **`'event'`** | **`EVENT`** | **[NEW] Calendar event messages** |

#### Metadata Shapes by Type

```text
image:      { mimeType: String }
file:       { fileName: String, fileSize: int, mimeType: String }
voiceNote:  { duration: int (seconds), mimeType: String }
contact:    { contactName: String, contactPhone: String }
system:     (no metadata — event text in `content`)
location:   { latitude: double, longitude: double, address: String }
audio:      { duration: int (seconds), mimeType: String, fileName: String }
poll:       { question: String, options: List<String>, votes: Map<String, List<String>> }
event:      { title: String, dateTime: String (ISO8601), description: String }
```

#### MessageStatus Enum

| Value | Icon | Description |
|-------|------|-------------|
| `pending` | Timer ⏳ | Saved locally, not yet ACK'd |
| `sent` | Single tick ✓ | Server ACK'd |
| `delivered` | Double tick ✓✓ | Recipient received |
| `read` | Blue ticks ✓✓ | Recipient opened chat |
| `error` | Error ❌ | Failed to send |

---

### 2. ChatSession (Flutter: `lib/features/chat/domain/entities/chat_session.dart`)

| Field | Type | SQLite Column | Notes |
|-------|------|---------------|-------|
| `id` | `String` | `id TEXT PK` | MongoDB room `_id` |
| `name` | `String` | `name TEXT` | Display name (other user's phone or group name) |
| `lastMessage` | `String` | `lastMessage TEXT` | Preview text for inbox |
| `timestamp` | `DateTime` | `timestamp TEXT` | ISO8601 — last activity |
| `unreadCount` | `int` | `unreadCount INTEGER` | Badge count |
| `isOnline` | `bool` | `isOnline INTEGER` | 0/1 — P2P only |
| `avatarUrl` | `String` | `avatarUrl TEXT` | Profile image URL |
| `phoneNumber` | `String` | `phoneNumber TEXT` | Other user's phone (P2P) |
| `lastMessageSenderId` | `String` | `lastMessageSenderId TEXT` | For "You:" prefix |
| `lastMessageStatus` | `MessageStatus` | `lastMessageStatus TEXT` | Status ticks on inbox |
| `type` | `ChatRoomType` | `type TEXT DEFAULT 'PRIVATE'` | `PRIVATE` or `GROUP` |
| `participants` | `List<String>` | `participants TEXT DEFAULT '[]'` | JSON-encoded phone list |
| `admins` | `List<String>` | `admins TEXT DEFAULT '[]'` | JSON-encoded admin phone list |
| `contactUserId` | `String` | *(not persisted)* | Transient — JIT flow only |

#### ChatRoomType Enum

| Value | Description |
|-------|-------------|
| `PRIVATE` | 1-on-1 P2P chat |
| `GROUP` | Multi-participant group chat |

---

### 3. Backend: MessageType (NestJS: `message.schema.ts`)

Current:
```typescript
export enum MessageType {
  TEXT       = 'text',
  IMAGE      = 'image',
  FILE       = 'file',
  CONTACT    = 'contact',
  VOICE_NOTE = 'voice_note',
  SYSTEM     = 'system',
}
```

**After this feature:**
```typescript
export enum MessageType {
  TEXT       = 'text',
  IMAGE      = 'image',
  FILE       = 'file',
  CONTACT    = 'contact',
  VOICE_NOTE = 'voice_note',
  SYSTEM     = 'system',
  LOCATION   = 'location',   // [NEW]
  AUDIO      = 'audio',      // [NEW]
  POLL       = 'poll',       // [NEW]
  EVENT      = 'event',      // [NEW]
}
```

### 4. Backend: MessageMetadata (NestJS: `message.schema.ts`)

**After this feature:**
```typescript
export class MessageMetadata {
  // Existing
  fileName?:     string;
  fileSize?:     number;
  mimeType?:     string;
  duration?:     number;
  contactName?:  string;
  contactPhone?: string;
  contactEmail?: string;
  // [NEW] Location
  latitude?:     number;
  longitude?:    number;
  address?:      string;
  // [NEW] Poll
  question?:     string;
  options?:      string[];
  votes?:        Record<string, string[]>; // optionIndex → userId[]
  // [NEW] Event
  title?:        string;
  dateTime?:     string; // ISO8601
  description?:  string;
}
```

## State Transitions

### Message Lifecycle
```
┌────────┐   socket ACK   ┌──────┐   recipient online   ┌───────────┐   recipient opens   ┌──────┐
│PENDING │ ──────────────► │ SENT │ ───────────────────► │ DELIVERED │ ──────────────────► │ READ │
└────────┘                 └──────┘                      └───────────┘                     └──────┘
     │                                                                                         
     │  send failure                                                                          
     ▼                                                                                        
 ┌───────┐                                                                                    
 │ ERROR │                                                                                    
 └───────┘                                                                                    
```

### WebSocket Lifecycle
```
┌──────────────┐              ┌────────────┐              ┌───────────┐
│ DISCONNECTED │ ────────────►│ CONNECTING │ ────────────►│ CONNECTED │
└──────────────┘              └────────────┘              └───────────┘
       ▲                                                       │
       │                      ┌──────────────┐                 │
       │◄─────────────────────│ RECONNECTING │◄────────────────┘
       │                      └──────────────┘           (connection drop)
       │
  ┌──────────┐
  │ TEARDOWN │  (logout)
  └──────────┘
```

## Relationships

```
ChatSession (1) ──── has many ──── (N) Message
ChatSession.participants[] ──── references ──── User.phoneNumber
ChatSession.admins[] ──── references ──── User.phoneNumber (subset of participants)
Message.senderId ──── references ──── User._id (or sentinel for system)
Message.roomId ──── references ──── ChatSession.id
```

## Validation Rules

1. `Message.clientMessageId` MUST be a valid UUID v4 generated by the client
2. `Message.senderId` for `system` type MUST be sentinel `000000000000000000000000`
3. `ChatSession.type` MUST be `PRIVATE` or `GROUP` — default `PRIVATE`
4. Poll messages MUST only be created in `GROUP` chat rooms
5. Location messages MUST include `metadata.latitude` and `metadata.longitude`
6. Audio messages MUST include `metadata.duration` and `metadata.mimeType`
7. Event messages MUST include `metadata.title` and `metadata.dateTime`
