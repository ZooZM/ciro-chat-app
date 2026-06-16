# Phase 0 Research: Status Feature Backend & Logic Integration

All items below were resolved during `/speckit-clarify` (see spec.md
`## Clarifications`) or by inspecting the existing codebase. No
`NEEDS CLARIFICATION` markers remain in the Technical Context.

## 1. Real-time status event placement

- **Decision**: Add the status-related Socket.IO events
  (`uploadStatus`, `statusViewed`, `statusReceived`, plus new
  `statusReacted`, `statusReplied`, `statusViewerAdded`) as
  `@SubscribeMessage` handlers on the existing `ChatGateway`
  (`chat-app-backend/src/modules/chat/chat.gateway.ts`), backed by a new
  `StatusService` injected into the gateway. `StatusModule` is imported into
  `ChatModule` (and `ChatModule` is imported into `StatusModule` for
  FR-012 reply delivery via `ChatService`/`MessagesRepository`) using Nest's
  `forwardRef()` to break the resulting circular dependency.
- **Rationale**: `ChatGateway` already owns the authenticated
  `activeSockets` map, the `AuthenticatedSocket` JWT-verified connection
  lifecycle, and the room-join/presence logic (Constitution IV/IV-B).
  Spinning up a second `@WebSocketGateway()` would either duplicate that
  authentication/connection bookkeeping or require fragile coordination
  between two independently-instantiated gateways on the same namespace.
  Reusing one gateway keeps "one singleton SocketService on the client,
  one authenticated connection per user on the server" intact.
- **Alternatives considered**:
  - *New `StatusGateway` with its own namespace (`/status`)* - rejected:
    the Flutter `SocketService` is a single singleton connected to the
    default namespace (Constitution IV); adding a second namespace means a
    second connection/auth handshake and a second presence/online model,
    which conflicts with IV-B (single source of truth for `isOnline`).
  - *New `StatusGateway` on the default namespace* - rejected: NestJS
    invokes `OnGatewayConnection.handleConnection` for every gateway bound
    to a namespace, so JWT verification and `activeSockets` bookkeeping
    would need to be duplicated or extracted into a shared service anyway -
    more moving parts than extending `ChatGateway` directly.

## 2. 24-hour expiry mechanism (FR-008)

- **Decision**: Give the new `Status` Mongo schema a `expiresAt: Date`
  field with a TTL index (`expireAfterSeconds: 0`), set to
  `createdAt + 24h` at creation time. Views and reactions are stored as
  embedded subdocument arrays on the `Status` document itself, so MongoDB's
  TTL deletion removes the status, its views, and its reactions atomically
  in one operation.
- **Rationale**: FR-008 requires the status *and* its views/reactions/replies
  to become inaccessible "exactly 24 hours" after creation, with SC-002
  requiring this to hold within ±1 minute for 100% of statuses, without a
  separate cron/cleanup job. A TTL index is the standard MongoDB mechanism
  for this and matches the "ephemeral" nature already assumed by the
  existing client-side 5-minute expiry-purge timer in `StatusCubit`.
- **Alternatives considered**:
  - *Application-level cron job that deletes expired statuses* - rejected:
    adds an extra scheduled job/dependency (the project already has BullMQ
    available, but a TTL index is zero-maintenance and guaranteed by the DB
    engine) and risks drift from the ±1 minute SC-002 target under load.
  - *Separate `StatusView`/`StatusReaction` collections with their own TTL
    indexes* - rejected for v1: adds write amplification (one extra insert
    per view, which can be very high-frequency) and a second TTL index to
    keep in sync with the parent `Status`'s `expiresAt`. Embedded
    subdocuments are simpler and sufficient at this feature's scale; can be
    revisited if view volume becomes a hot-document/document-size problem.
