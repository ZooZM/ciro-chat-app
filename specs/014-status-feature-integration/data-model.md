# Phase 1 Data Model: Status Feature Backend & Logic Integration

This document defines the entities introduced or extended by this feature, on
both the backend (MongoDB, via Mongoose schemas) and the frontend (sqflite).
Field names use the casing of their host language (camelCase for
TypeScript/Mongoose, snake_case for sqflite columns), per Constitution VI.

## Backend (MongoDB / Mongoose)

### 1. `Status` (new collection: `statuses`)

| Field | Type | Required | Notes |
|---|---|---|---|
| `_id` | ObjectId | auto | Mongo document ID |
| `authorId` | ObjectId (ref `User`) | yes | Status author |
| `clientStatusId` | string | yes, **unique index** | Client-generated UUID; idempotency key (FR-002, FR-016) |
| `contentType` | enum: `text`, `image`, `video`, `voice` | yes | Matches Flutter `StatusContentType` |
| `textContent` | string | no | Required when `contentType = text` |
| `mediaUrl` | string | no | Relative path on disk, served only via authenticated media route (FR-007); required when `contentType ∈ {image, video, voice}` |
| `backgroundColor` | string | no | Hex color, free-form per existing creation UI |
| `fontStyle` | string | no | Free-form per existing creation UI |
| `musicTrackId` | string | no | Opaque client-supplied reference (research.md §10) |
| `caption` | string | no | Optional caption for media statuses |
| `privacy` | enum: `public`, `private`, `showOnMap` | yes, default `public` | FR-004 |
| `audience` | ObjectId[] (ref `User`) | no | Only meaningful when `privacy = private`; the explicitly-selected mutual contacts (FR-006) |
| `views` | `StatusView[]` (embedded) | default `[]` | See below |
| `reactions` | `StatusReaction[]` (embedded) | default `[]` | See below |
| `createdAt` | Date | auto (`timestamps: true`) | |
| `updatedAt` | Date | auto (`timestamps: true`) | |
| `expiresAt` | Date | yes | `createdAt + 24h`, **TTL index** `{ expiresAt: 1 }, { expireAfterSeconds: 0 }` (FR-008) |

**Indexes**:
- `{ clientStatusId: 1 }` unique - idempotent resubmission (FR-002)
- `{ authorId: 1, createdAt: -1 }` - author's own statuses / feed assembly
- `{ expiresAt: 1 }` TTL, `expireAfterSeconds: 0` - automatic 24h removal (FR-008)
- `{ privacy: 1, authorId: 1 }` - feed query filtering by privacy

**Validation rules**:
- Exactly one of `textContent` (for `contentType = text`) or `mediaUrl` (for
  `image`/`video`/`voice`) must be present, enforced in `CreateStatusDto` /
  service layer.
- `audience` is only persisted/considered when `privacy = private`; ignored
  (cleared) for `public`/`showOnMap`.
- `audience` entries MUST be a subset of the author's mutual contacts at
  write time (FR-005/FR-006); invalid entries are rejected with a 400.
- `privacy: 'showOnMap'` is feed-visible to the author's mutual contacts
  identically to `privacy: 'public'` (FR-004/FR-005); the map channel
  (research.md §9) is an additional surface on top of this, not a
  replacement for it.

**State transitions**: A `Status` has no explicit status/lifecycle field -
its only "transition" is implicit: `active` (now < `expiresAt`) →
*non-existent* (TTL-deleted at `expiresAt`, FR-008). There is no
soft-delete/archived state.

#### 1a. `StatusView` (embedded subdocument, `_id: false`)

| Field | Type | Required | Notes |
|---|---|---|---|
| `userId` | ObjectId (ref `User`) | yes | Viewer identity (FR-009) |
| `viewedAt` | Date | yes | Timestamp of view (FR-009) |

