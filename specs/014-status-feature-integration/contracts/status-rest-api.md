# Contract: Status REST API (`chat-app-backend`)

All routes are under the existing global prefix conventions (no versioned
prefix, matching `/chat`, `/users`, `/map`). All routes require
`@UseGuards(JwtAuthGuard)` (Bearer access token) unless noted. Request/response
bodies are wrapped by the existing `GlobalResponseInterceptor` /
`GlobalExceptionFilter` like every other controller.

## `POST /status/upload`

Create (or idempotently re-acknowledge) a status. Replaces the current
non-functional stub called from
`StatusRemoteDataSourceImpl.uploadStatus()`.

- **Content-Type**: `multipart/form-data` when `contentType ∈ {image, video,
  voice}` (file field `file`, `<= 20MB`, same `FileInterceptor` config as
  `POST /chat/upload`); `application/json` when `contentType = text`.
- **Body fields** (`CreateStatusDto`):
  | Field | Type | Required |
  |---|---|---|
  | `clientStatusId` | string (UUID) | yes |
  | `contentType` | `'text' \| 'image' \| 'video' \| 'voice'` | yes |
  | `textContent` | string | required if `contentType = 'text'` |
  | `backgroundColor` | string | no |
  | `fontStyle` | string | no |
  | `musicTrackId` | string | no |
  | `caption` | string | no |
  | `privacy` | `'public' \| 'private' \| 'showOnMap'` | yes |
  | `audience` | string[] (user IDs) | required if `privacy = 'private'` |
- **Behavior** (FR-002):
  - If a `Status` with this `clientStatusId` already exists for this user,
    return it unchanged (HTTP 200) - no duplicate created.
  - Otherwise create the `Status` (`expiresAt = now + 24h`), persist
    `audience` (validated as a subset of mutual contacts when `privacy =
    'private'`, FR-006), update `User.defaultStatusAudience` when `privacy =
    'private'` (FR-013), and broadcast to permitted recipients (see
    `status-socket-events.md` → `statusReceived`).
- **Response** `201 Created` (or `200 OK` on idempotent replay): the created
  `Status` document (camelCase JSON), including resolved `mediaUrl` as a
  path under `/status/media/...` (see below).
- **Errors**: `400` invalid DTO / `audience` contains a non-mutual contact;
  `413` file too large; `415` unsupported media type.

## `GET /status/feed`

Returns the current set of non-expired statuses the authenticated user is
permitted to see (FR-003), each annotated with whether *this* user has
viewed it (for FR-014/FR-015 client merge logic).

Statuses with `privacy: 'showOnMap'` are included using the same
mutual-contact rule as `privacy: 'public'` (research.md §9); the map-based
view is an additional, separate surface for these statuses, not a
replacement for their feed visibility.

- **Query params**: none (no pagination - bounded by 24h window and contact
  graph size, consistent with existing Updates screen).
- **Response** `200 OK`:
  ```json
  {
    "data": [
      {
        "id": "...",
        "authorId": "...",
        "authorName": "...",
        "authorAvatar": "...",
        "clientStatusId": "...",
        "contentType": "image",
        "mediaUrl": "/status/media/<statusId>/<filename>",
        "caption": "...",
        "backgroundColor": null,
        "fontStyle": null,
        "musicTrackId": null,
        "privacy": "public",
        "createdAt": "2026-06-10T12:00:00.000Z",
        "expiresAt": "2026-06-11T12:00:00.000Z",
        "isViewed": false,
        "isMine": false
      }
    ]
  }
  ```
- Includes the caller's own non-expired statuses (`isMine: true`) so the
  client's `getMyStatus()` query continues to work from the same merged
  table (FR-014).

## `GET /status/:id/viewers`

Author-only: list of viewers + timestamps (FR-009).

- **Authorization**: 403 if `req.user.userId !== status.authorId`.
- **Response** `200 OK`:
  ```json
  {
    "data": [
      { "userId": "...", "name": "...", "avatarUrl": "...", "viewedAt": "2026-06-10T12:05:00.000Z" }
    ]
  }
  ```

## `POST /status/:id/react`

Send a reaction (FR-011).

- **Body** (`ReactStatusDto`): `{ "reaction": "heart" }` (single fixed
  reaction type per Assumptions).
- **Behavior**: Upserts the caller's `StatusReaction` (replacing any prior
  reaction by the same user on this status). Emits `statusReacted` to the
  status author if online (FR-010) and within FR-006/FR-005 visibility
  rules (a viewer can only react to a status they're permitted to view -
  enforced the same way as `GET /status/feed` filtering).
- **Response** `200 OK`: `{ "data": { "statusId": "...", "reaction": "heart" } }`
- **Errors**: `403` if the caller is not permitted to view this status
  (FR-006); `404` if the status has expired/doesn't exist.

## `POST /status/:id/reply`

Send a text reply, delivered as a regular 1:1 chat message (FR-012).

- **Body** (`ReplyStatusDto`): `{ "message": "..." }`
- **Behavior**: Resolves (or creates) the 1:1 `ChatRoom` between caller and
  status author (reuses `ChatService.resolvePrivateRoom`, same as `POST
  /chat/private/resolve`), then calls `ChatService.saveMessage(...)` with
  `messageType: 'text'`, `content: message`, and `statusRef: { statusId,
  statusAuthorId, expiresAt: status.expiresAt }`. The resulting message is
  delivered via the normal `newMessage` socket event (Constitution IX) -
  **no separate `statusReplied` event** is emitted.
- **Response** `201 Created`: the created `Message` document, including
  `roomId` and `statusRef`, so the client can route it into the existing
  chat send/optimistic-update flow per FR-018.
- **Errors**: `403` if the caller is not permitted to view this status;
  `404` if the status has expired/doesn't exist.

## `GET /status/audience/default`

Returns the caller's persisted default "Private" audience (FR-013), for
pre-filling the "Private (select contacts)" picker (FR-017).

- **Response** `200 OK`:
  ```json
  { "data": [ { "userId": "...", "name": "...", "phoneNumber": "...", "avatarUrl": "..." } ] }
  ```
- Entries that are no longer mutual contacts are silently omitted (per
  Assumptions - "no error is raised").

## `GET /status/media/:statusId/:filename`

Authenticated, permission-checked media retrieval (FR-007). Replaces direct
`/uploads/<uuid>` access for status media.

- **Authorization**: `JwtAuthGuard` + per-request check that
  `req.user.userId` is permitted to view `Status(:statusId)` under
  FR-004/FR-005/FR-006 (author, mutual contact for `public`, selected
  audience member for `private`, or - for `showOnMap` - permitted via the
  existing map location-sharing check, research.md §9). `404` (not `403`,
  to avoid confirming existence to unauthorized users) if the status has
  expired or the caller isn't permitted.
- **Response** `200 OK`: the file stream (`Content-Type` set from stored
  `mimeType`/extension), `Cache-Control: private, max-age=...` (short TTL,
  since access is re-validated per request rather than via a long-lived
  signed URL).

## `POST /users/sync-contacts` (existing endpoint, extended behavior)

No request/response shape change. Newly, on each call the backend also
`$set`s the caller's `User.syncedContacts` to the submitted `phoneNumbers`
array (FR-005), enabling mutual-contact evaluation. The Flutter
`ContactsService.syncContacts()` call site requires no change - it already
calls this endpoint on contact sync.