- **Note**: Status replies (FR-012) are stored as regular chat `Message`
  documents (see item 6) and are **not** covered by the `Status` TTL index.
  Their removal at expiry (per FR-008/Assumptions) requires a small
  TTL-aligned cleanup (e.g., a Mongo TTL index on the `Message.statusRef`
  subdocument's `expiresAt`, copied from the parent status at write time) -
  documented as a task for `/speckit-tasks`, not a new architectural
  decision.

## 3. Status media access control (FR-007)

- **Decision**: Serve status media (image/video/voice) via a new
  authenticated REST route (e.g., `GET /status/media/:statusId/:filename`)
  guarded by `JwtAuthGuard`, which re-checks the requesting user's
  permission to view that status (author, mutual-contact "Public", or
  selected "Private" audience member - FR-004/FR-005/FR-006) on every
  request before streaming the file from disk. The Flutter client attaches
  its existing Bearer access token as an HTTP header when requesting status
  media (`CachedNetworkImage`/`DefaultCacheManager().getSingleFile` both
  accept custom headers).
- **Rationale**: The app already has a working, refreshable JWT
  access-token lifecycle (Constitution IV-C / `TokenRefreshService`) used
  for every other authenticated REST call. Reusing it for media requests
  means "expiring" access (per FR-007's "signed/expiring or authenticated"
  wording) falls out for free - an expired access token simply 401s like
  any other endpoint and is refreshed by the existing interceptor - and the
  permission check is always evaluated against live data (so a status that
  becomes inaccessible via a changed audience or 24h TTL is immediately
  reflected, satisfying SC-003's "all retrieval paths" requirement)
  without any separate signing/verification infrastructure.
- **Alternatives considered**:
  - *Signed/expiring URLs (HMAC query-param tokens with short TTL)* -
    rejected: requires new signing-secret management and clock-skew
    handling, and still needs the same live permission re-check at
    verification time to satisfy SC-003 (a stolen-but-unexpired signed URL
    would otherwise leak Private media) - so it adds infrastructure without
    removing the need for the per-request check above.
  - *Reuse existing unauthenticated `/uploads/<uuid>` static serving* -
    explicitly rejected by Q2 in `/speckit-clarify` (FR-007).

## 4. Mutual-contact persistence model (FR-005)

- **Decision**: Add `syncedContacts: string[]` (normalized phone numbers) to
  the `User` schema (`chat-app-backend/src/modules/users/schemas/user.schema.ts`).
  `UsersService.syncContacts()` (currently a stateless lookup) is extended to
  also `$set` the caller's `syncedContacts` to the submitted phone-number
  list (idempotent full replace, matching how the device's contact list is
  itself a full snapshot). Mutual-contact evaluation for user A viewing user
  B's "Public" status becomes: `B.phoneNumber ∈ A.syncedContacts AND
  A.phoneNumber ∈ B.syncedContacts`, computed in `UsersRepository`/
  `StatusRepository` query helpers.
- **Rationale**: This is a 1:1, append/replace relationship naturally owned
  by the `User` document - no new collection or join is needed, and it
  reuses the exact data already submitted by the existing
  `POST /users/sync-contacts` endpoint (`SyncContactsDto`), so the Flutter
  `ContactsService.syncContacts()` requires **no changes** to keep this data
  fresh.
- **Alternatives considered**:
  - *New `Contact` collection (`{ ownerId, phoneNumber }` per row)* -
    rejected: enables richer per-contact metadata later, but for a simple
    "is this phone number in my synced list" check, an array field on
    `User` with an index is simpler, requires fewer queries (no join), and
    matches the existing `blockedUsers: ObjectId[]` pattern already on
    `User`.

## 5. Persisted default "Private" audience (FR-013/FR-017)

- **Decision**: Add `defaultStatusAudience: Types.ObjectId[]` (ref `User`)
  to the `User` schema. `POST /status/upload` (and the `uploadStatus` socket
  event) accept an `audience: string[]` of user IDs when `privacy ===
  'private'`; on success, the service `$set`s
  `defaultStatusAudience = audience` for the author. A new
  `GET /status/audience/default` returns the persisted list (resolved to
  basic contact info) so the client can pre-fill the "Private" selector
  (FR-017) without re-deriving it from local cache.
- **Rationale**: Same reasoning as item 4 - a single small array on `User`
  is the minimal model satisfying "persist the most recently selected
  Private audience and pre-fill it" with no extra collection.
- **Alternatives considered**:
  - *Derive default audience client-side from local SQLite history of past
    Private statuses* - rejected: the spec (Q5) explicitly calls for
    server-persisted state so the default follows the user across devices
    and survives app reinstall/local-cache loss, consistent with
    "Updates flow merged correctly with anything already cached" (FR-014).

## 6. Status replies as chat messages (FR-012)

- **Decision**: Extend `Message` schema
  (`chat-app-backend/src/modules/chat/schemas/message.schema.ts`) with an
  optional `statusRef?: { statusId: Types.ObjectId; authorId: Types.ObjectId }`
  field. `POST /status/:id/reply` (replacing the current stub in
  `status_remote_data_source.dart`) resolves/creates the 1:1 chat room
  between viewer and author (reusing `ChatService.resolvePrivateRoom`,
  the same logic backing `POST /chat/private/resolve`), then calls
  `ChatService.saveMessage(...)` with `messageType: TEXT`, the reply text as
  `content`, and `statusRef` set - so it flows through the exact same
  persistence, delivery (`newMessage` socket event), and
  delivered/read-receipt machinery as any other chat message (Constitution
  IX).
- **Rationale**: Directly implements Q3's resolution ("Real chat message").
  Reusing `ChatService.saveMessage` means status replies automatically get
  `clientMessageId` idempotency, push notifications to offline recipients,
  and correct unread-count behavior with zero new code paths.
- **Alternatives considered**: A separate "status notifications" inbox -
  rejected per Q3.

## 7. Offline-queue idempotency (FR-002/FR-016)

- **Decision**: The `Status` schema's idempotency key is
  `clientStatusId: string` (unique index), generated client-side at
  creation time (UUID, same generation point as `clientMessageId` today).
  `POST /status/upload` and the `uploadStatus` socket event both perform an
  upsert-by-`clientStatusId`: if a status with that ID already exists,
  return/broadcast the existing document instead of creating a duplicate
  (mirrors `MessagesRepository.findByClientMessageId` used in
  `ChatService.saveMessage`).
- **Rationale**: Directly implements Q4's resolution ("reuse
  `clientMessageId` pattern"). On the client, `StatusLocalDataSourceImpl`
  already caches a status row immediately on creation (optimistic write,
  Constitution III); FR-016 only requires that the *same* cached row
  (carrying its `clientStatusId`) be retried on reconnect via the existing
  `syncPendingMessages`-style replay mechanism, extended to also replay
  queued statuses.
- **Alternatives considered**: Server-generated IDs with client-side
  dedup-by-content-hash - rejected: more fragile (two genuinely different
  statuses could hash-collide on metadata) and inconsistent with the
  established `clientMessageId` convention.

## 8. Client feed merge & view-state sync (FR-014/FR-015)

- **Decision**: `StatusRepositoryImpl.getRecentStatuses()` is extended to,
  on each call, fetch `GET /status/feed` (server-computed list of
  non-expired, permitted statuses with each viewer's `isViewed` flag),
  upsert each into the existing sqflite `statuses` table
  (`INSERT OR REPLACE`, matching the chat message dedup convention), then
  read the merged local table back - so the existing
  `is_viewed = 0 AND is_mine = 0 AND expires_at > now` /
  `is_viewed = 1` queries in `StatusLocalDataSourceImpl` continue to drive
  "Recent status" vs "Status that were presented" with **no UI change**,
  now reflecting server state. `markStatusAsViewed` continues to optimistically
  set `is_viewed = 1` locally and call `notifyViewed`/`statusViewed`; FR-015's
  "based on server-confirmed view state" is satisfied because the next
  feed fetch's `isViewed` flag (now true server-side) reconciles any
  optimistic-update edge case (e.g., the two-devices-mark-viewed race in
  Edge Cases) via the same `INSERT OR REPLACE`.
- **Rationale**: Minimal change to `StatusCubit`/`StatusLocalDataSourceImpl`
  - the existing query/section logic is reused verbatim; only the *source*
  of the cached rows changes (server feed in addition to socket pushes).
- **Alternatives considered**: Push-only model (no feed-fetch endpoint,
  rely solely on `statusReceived` socket events) - rejected: doesn't cover
  "load on app open" (User Story 2, scenario 1) for statuses posted while
  the app was closed.

## 9. "Show on Map" integration (User Story 6, scenario 3)

- **Decision**: A status with `privacy: 'showOnMap'` is treated as
  feed-visible to the author's mutual contacts exactly like
  `privacy: 'public'` (FR-005) - `GET /status/feed`'s mutual-contact branch
  covers `privacy ∈ {'public', 'showOnMap'}` (no new audience/permission
  model for the feed). Additionally, it is returned by the existing map
  feature's nearby-users/location query
  (`chat-app-backend/src/modules/map/map.service.ts`,
  `getNearbyUsers`/location-sharing permission check) as an extra field on
  the relevant user, gated by that user's existing location-sharing
  permission - it does not get its own `audience` array; the map channel is
  purely additive on top of its public-equivalent feed visibility.
- **Rationale**: Resolves the ambiguity in FR-004 acceptance scenario 3
  ("made available through the map-based status view ... in addition to the
  chosen audience rules") - the "chosen audience rules" are the
  mutual-contacts rule it shares with `public`. Matches the Assumptions
  section ("an additional channel layered on top of the author's
  location-sharing permissions ... not an independent privacy mechanism with
  its own audience list"). Avoids duplicating permission logic that the map
  module already enforces.
- **Alternatives considered**:
  - *A dedicated map-status audience list* - rejected per Assumptions (no
    evidence in spec/UI of a separate selector).
  - *`showOnMap` excluded from `GET /status/feed` entirely (map-only)* -
    rejected: would contradict FR-004 acceptance scenario 3's "in addition
    to the chosen audience rules" wording, and would mean a `showOnMap`
    status is invisible in the Updates feed even to the author's closest
    mutual contacts, which has no support in the spec or existing UI.

## 10. `musicTrackId` field

- **Decision**: No backend dependency. `musicTrackId` remains an opaque
  client-supplied string stored on the `Status` document (and already
  present in `StatusModel`/sqflite `statuses.music_track_id`); it is
  resolved to playable audio entirely client-side by the existing
  music repository/cubit (commit `824b869`, frontend-only). The backend
  treats it as pass-through metadata.
- **Rationale**: No `MusicModule` exists in `app.module.ts`, and the spec
  does not require server-side music catalog/search - out of scope.

## 11. Mid-session "Private" audience removal (Edge Cases)

- **Decision**: No server-side push to revoke an already-open status view.
  `GET /status/:id/viewers`, `GET /status/feed`, and
  `GET /status/media/:statusId/:filename` (T023/T030/T039/T048) all
  re-evaluate `privacy`/`audience` against live data on every request: if a
  viewer is removed from a "Private" status's `audience` mid-session, their
  *next* request for that status's feed entry, viewer list, or media is
  denied (`404`), but a request already in flight or a media file already
  downloaded to the device is not retroactively invalidated.
- **Rationale**: Matches FR-006/SC-003's "for both real-time delivery and
  any retrieval before expiration" wording (per-request enforcement) without
  requiring a new push-based revocation channel, which would add a new
  socket event and client-side teardown logic for a narrow edge case.
- **Alternatives considered**: A `statusAudienceChanged` push event forcing
  the client to close an open viewer - rejected as disproportionate; the
  live per-request check already satisfies FR-006/SC-003 for all *future*
  requests.

## 12. Partial media-upload failure (Edge Cases)

- **Decision**: `StatusRepositoryImpl.uploadStatus()` (T026) treats a
  non-recoverable upload failure (e.g., the multipart `POST /status/upload`
  request fails partway through, or returns a `4xx`) the same way
  `ChatRepositoryImpl` treats a failed message-media upload: set the local
  row's `sync_status = 'error'` and surface a retry affordance, rather than
  treating it as `'pending'` (which would trigger indefinite offline-queue
  retries per FR-016).
- **Rationale**: Reuses an established, already-tested status-transition
  pattern (Constitution III "On failure, update status to `error` and
  surface a retry option") instead of introducing a new failure taxonomy
  for statuses.
- **Alternatives considered**: Treating upload failures identically to
  offline (`'pending'`, auto-retried by T027) - rejected: a `4xx` rejection
  (e.g., oversized file, unsupported type) will never succeed on retry
  without user action, so silently retrying would loop forever.

## 13. Status search retrieval path (SC-003)

- **Decision**: The existing `status_search_bar.dart` widget filters the
  already-merged, already-permission-filtered local `statuses` table
  (the result of T032's `GET /status/feed` merge) client-side. No new
  server-side search endpoint is introduced.
- **Rationale**: SC-003 lists "search" as a retrieval path that must not
  leak "Private" statuses to non-audience users; since search operates only
  over data already filtered by `GET /status/feed`'s
  mutual-contact/audience rules (T030/T048), it cannot surface anything the
  feed itself wouldn't.
- **Alternatives considered**: A dedicated `GET /status/search?q=...`
  endpoint - rejected: no evidence in the existing UI of server-side status
  search, and it would duplicate the feed's permission filtering for no
  added capability.