- Uniqueness: at most one `StatusView` per `(status, userId)` - enforced at
  the service layer via `$addToSet`-style upsert (mirrors
  `MessagesRepository.markRead`'s `$addToSet`), so multi-device duplicate
  "viewed" events from the same user (Edge Cases) collapse into one entry
  with the *first* `viewedAt`.

#### 1b. `StatusReaction` (embedded subdocument, `_id: false`)

| Field | Type | Required | Notes |
|---|---|---|---|
| `userId` | ObjectId (ref `User`) | yes | Reactor identity (FR-011) |
| `reaction` | string | yes | Fixed reaction type per Assumptions (e.g., `"heart"`) |
| `createdAt` | Date | yes | |

- Uniqueness: at most one `StatusReaction` per `(status, userId)` - a
  repeated reaction from the same user replaces (does not duplicate) their
  prior reaction, via `$set` on the matched array element (or
  pull-then-push if the reaction value changes).

### 2. `User` (extend existing collection: `users`)

New fields added to `chat-app-backend/src/modules/users/schemas/user.schema.ts`:

| Field | Type | Required | Notes |
|---|---|---|---|
| `syncedContacts` | string[] | no, default `[]` | Normalized phone numbers from the user's most recent `POST /users/sync-contacts` call (FR-005). Full-replace on each sync. |
| `defaultStatusAudience` | ObjectId[] (ref `User`) | no, default `[]` | Most recently selected "Private" status audience (FR-013), pre-fills future Private statuses (FR-017). |

**Derived relationship - "Mutual Contact" (FR-005)**: Not stored; computed
at query time. Users A and B are mutual contacts iff:

```text
B.phoneNumber ∈ A.syncedContacts  AND  A.phoneNumber ∈ B.syncedContacts
```

Used to: (a) determine the recipient set for a `public` status (every
mutual contact of the author), and (b) validate that `audience` entries on a
`private` status are themselves mutual contacts of the author.

**Index addition**: `{ syncedContacts: 1 }` (multikey) to support efficient
"who has my number saved" reverse lookups when assembling a `public` status's
recipient set.

### 3. `Message` (extend existing collection: `messages`)

New optional field added to
`chat-app-backend/src/modules/chat/schemas/message.schema.ts`:

| Field | Type | Required | Notes |
|---|---|---|---|
| `statusRef` | `{ statusId: ObjectId (ref Status); statusAuthorId: ObjectId (ref User); expiresAt: Date }` \| undefined | no | Present only for messages created via FR-012 (status replies). `expiresAt` is copied from the source `Status.expiresAt` at write time so the reply can be cleaned up in alignment with the status's own 24h expiry (research.md §2 note). |

No change to existing `Message` validation/state-transition rules
(Constitution IX) - a status-reply message is a normal `Message` in every
other respect (gets `clientMessageId`, `status` lifecycle, `deliveredTo`/
`readBy`, etc.).

---

## Frontend (sqflite, `lib/features/chat/data/datasources/chat_local_data_source.dart`)

### 4. `statuses` table (extend existing schema)

Existing columns (unchanged): `id`, `author_name`, `author_avatar`,
`timestamp`, `expires_at`, `is_viewed`, `is_mine`, `content_type`,
`text_content`, `media_url`, `background_color`, `font_style`,
`music_track_id`, `caption`, `privacy`.

New columns (additive, via `onUpgrade` migration following the existing
`ALTER TABLE ... ADD COLUMN` pattern):

| Column | Type | Default | Notes |
|---|---|---|---|
| `client_status_id` | TEXT | `''` | Idempotency key generated at creation (FR-002/FR-016); sent as `clientStatusId` to the server |
| `sync_status` | TEXT | `'synced'` | One of `pending` \| `synced` \| `error` - drives the offline queue (FR-016), mirroring chat messages' `pending`/`sent`/`error` |
| `audience_json` | TEXT | `'[]'` | JSON array of selected mutual-contact user IDs, only meaningful when `privacy = 'private'` (FR-017) |
| `author_id` | TEXT | `''` | Server user ID of the author - needed to distinguish "my" statuses across devices and to resolve the 1:1 chat room for replies (FR-012) |

**New index**: `CREATE INDEX IF NOT EXISTS idx_statuses_client_id ON
statuses(client_status_id)` - supports the offline-queue replay lookup
(`WHERE sync_status = 'pending'`) and reconciliation on server ACK (mirrors
`idx_msg_client_id`).

### 5. `status_default_audience` (new lightweight cache, optional)

A small SharedPreferences entry (not a new table - per Constitution III,
"lightweight... user preferences" belong in `SharedPreferences`) storing the
JSON array of user IDs last returned by `GET /status/audience/default`, used
to pre-fill the "Private" selector instantly (FR-017) before/independent of a
network round trip. Refreshed on every successful status post and on app
start.

---

## Entity Relationship Summary

```text
User ──< syncedContacts (string[], normalized phone numbers) ─ (mutual iff bidirectional)
User ──< defaultStatusAudience (ObjectId[] → User) ─ pre-fill for next Private Status

Status }──1 authorId ──1 User
Status ──< views[] (embedded StatusView { userId → User, viewedAt })
Status ──< reactions[] (embedded StatusReaction { userId → User, reaction, createdAt })
Status ──< audience[] (ObjectId[] → User, only when privacy = private)

Message }──1 chatRoomId ──1 ChatRoom
Message }──0..1 statusRef { statusId → Status, statusAuthorId → User, expiresAt }
```
