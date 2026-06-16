# Contract: Status Socket.IO Events (`ChatGateway`)

All events below are added to the existing `ChatGateway`
(`chat-app-backend/src/modules/chat/chat.gateway.ts`) on the default
namespace, using the same `AuthenticatedSocket` (`client.user.userId`) and
`activeSockets` map as existing chat/call events. Per Constitution IV-A, the
Flutter side MUST validate every incoming payload with
`if (data == null || data is! Map) return;` then
`Map<String, dynamic>.from(data)` before use.

## `uploadStatus` (client → server)

- **Replaces**: the current fire-and-forget emit in
  `StatusRemoteDataSourceImpl.uploadStatus()` for `text` statuses (media
  statuses use `POST /status/upload` instead, per existing multipart logic).
- **Payload**: same shape as `CreateStatusDto` (see
  `status-rest-api.md` → `POST /status/upload`), JSON-serializable
  (`StatusModel.toMap()`/`toJson()`).
- **Server behavior**: identical to `POST /status/upload` (idempotent on
  `clientStatusId`, FR-002) - the gateway handler delegates to
  `StatusService.createStatus(...)`.
- **Acknowledgement to sender**: emits `statusUploaded` to the originating
  socket:
  ```json
  { "clientStatusId": "...", "id": "...", "createdAt": "..." }
  ```
  (mirrors `messageSent` ACK pattern, Constitution IX-B) so the client can
  promote the local row from `sync_status = 'pending'` → `'synced'`
  (FR-016).
- **Fan-out**: for each currently-connected, permitted recipient (mutual
  contacts for `public`, `audience` members for `private` - FR-003), emit
  `statusReceived` (see below). Recipients not connected receive the new
  status on their next `GET /status/feed` call (FR-014).

## `statusReceived` (server → client)

- **Direction**: server pushes to each permitted, online recipient's
  personal room (`user:<userId>`, already joined on connect per
  `ChatGateway.handleConnection`).
- **Payload**: the created `Status` document (same shape as one element of
  `GET /status/feed`'s `data` array), with `isViewed: false`, `isMine:
  false`.
- **Existing client handling**: `SocketService.onStatusReceived` →
  `StatusRemoteDataSourceImpl` → `StatusRepositoryImpl.statusStream` →
  `StatusCubit._listenToStatusStream()` already exists and inserts the new
  status into `recentStatuses` (FR-003/SC-001). No change required beyond
  ensuring the payload now contains real fields (previously this path was
  unused since nothing emitted `statusReceived`).

## `statusViewed` (client → server)

- **Existing emit**: `SocketService.notifyStatusViewed(statusId)` already
  emits `{ "statusId": "..." }` - **no payload change**.
- **Server behavior** (new handler): delegates to
  `StatusService.recordView(statusId, viewerId)` - upserts a `StatusView`
  subdocument (dedup by `userId`, FR-009; multi-device race in Edge Cases
  resolved by `$addToSet`-equivalent upsert keeping the first `viewedAt`).
- **Fan-out**: if the status author is online, emit `statusViewerAdded` to
  them (FR-010, SC-004):
  ```json
  { "statusId": "...", "viewer": { "userId": "...", "name": "...", "avatarUrl": "..." }, "viewedAt": "..." }
  ```

## `statusReacted` (server → client)

- **Direction**: server → status author's personal room, only if the author
  is online (FR-010, SC-005).
- **Trigger**: emitted by `StatusService` after `POST /status/:id/react`
  succeeds (REST, not a new socket *input* event - reactions are submitted
  via REST per `status-rest-api.md`, matching the existing
  `StatusRepositoryImpl.reactToStatus` Dio call).
- **Payload**:
  ```json
  { "statusId": "...", "reaction": "heart", "from": { "userId": "...", "name": "...", "avatarUrl": "..." }, "createdAt": "..." }
  ```
- **Client handling** (new): `SocketService` gains a typed
  `onStatusReacted` callback, wired through `StatusRemoteDataSource` →
  `StatusRepository` → `StatusCubit`, to surface a real-time badge/update on
  the author's own status (no UI change required by this feature beyond
  whatever the existing viewer-list UI already renders for reactions, per
  SC-007 - if no such UI exists yet, this event is consumed but not yet
  displayed, which is acceptable since FR-010 only requires the
  notification to be *delivered*).

## Status replies - no new socket event

Per FR-012/research.md §6, a status reply is created via `POST
/status/:id/reply` and delivered through the **existing** `newMessage`
socket event (with the new `statusRef` field populated), not a bespoke
`statusReplied` event. `ChatGateway.handleSendMessage`'s broadcast path is
unchanged; `StatusService` only originates the `Message` via
`ChatService.saveMessage`.

## Summary table

| Event | Direction | New / Existing | Notes |
|---|---|---|---|
| `uploadStatus` | client → server | existing emit, **new handler** | idempotent on `clientStatusId` |
| `statusUploaded` | server → sender | **new** | ACK for offline-queue promotion (FR-016) |
| `statusReceived` | server → recipients | existing emit point (client), **new server emitter** | FR-003 |
| `statusViewed` | client → server | existing emit, **new handler** | FR-009/FR-015 |
| `statusViewerAdded` | server → author | **new** | FR-010/SC-004 |
| `statusReacted` | server → author | **new** | FR-010/SC-005, reaction itself sent via REST |
| (reply) `newMessage` | server → recipient | existing, payload extended with `statusRef` | FR-012 |
