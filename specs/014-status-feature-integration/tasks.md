---

description: "Task list for Status Feature Backend & Logic Integration"
---

# Tasks: Status Feature Backend & Logic Integration

**Input**: Design documents from `/specs/014-status-feature-integration/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Repos**:
- **Frontend** (this repo): `/Volumes/Zeyad/Documents/work/Flutter/ciro-chat-app`
- **Backend** (sibling repo): `/Volumes/Zeyad/Documents/work/Node js/chat-app-backend`

All backend paths below are relative to the backend repo root; all frontend
paths are relative to this repo's root. Per SC-007, **no files under
`lib/features/status/presentation/pages/` or `presentation/widgets/`** may be
modified — this feature is data/business-logic only.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps task to a user story (US1-US6) from spec.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the new backend module and new frontend files referenced
by later phases.

- [X] T001 [P] Create backend `status` module skeleton: `src/modules/status/dto/`, `src/modules/status/schemas/`, and empty `src/modules/status/status.module.ts`, `src/modules/status/status.controller.ts`, `src/modules/status/status.service.ts`, `src/modules/status/status.repository.ts` (chat-app-backend)
- [X] T002 [P] Create new frontend domain/data files: `lib/features/status/domain/entities/status_viewer.dart` (StatusViewer entity) and `lib/features/status/data/models/status_viewer_model.dart` (StatusViewerModel with `fromJson`)

**Checkpoint**: Empty files exist for both new modules; ready for foundational implementation.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema/model/DI changes that every user story depends on. No
user story can be completed until this phase is done.

### Backend schemas & DTOs

- [X] T003 Define `Status` Mongoose schema with embedded `StatusView` (`userId`, `viewedAt`) and `StatusReaction` (`userId`, `reaction`, `createdAt`) subdocuments (`_id: false`), fields per data-model.md §1 (`authorId`, `clientStatusId`, `contentType`, `textContent`, `mediaUrl`, `backgroundColor`, `fontStyle`, `musicTrackId`, `caption`, `privacy`, `audience`, `views`, `reactions`, `expiresAt`), and indexes (`{clientStatusId:1}` unique, `{authorId:1, createdAt:-1}`, `{expiresAt:1}` TTL `expireAfterSeconds:0`, `{privacy:1, authorId:1}`) in `src/modules/status/schemas/status.schema.ts`
- [X] T004 [P] Create `CreateStatusDto` (clientStatusId, contentType, textContent?, backgroundColor?, fontStyle?, musicTrackId?, caption?, privacy, audience?) with `class-validator` decorators in `src/modules/status/dto/create-status.dto.ts`
- [X] T005 [P] Create `ReactStatusDto` (`reaction: string`) and `ReplyStatusDto` (`message: string`) in `src/modules/status/dto/react-status.dto.ts` and `src/modules/status/dto/reply-status.dto.ts`
- [X] T006 [P] Create a reusable `audience` field validator (`class-validator` custom decorator validating `string[]` of MongoDB ObjectId-format strings) in `src/modules/status/dto/audience.validator.ts`, applied to `CreateStatusDto.audience` (T004); `defaultStatusAudience` persistence (T050) reuses `CreateStatusDto.audience` directly - no separate "set default audience" DTO/endpoint exists
- [X] T007 Extend `User` schema in `src/modules/users/schemas/user.schema.ts`: add `syncedContacts: string[]` (default `[]`) with multikey index `{syncedContacts:1}`, and `defaultStatusAudience: Types.ObjectId[]` (ref `User`, default `[]`), per data-model.md §2
- [X] T008 Extend `Message` schema in `src/modules/chat/schemas/message.schema.ts`: add optional `statusRef?: { statusId: Types.ObjectId; statusAuthorId: Types.ObjectId; expiresAt: Date }` per data-model.md §3

### Backend module wiring

- [X] T009 Implement `StatusRepository extends BaseRepository<Status>` in `src/modules/status/status.repository.ts` with: `findByClientStatusId`, mutual-contact-aware `findFeedForUser(userId)`, `findViewersByStatusId`, `upsertView`, `upsertReaction`, audience-subset validation helper
- [X] T010 Implement `StatusService` constructor/DI skeleton (inject `StatusRepository`, `UsersRepository`/`UsersService`, and `ChatService` via `forwardRef(() => ChatModule)`) in `src/modules/status/status.service.ts`
- [X] T011 Implement `StatusController` skeleton with `@UseGuards(JwtAuthGuard)` class-level guard and route stubs for all 7 endpoints in contracts/status-rest-api.md, in `src/modules/status/status.controller.ts`
- [X] T012 Create `StatusModule` registering `MongooseModule.forFeature([{name: Status.name, schema: StatusSchema}])`, `StatusController`, `StatusService`, `StatusRepository`, exporting `StatusService`, and importing `forwardRef(() => ChatModule)` + `UsersModule`, in `src/modules/status/status.module.ts`
- [X] T013 Import `StatusModule` into `ChatModule` via `forwardRef(() => StatusModule)` in `src/modules/chat/chat.module.ts`
- [X] T014 Extend `UsersRepository.syncContacts`/`UsersService.syncContacts` to `$set` the caller's `syncedContacts` from `SyncContactsDto.phoneNumbers`, and add a `findMutualContactIds(userId)` helper (bidirectional `phoneNumber ∈ syncedContacts` check) in `src/modules/users/users.repository.ts` and `src/modules/users/users.service.ts`

### Frontend schema/model/interface extensions

- [X] T015 Bump sqflite DB version to 17 and add `onUpgrade` migration adding columns `client_status_id TEXT DEFAULT ''`, `sync_status TEXT DEFAULT 'synced'`, `audience_json TEXT DEFAULT '[]'`, `author_id TEXT DEFAULT ''` to the `statuses` table, plus `CREATE INDEX IF NOT EXISTS idx_statuses_client_id ON statuses(client_status_id)`, in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [X] T016 [P] Extend `StatusEntity` (`lib/features/status/domain/entities/status_entity.dart`) and `StatusModel` (`lib/features/status/data/models/status_model.dart`) with `clientStatusId`, `audience: List<String>`, `syncStatus`, `authorId`, `viewers: List<StatusViewer>`, `reactions` fields, `toMap()`/`fromMap()`/`toJson()`/`fromJson()` updates
- [X] T017 Extend `StatusRepository` abstract interface in `lib/features/status/domain/repositories/status_repository.dart` with new method signatures: `getFeed()`, `getViewers(statusId)`, `getDefaultAudience()`, `react(statusId, reaction)`, `reply(statusId, message)`, all returning `Either<Failure, T>`
- [X] T018 [P] Add new socket event name constants (`uploadStatus`, `statusUploaded`, `statusReceived`, `statusViewed`, `statusViewerAdded`, `statusReacted`) to `lib/core/network/socket_events.dart` (skip any already present)

**Checkpoint**: Both repos compile with the new schemas/models/interfaces in place (empty/stub implementations). User story phases can now begin.

---

## Phase 3: User Story 1 - Post a Status That Contacts Can See (Priority: P1) 🎯 MVP

**Goal**: A status created on the client is persisted server-side, idempotent
on `clientStatusId`, and delivered to permitted mutual contacts.

**Independent Test**: Post a text status as User A (mutual contact of User
B); verify the status is persisted server-side and appears in User B's feed.

### Backend

- [X] T019 [US1] Implement `StatusService.createStatus(userId, dto, file?)`: idempotent lookup by `clientStatusId` (return existing on replay), validation (exactly one of `textContent`/media per contentType), `expiresAt = now + 24h`, audience-subset-of-mutual-contacts validation for `privacy='private'` (400 on violation), persist via `StatusRepository`, in `src/modules/status/status.service.ts`
- [X] T020 [US1] Implement `POST /status/upload` in `src/modules/status/status.controller.ts`: `multipart/form-data` with `FileInterceptor('file', diskStorage(...))` (mirror `POST /chat/upload` config, `<=20MB`) when `contentType` is `image|video|voice`, plain JSON body when `contentType='text'`; return `201`/`200` per contracts/status-rest-api.md
- [X] T021 [US1] Implement recipient resolution + `statusReceived` fan-out: for `privacy='public'`, resolve all mutual contacts via `findMutualContactIds`; for `privacy='private'`, use `audience`; emit `statusReceived` to each online recipient's `user:<userId>` room with `isViewed:false, isMine:false`, in `src/modules/status/status.service.ts`
- [X] T022 [US1] Implement `uploadStatus` `@SubscribeMessage` handler in `src/modules/chat/chat.gateway.ts`: validate payload (`if (data == null || data is! Map) return` equivalent — TS null/shape check), delegate to `StatusService.createStatus`, emit `statusUploaded` ACK (`{clientStatusId, id, createdAt}`) to the originating socket
- [X] T023 [US1] Implement `GET /status/media/:statusId/:filename` in `src/modules/status/status.controller.ts`: `@UseGuards(JwtAuthGuard)`, re-check requester permission via `StatusService` (author / mutual contact for public / audience member for private), stream file with `Content-Type` from stored `mimeType`, `404` if expired/not permitted (not `403`)

### Frontend

- [X] T024 [US1] Replace the stub in `StatusRemoteDataSourceImpl.uploadStatus()` (`lib/features/status/data/datasources/status_remote_data_source.dart`): generate/forward `clientStatusId`, use Dio multipart `POST /status/upload` for `image|video|voice` (mirroring existing chat upload), or socket emit `uploadStatus` for `text`
- [X] T025 [US1] In `StatusLocalDataSourceImpl` (`lib/features/status/data/datasources/status_local_data_source.dart`), implement optimistic insert on creation: write row with `client_status_id`, `author_id = currentUserId`, `sync_status = 'pending'`, `is_mine = 1`
- [X] T026 [US1] Implement `StatusRepositoryImpl.uploadStatus()` orchestration in `lib/features/status/data/repositories/status_repository_impl.dart`: optimistic local insert (T025) → attempt remote (T024) → on success update row to `sync_status='synced'`; on no-connectivity leave `sync_status='pending'` for replay (T027); on a non-recoverable upload failure (e.g., a media upload that fails partway through, or a 4xx rejection) set `sync_status='error'` (mirroring the existing chat message `pending → error` transition, Constitution III) and surface a retry option to the user
- [X] T027 [US1] Implement offline-queue replay: on socket reconnect (`SocketService` reconnect callback) or app start, query `statuses WHERE sync_status='pending' AND is_mine=1` and resubmit each via `uploadStatus()` (T024), in `lib/features/status/data/repositories/status_repository_impl.dart`
- [X] T028 [US1] Wire `statusUploaded` ACK: add typed `onStatusUploaded` callback in `lib/core/network/socket_service.dart` (validating payload per Constitution IV-A: `if (data == null || data is! Map) return; Map<String,dynamic>.from(data)`), handled in `status_repository_impl.dart` to set `sync_status='synced'` for the matching `client_status_id` row
- [X] T029 [US1] Update status media URL resolution: pass the relative `mediaUrl` (`/status/media/:statusId/:filename`) returned by `GET /status/feed` through `UrlUtils.resolveMediaUrl()` (Constitution VIII-A) to obtain the absolute URL, then request it with the Bearer access token attached (via existing `TokenRefreshService`/Dio interceptor or `CachedNetworkImage` custom headers), in `lib/features/status/data/datasources/status_remote_data_source.dart`

**Checkpoint**: A status posted on Device A is persisted server-side, idempotent on retry, and (per US2 below) deliverable to Device B.

---

## Phase 4: User Story 2 - View Contacts' Statuses in Real Time (Priority: P1)

**Goal**: The Updates screen shows the merged server+local feed and updates
live via `statusReceived` with no manual refresh.

**Independent Test**: With Device B's Updates screen open, User A posts a new
status; it appears in Device B's "Recent status" within seconds.

### Backend

- [X] T030 [US2] Implement `GET /status/feed` in `src/modules/status/status.controller.ts`/`status.service.ts`/`status.repository.ts`: return non-expired statuses where `isMine=true` OR (`privacy ∈ {'public','showOnMap'}` AND mutual contact) OR (`privacy='private'` AND caller in `audience`), each annotated with `isViewed`/`isMine` per contracts/status-rest-api.md - `showOnMap` is feed-visible to mutual contacts identically to `public` (research.md §9), in addition to its map-channel visibility (T051)

### Frontend

- [X] T031 [US2] Extend `StatusRemoteDataSourceImpl` with `getFeed()` calling `GET /status/feed`, mapping response to `List<StatusModel>`, in `lib/features/status/data/datasources/status_remote_data_source.dart`
- [X] T032 [US2] Implement `StatusRepositoryImpl.getRecentStatuses()` to call `getFeed()` (T031), `INSERT OR REPLACE` each result into the sqflite `statuses` table via `StatusLocalDataSourceImpl`, then read back and return the merged local result using the existing `is_viewed`/`is_mine`/`expires_at` query logic unchanged, in `lib/features/status/data/repositories/status_repository_impl.dart`. The existing `status_search_bar.dart` widget filters this same merged local result client-side - no separate search endpoint is introduced, so SC-003's "search" retrieval path is covered by this same permission-filtered feed
- [X] T033 [US2] Confirm/repair the `statusReceived` → `SocketService.onStatusReceived` → `StatusRemoteDataSourceImpl` → `StatusRepositoryImpl.statusStream` → `StatusCubit._listenToStatusStream()` path: ensure the incoming payload (real `Status` document fields) maps correctly to `StatusModel`, is upserted into sqflite, and inserted into `recentStatuses` in `lib/features/status/presentation/bloc/status_cubit.dart`

**Checkpoint**: US1 + US2 together deliver the MVP — post and view statuses in real time.

---

## Phase 5: User Story 3 - Statuses Expire After 24 Hours for Everyone (Priority: P1)

**Goal**: Expired statuses (and their views/reactions/replies) are
unreachable from any retrieval path, server and client.

**Independent Test**: A status created >24h ago does not appear in
`GET /status/feed`, its Mongo document is gone, and it's purged from local
storage.

### Backend

- [X] T034 [US3] Verify the `Status.expiresAt` TTL index (`expireAfterSeconds: 0`, from T003) is created on app boot (`db.statuses.getIndexes()` per quickstart.md); add a TTL index on `Message` for `statusRef.expiresAt` (`expireAfterSeconds: 0`, partial index `{ statusRef: { $exists: true } }`) in `src/modules/chat/schemas/message.schema.ts` so status-reply messages are cleaned up in alignment with their source status (research.md §2)
- [X] T035 [US3] [P] Add a defensive `expiresAt > now` filter to `StatusRepository.findFeedForUser`, `findViewersByStatusId`, and the media-permission check in `status.repository.ts`/`status.service.ts` (belt-and-braces alongside the TTL index, per FR-008/SC-002)

### Frontend

- [X] T036 [US3] Extend the existing local expiry-purge timer in `lib/features/status/presentation/bloc/status_cubit.dart` (and/or `StatusLocalDataSourceImpl`) to `DELETE FROM statuses WHERE expires_at <= now` on its existing 5-minute interval, satisfying FR-020

**Checkpoint**: US1-US3 complete — full P1 MVP (post, view live, auto-expire).

---

## Phase 6: User Story 4 - Author Sees Who Viewed Their Status (Priority: P2)

**Goal**: Status authors can retrieve a viewer list and get real-time
notifications of new views.

**Independent Test**: User B views User A's status; User A (online) receives
`statusViewerAdded` and `GET /status/:id/viewers` lists User B.

### Backend

- [X] T037 [US4] Implement `statusViewed` `@SubscribeMessage` handler in `src/modules/chat/chat.gateway.ts` delegating to `StatusService.recordView(statusId, viewerId)` (no payload shape change from existing `notifyStatusViewed` emit)
- [X] T038 [US4] Implement `StatusService.recordView`: upsert a `StatusView{userId, viewedAt}` into `Status.views` keeping the *first* `viewedAt` per user (mirrors `MessagesRepository.markRead`'s `$addToSet`), then emit `statusViewerAdded` (`{statusId, viewer:{userId,name,avatarUrl}, viewedAt}`) to the author's `user:<userId>` room if online, in `src/modules/status/status.service.ts`
- [X] T039 [US4] Implement `GET /status/:id/viewers` in `status.controller.ts`/`status.service.ts`: `403` if `req.user.userId !== status.authorId`, else return `views` resolved to `{userId, name, avatarUrl, viewedAt}[]`

### Frontend

- [X] T040 [US4] Add typed `onStatusViewerAdded` callback to `lib/core/network/socket_service.dart` (validating payload per Constitution IV-A)
- [X] T041 [US4] Implement `getViewers(statusId)` in `status_remote_data_source.dart` (`GET /status/:id/viewers`) and `status_repository_impl.dart`, returning `Either<Failure, List<StatusViewer>>`
- [X] T042 [US4] Wire `onStatusViewerAdded` through `status_remote_data_source.dart` → `status_repository_impl.dart` → `StatusCubit`, updating viewer-count/list state for the caller's own status in `lib/features/status/presentation/bloc/status_cubit.dart` and `status_state.dart`

**Checkpoint**: Authors get viewer lists + live viewer notifications.

---

## Phase 7: User Story 5 - React To and Reply To a Status (Priority: P2)

**Goal**: Viewers can send a fixed-type reaction or a text reply; the author
receives both.

**Independent Test**: User B sends a reaction and a text reply while viewing
User A's status; User A receives `statusReacted` in real time and the reply
appears as a new chat message tagged with `statusRef`.

### Backend

- [X] T043 [US5] Implement `POST /status/:id/react` in `status.controller.ts`/`status.service.ts`: visibility check (403/404 per FR-006), upsert caller's `StatusReaction` in `Status.reactions` (replace prior reaction by same user), emit `statusReacted` (`{statusId, reaction, from:{userId,name,avatarUrl}, createdAt}`) to author's room if online
- [X] T044 [US5] Implement `POST /status/:id/reply` in `status.controller.ts`/`status.service.ts`: visibility check (403/404), resolve/create 1:1 room via `ChatService.resolvePrivateRoom(viewerId, authorId)`, call `ChatService.saveMessage(...)` with `messageType: TEXT`, `content: message`, `statusRef: {statusId, statusAuthorId: authorId, expiresAt: status.expiresAt}`; return the created `Message`. Verify (FR-010) that `ChatService.saveMessage`'s existing `newMessage` socket emission fires for this `statusRef`-tagged message exactly as for any other chat message - no additional event is introduced

### Frontend

- [X] T045 [US5] [P] Add typed `onStatusReacted` callback to `lib/core/network/socket_service.dart` (validating payload per Constitution IV-A), wired through `status_remote_data_source.dart` → `status_repository_impl.dart` → `StatusCubit` (consumed and stored on state per research.md §1, no new UI required)
- [X] T046 [US5] Implement/fix `StatusRepositoryImpl.reactToStatus(statusId, reaction)` to call `POST /status/:id/react` via `status_remote_data_source.dart`, returning `Either<Failure, void>`
- [X] T047 [US5] Implement `StatusRepositoryImpl.replyToStatus(statusId, message)` calling `POST /status/:id/reply` via `status_remote_data_source.dart`; on success, insert the returned `Message` (with `statusRef`) into the existing chat local data source / message list for that `roomId` so it appears via the normal chat send flow (FR-018), in `lib/features/status/data/repositories/status_repository_impl.dart`

**Checkpoint**: Reactions and replies flow end-to-end.

---

## Phase 8: User Story 6 - Control Who Can See a Status (Priority: P2)

**Goal**: "Public" (mutual contacts), "Private" (selected audience, persisted
default), and "Show on Map" privacy settings are fully enforced.

**Independent Test**: A "Private" status to User B only is invisible to User
C (mutual contact, not selected) but visible to User B; the next "Private"
status pre-selects User B via `GET /status/audience/default`.

### Backend

- [X] T048 [US6] Audit and harden `StatusRepository.findFeedForUser`/`findViewersByStatusId`/media-permission check (T030/T039/T023) so `privacy ∈ {'public','showOnMap'}` strictly requires bidirectional `syncedContacts` membership (FR-005/SC-008) and `privacy='private'` strictly requires caller `∈ audience` (FR-006/SC-003), in `src/modules/status/status.repository.ts`
- [X] T049 [US6] Implement `GET /status/audience/default` in `status.controller.ts`/`status.service.ts`: resolve `User.defaultStatusAudience` to `{userId, name, phoneNumber, avatarUrl}[]`, silently omitting entries no longer mutual contacts
- [X] T050 [US6] In `StatusService.createStatus` (T019), when `privacy='private'`, `$set User.defaultStatusAudience = audience` after successful creation (FR-013), in `src/modules/status/status.service.ts`
- [X] T051 [US6] Implement the additional "Show on Map" channel: a `privacy='showOnMap'` status is already feed-visible to mutual contacts via T030/T048 (identical to `public`); additionally include its status reference in the existing `getNearbyUsers`/location-sharing query in `src/modules/map/map.service.ts`, gated by that user's existing location-sharing permission (research.md §9) — no new audience list

### Frontend

- [X] T052 [US6] Implement `getDefaultAudience()` in `status_remote_data_source.dart` (`GET /status/audience/default`) and `status_repository_impl.dart`; cache the result as a JSON array in `SharedPreferences` (`status_default_audience`, data-model.md §5), refreshed on app start and after each successful status post
- [X] T053 [US6] In the "Private (select contacts)" flow, pre-select the cached/fetched default audience (T052) and submit the (possibly edited) `audience: List<String>` with `uploadStatus()` (T024); persist to local `audience_json` column on success, in `lib/features/status/data/repositories/status_repository_impl.dart` and `status_local_data_source.dart`
- [X] T054 [US6] [P] Verify `StatusCubit`'s feed-section logic (`recentStatuses`/"Status that were presented") relies solely on the server-filtered `GET /status/feed` result (T032) for visibility — no client-side privacy re-filtering needed — in `lib/features/status/presentation/bloc/status_cubit.dart`

**Checkpoint**: All privacy modes (Public/Private/Show on Map) enforced end-to-end; all 6 user stories complete.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T055 [P] Write backend Jest specs: `src/modules/status/status.service.spec.ts`, `src/modules/status/status.controller.spec.ts`, extend `src/modules/chat/chat.gateway.spec.ts` (status events) and `src/modules/users/users.service.spec.ts` (syncedContacts/mutual contacts), per quickstart.md backend test commands
- [X] T056 [P] Write frontend tests under `test/features/status/` (Cubit/`bloc_test`, repository, data source unit tests covering feed merge, offline queue, idempotency, reactions/replies)
- [ ] T057 Run the 9-step manual smoke test from quickstart.md §3 (US1-US6 + mutual-contact edge case + offline queue + media access control) across two devices/emulators
- [X] T058 Verify SC-007: launch the app and visually compare the existing Updates screen, status creation bottom sheet, and story viewer before/after — confirm zero layout/visual changes; flag any gap as a follow-up rather than adding UI
- [X] T059 [P] Update `StatusCubit.close()`/`dispose()` (and corresponding `SocketService` listener teardown) to cancel/unsubscribe the new `onStatusUploaded` (T028), `onStatusViewerAdded` (T040), and `onStatusReacted` (T045) callbacks alongside the existing `_statusSubscription`/`_expiryTimer`, per Constitution V (Memory Leak Prevention), in `lib/features/status/presentation/bloc/status_cubit.dart` and `lib/core/network/socket_service.dart`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001-T002) - BLOCKS all user stories (T019+)
- **User Stories (Phase 3-8)**: All depend on Foundational (Phase 2) completion
  - US1 (P1) and US2 (P1) are tightly coupled (post → feed/delivery) but their backend/frontend halves can proceed in parallel once Phase 2 is done
  - US3 (P1) depends on the `Status`/`Message` schemas (T003, T008) from Phase 2 only
  - US4-US6 (P2) depend on Phase 2 and benefit from US1/US2 being functional for end-to-end testing, but their server-side pieces (viewers, reactions, replies, audience) are independently codable
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundational only
- **US2 (P1)**: Foundational only; functionally validated together with US1
- **US3 (P1)**: Foundational only (T003 `Status` schema, T008 `Message` schema)
- **US4 (P2)**: Foundational + benefits from US1 (statuses to view) for testing
- **US5 (P2)**: Foundational + US4's visibility checks pattern (T039) reused in T043/T044; benefits from US1/US2 for testing
- **US6 (P2)**: Foundational; T048 hardens queries already built in T030/T039/T023 (US2/US4/US1)

### Within Each User Story

- Backend schema/service/controller before frontend data source/repository/cubit wiring
- `StatusService` methods (createStatus, recordView, react, reply, feed, audience) before the `ChatGateway`/`StatusController` handlers that call them
- Repository interface methods (T017) before their `StatusRepositoryImpl` implementations

### Parallel Opportunities

- T001 and T002 (Setup) in parallel
- T004, T005, T006 (DTOs/validators) in parallel after T003
- T016 and T018 (frontend model/socket-constant extensions) in parallel after T015/T017
- T035 and T036 (US3 backend filter + frontend purge) in parallel
- T045 (US5 socket callback) in parallel with T043/T044 (backend reaction/reply endpoints)
- T054 (US6 cubit verification) in parallel with T052/T053
- T055, T056, and T059 (Polish tests/cleanup) in parallel

---

## Parallel Example: Foundational Phase

```bash
# Backend DTOs, after T003 (Status schema) lands:
Task: "Create CreateStatusDto in src/modules/status/dto/create-status.dto.ts"
Task: "Create ReactStatusDto and ReplyStatusDto in src/modules/status/dto/"
Task: "Create the audience field validator in src/modules/status/dto/audience.validator.ts"

# Frontend, after T015 (sqflite migration) and T017 (repo interface):
Task: "Extend StatusEntity/StatusModel with clientStatusId, audience, syncStatus, authorId, viewers"
Task: "Add new socket event constants to lib/core/network/socket_events.dart"
```

---

## Implementation Strategy

### MVP First (User Stories 1-3, all P1)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks everything)
3. Complete Phase 3 (US1: post + persist + deliver)
4. Complete Phase 4 (US2: live feed)
5. Complete Phase 5 (US3: 24h expiry)
6. **STOP and VALIDATE**: Run quickstart.md steps 1-3 (US1-US3) end-to-end across two devices

### Incremental Delivery

1. Setup + Foundational → both repos compile with new schemas/models
2. US1 + US2 + US3 → MVP: post, view live, auto-expire (validate via quickstart steps 1-3, 8)
3. US4 → viewer lists + live notifications (quickstart step 4)
4. US5 → reactions + replies (quickstart step 5)
5. US6 → privacy enforcement + default audience (quickstart steps 6-7, 9)
6. Polish → tests + full smoke test + SC-007 visual check
