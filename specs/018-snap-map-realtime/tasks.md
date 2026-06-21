# Tasks: Snap Map Real-Time Logic

**Input**: Design documents from `/specs/018-snap-map-realtime/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: INCLUDED — the spec's success criteria (SC-001/008 authorization, SC-009 TTL, SC-011 race, SC-012 batching) are correctness/privacy guarantees that must be verified, and the project already has a test culture (`test/features/status`, backend `*.spec.ts`).

**Organization**: Tasks are grouped by user story (priority order) for independent implementation and testing.

## Path Conventions

- **Flutter app**: `lib/features/map/`, `lib/core/`, tests in `test/features/map/`
- **Backend** (separate repo): `chat-app-backend/src/modules/...` (additional working dir `/Volumes/Zeyad/Documents/work/Node js/chat-app-backend`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependencies, permissions, and folder structure

- [X] T001 [P] Add Flutter deps to `pubspec.yaml`: `geolocator`, a clustering helper (`google_maps_cluster_manager`); confirm `google_maps_flutter`, `widget_to_marker`, `cached_network_image`, `fpdart`, `injectable`, `shared_preferences`, `image` are present. Run `flutter pub get`. — used `google_maps_cluster_manager_2` (maintained fork) + `image: ^4.3.0`; `geolocator` was already present.
- [X] T002 [P] Add device location permission strings: `NSLocationWhenInUseUsageDescription` in `ios/Runner/Info.plist` and `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` in `android/app/src/main/AndroidManifest.xml`. — already present from existing `geolocator` usage; no change needed.
- [X] T003 [P] Create the missing Clean Architecture folders under `lib/features/map/`: `data/datasources/`, `data/models/`, `data/repositories/`, `domain/entities/`, `domain/repositories/`, `presentation/utils/`.
- [X] T004 [P] Confirm/add `@nestjs/schedule` (or plan a plain `setInterval`) in `chat-app-backend` for the batch-flush timer; ensure `MapModule` imports `ChatModule`/gateway access for room fan-out in `chat-app-backend/src/modules/map/map.module.ts`. — used plain `setInterval`+`OnModuleDestroy` in `LocationBatchService` (no new dependency); resolved analysis finding I2 by extending `chat.gateway.ts` directly (no separate map gateway) with a `forwardRef` circular module relationship between `ChatModule`↔`MapModule`, mirroring the existing `ChatModule`↔`StatusModule` pattern. Verified via a live Nest DI boot check — no dependency-resolution errors.

**Also resolved (pre-implementation, from `/speckit.analyze` findings I1/I2):**
- [X] Fixed `SocketService.onUserStatusChanged` single-assignment conflict (I1): converted to a multicast listener list (`addUserStatusListener`/`removeUserStatusListener`, mirroring the existing `_reconnectListeners` pattern) in `lib/core/network/socket_service.dart`; migrated `ChatCubit` to the new API with proper `close()` teardown. Both ChatCubit (SQLite presence) and the future MapCubit can now listen independently.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema, entities, contracts, and skeletons that ALL user stories depend on. No story can start until this phase is complete.

⚠️ Blocks every user story below.

### Backend schema & authorization core

- [X] T005 [P] Extend User schema in `chat-app-backend/src/modules/users/schemas/user.schema.ts`: add `isGhostMode: boolean` (default `false`) and `locationUpdatedAt?: Date`. Keep the existing `2dsphere` `location` index.
- [X] T006 Implement `authorizedObserverIds(userId)` and `visibleMapUsers(viewerId)` — implemented in **`map.service.ts`+`map.repository.ts`** (new files) rather than `users.repository.ts`: a map-domain concern, avoids `UsersModule` needing to know about `ChatRoom`. Union of shared chat-room participants (direct `ChatRoom` model injection, mirroring the existing `UsersRepository`→`Status` model pattern) and `findMutualContactIds`, minus blocked (both directions) and self. Tested in `map.service.spec.ts` (SC-001/008).

### Flutter domain (entities + abstract repo)

- [ ] T007 [P] Create `MapUser` entity in `lib/features/map/domain/entities/map_user.dart` (Equatable; fields per data-model incl. `lastUpdatedAt`, `groupIds`, `isCoarse`, `isCurrentUser`). Replaces `MockUser`/`MockMapMarker`.
- [ ] T008 [P] Create `MapFilter` value object + `MapStatusFilter`/`MapDistanceFilter` enums in `lib/features/map/domain/entities/map_filter.dart` (defaults: status `all`, groupId `null`, distance `all`, radius `10.0`), with `bool matches(MapUser)`.
- [ ] T009 [P] Create `MapGroup` entity in `lib/features/map/domain/entities/map_group.dart`.
- [ ] T010 Define abstract `MapRepository` in `lib/features/map/domain/repositories/map_repository.dart` (returns `Either<Failure, T>`; exposes user fetches, groups, ghost-mode, location share, and live update streams).

### Flutter data skeleton + DTOs

- [ ] T011 [P] Create `MapUserModel` in `lib/features/map/data/models/map_user_model.dart` (`fromJson` mapping `_id`→id, `location.coordinates`→lat/lng, `locationUpdatedAt`→`lastUpdatedAt`, `sharedGroupIds`→groupIds, `isCoarse`; `toEntity()`). Follow `StatusModel` pattern; resolve avatar via `UrlUtils.resolveMediaUrl` at render time.
- [ ] T012 [P] Create `LocationUpdateModel` in `lib/features/map/data/models/location_update_model.dart` parsing batched items (`userId`, `longitude`, `latitude`, `isOnline`, `lastUpdatedAt`) — used by the IV-A-safe socket handler.
- [ ] T013 Create `MapRemoteDataSource` (abstract + impl skeleton) in `lib/features/map/data/datasources/map_remote_data_source.dart` with `DioClient` + `SocketService` injected (`@LazySingleton`); declare streams `onLocationUpdate`/`onLocationHidden`/`onUserStatusChanged`.
- [ ] T014 Create `MapRepositoryImpl` skeleton in `lib/features/map/data/repositories/map_repository_impl.dart` (`@LazySingleton(as: MapRepository)`), constructor-injected datasource + `AuthLocalDataSource` + `SharedPreferences`.

### Flutter presentation skeleton

- [ ] T015 Rewrite `MapState` in `lib/features/map/presentation/bloc/map_state.dart`: add `MapViewStatus` enum (`loading/loaded/empty/error`), `allUsers`, `filter`, `groups`, `selfLocation`, `isSharing`, `isGhostMode`, `permissionGranted`, `failure`; keep `googleMarkers`, `selectedUser`, `mapType`, `selectedTab`. Extend `copyWith`/`props` (Equatable).
- [ ] T016 Rewrite `MapCubit` constructor/shell in `lib/features/map/presentation/bloc/map_cubit.dart`: inject `MapRepository`; remove mock seeding; add a private `_deriveMarkers()` placeholder and an empty `close()` that will cancel subscriptions + timers.
- [ ] T017 Register the map feature in DI: annotate the new classes and run `dart run build_runner build --delete-conflicting-outputs`; verify wiring in `lib/core/di/injection.config.dart`. Provide `MapCubit` to `MapScreen` (e.g., `BlocProvider` in `lib/core/routing/app_router.dart`).

**Checkpoint**: Schema, entities, contracts, DI, and skeletons exist — user stories can begin.

---

## Phase 3: User Story 1 — See Contacts on the Map in Real Time (Priority: P1) 🎯 MVP

**Goal**: Replace mock markers with the authorized live-contact set; markers reflect live presence; marker state is race-safe (idempotent) and self-cleaning (TTL); the Following/Explore tabs are populated (Explore = coarse status markers).

**Independent Test**: Sign in with a contact who shared a location; their marker appears at real coords with correct online/offline border; toggling their presence updates the marker within 5 s; a late HTTP load never overwrites a fresher socket value; a force-quit contact's marker disappears after the TTL cycle.

### Backend (US1)

- [X] T018 [US1] Add `GET /map/visible` in `chat-app-backend/src/modules/map/map.controller.ts` + `map.service.ts`: return `visibleMapUsers(caller)` excluding ghost-mode + no-location users; include `locationUpdatedAt` and `sharedGroupIds` per item (FR-003b).
- [X] T019 [US1] In `PATCH /map/location` (`map.service.updateLocation`) set server-assigned `locationUpdatedAt = now` on every write (`chat-app-backend/src/modules/users/users.service.ts`).
- [X] T020 [US1] Add `GET /map/explore` in `map.controller.ts` + `map.service.ts`: return users with active `SHOW_ON_MAP` status; **coarsen** coordinates (truncate to 2 dp) and set `isCoarse: true` for non-contacts (FR-001b). Reuse status repo map-visible query.
- [X] T021 [P] [US1] Backend authorization test `chat-app-backend/src/modules/map/map.service.spec.ts`: authorized contact ✓, unauthorized non-contact ✗, blocked (both directions) ✗, ghost-mode ✗ (SC-001/008). 10 tests passing.
- [X] T022 [P] [US1] Backend Explore coarsening test in `map.service.spec.ts`: non-contact coords are grid-truncated, contact coords precise (FR-001b).

### Flutter data (US1)

- [ ] T023 [US1] Implement `getVisibleUsers()` and `getExploreUsers()` in `map_remote_data_source.dart` (Dio GET `/map/visible`, `/map/explore`); wire `SocketService.onUserStatusChanged` → `onUserStatusChanged` stream.
- [ ] T024 [US1] Implement repository fetches in `map_repository_impl.dart` returning `Either<Failure, List<MapUser>>` (map Dio/Socket exceptions to `ServerFailure`/`CacheFailure` per Constitution VII).

### Flutter presentation (US1)

- [ ] T025 [US1] In `MapCubit` (`map_cubit.dart`): `loadFollowing()` → emit `loading` then `loaded`/`empty`/`error`; populate `allUsers`; subscribe to `onUserStatusChanged` to update matching `MapUser.isOnline` (debounced, FR-004).
- [ ] T026 [US1] Implement the **idempotent upsert** helper in `MapCubit`: apply an incoming user/location ONLY IF `lastUpdatedAt` is strictly newer than the cached entry (used by initial load + live updates) — FR-022a / SC-011.
- [ ] T027 [US1] Implement the **TTL cleanup** `Timer.periodic` (~60 s) in `MapCubit`: fade then remove markers older than 2 h with no update; re-derive; cancel the timer in `close()` (FR-003c / SC-009, Constitution V).
- [ ] T028 [US1] Implement `_deriveMarkers()` building `googleMarkers` from `allUsers` (plain avatar markers for now — clustering/isolate added in US5); wire `selectUser` to real `MapUser` and the existing user-detail sheet (FR-030).
- [ ] T029 [US1] Wire `lib/features/map/presentation/pages/map_screen.dart` to live state: feed `state.googleMarkers`; handle `loading`/`empty`/`error` (with retry) overlays (FR-029); wire Following/Explore tab switch to `loadFollowing()`/`loadExplore()`.
- [ ] T030 [US1] Update `lib/features/map/presentation/widgets/map_avatar_marker.dart` to render from `MapUser` (replace `MockMapMarker`); keep visuals unchanged.

### Tests (US1)

- [ ] T031 [P] [US1] `test/features/map/map_cubit_test.dart` (`bloc_test`): load→loaded/empty/error; presence update flips marker; **stale-timestamp update is ignored** (SC-011); **TTL tick removes aged marker** (SC-009).
- [ ] T032 [P] [US1] `test/features/map/map_repository_impl_test.dart` (`mocktail`): `Either` success/failure mapping for visible/explore fetches.

**Checkpoint**: MVP — the map shows real authorized contacts with live, race-safe, self-cleaning markers and a coarse Explore tab.

---

## Phase 4: User Story 2 — Filter Who Appears on the Map (Priority: P1)

**Goal**: Status (All/Online/Offline) and group filters drive the visible markers instantly; group list comes from the user's real groups.

**Independent Test**: With mixed markers, "Online Only" shows only online; selecting "Tech Team" shows only that group; combined = intersection; selections persist across reopening the sheet.

### Backend (US2)

- [X] T033 [US2] Add `GET /map/groups` in `chat-app-backend/src/modules/map/map.controller.ts` + `map.service.ts`: return the caller's `ChatRoom`s where `type = GROUP` (`id`, `name`, `memberCount`, `avatarUrl`, `initials`).

### Flutter (US2)

- [ ] T034 [US2] Implement `getGroups()` in `map_remote_data_source.dart` + repository (`Either<Failure, List<MapGroup>>`).
- [ ] T035 [US2] In `MapCubit`: `setStatusFilter`, `setGroupFilter`, `loadGroups`; store `filter` in state (retained for session, FR-021); `_deriveMarkers()` applies status+group client-side over `allUsers` (< 300 ms, SC-004); re-derive on every live update (FR-022).
- [ ] T036 [US2] Lift `lib/features/map/presentation/widgets/map_filter_sheet.dart` local state into the cubit: read selection from `state.filter`, dispatch `setStatusFilter`/`setGroupFilter`; replace `mockGroupsList` with `state.groups`. No visual redesign.
- [ ] T037 [P] [US2] `test/features/map/map_filter_test.dart` (`bloc_test`): status filter, group filter, and combined intersection derive correctly (SC-007).

**Checkpoint**: US1 + US2 work independently.

---

## Phase 5: User Story 3 — Location Sharing, Privacy & Ghost Mode (Priority: P1)

**Goal**: User shares live location (throttled), can Locate Me, and can toggle global Ghost Mode (persisted, server-enforced). Live location fans out to authorized observers via **server-side batched** events; Ghost Mode removes the marker everywhere.

**Independent Test**: A shares location → B (contact) sees A; A enables Ghost Mode → A leaves B's map ≤5 s and persists hidden after restart; non-contact C never sees A; in a large group, each client gets ≤1 batched frame per interval.

### Backend (US3)

- [X] T038 [US3] Add `set-ghost-mode.dto.ts` (`{ enabled: boolean }`) and `PATCH /map/ghost-mode` + `GET /map/ghost-mode` in `map.controller.ts`/`map.service.ts`; persist `isGhostMode`; exclude ghost users from `/visible`, `/nearby`, and fan-out.
- [X] T039 [US3] Add `shareLocation` socket handler — implemented directly in **`chat.gateway.ts`** (resolved analysis finding I2: no separate map gateway, since room membership/auth lives there): persists location + `locationUpdatedAt` immediately; if not ghost, enqueues into the batch accumulator.
- [X] T040 [US3] Implement `location-batch.service.ts` in `chat-app-backend/src/modules/map/`: in-memory `Map<roomId, Map<userId, latest>>` accumulator + single ~5 s flush timer (plain `setInterval`) emitting batched `locationUpdate { updates: [...] }` to each room (coalesce per user) — FR-006a / SC-012. Cleared on `onModuleDestroy`.
- [X] T041 [US3] Emit `locationHidden { userId }` to authorized rooms on Ghost Mode enable (and `locationUpdate` on disable if a location exists) from `map.service` (via `ChatGateway` injected through a `forwardRef` circular module relationship) (FR-012).
- [X] T042 [P] [US3] Backend batching test `chat-app-backend/src/modules/map/location-batch.service.spec.ts`: N updates for one user within an interval → one entry; one frame per room per flush (SC-012). 4 tests passing.
- [X] T043 [P] [US3] Backend gateway fan-out test in `chat.gateway.spec.ts` (`handleShareLocation` describe block): persists + enqueues per joined room; ghost-mode users persist but are never enqueued; malformed payloads ignored. 3 tests passing.

### Flutter — SocketService & location (US3)

- [ ] T044 [US3] Extend `lib/core/network/socket_service.dart`: add `onLocationUpdate(List<LocationUpdateModel>)`, `onLocationHidden(String userId)` callbacks and `shareLocation(lng, lat)` emit; register `_socket?.on('locationUpdate'/'locationHidden')` using the **IV-A safe pattern** (`if (data is! Map) return; Map<String,dynamic>.from(data)`, parse `updates` array).
- [ ] T045 [US3] Add a location service wrapper (e.g., `lib/features/map/data/datasources/` or reuse) using `geolocator`: request permission, position stream with `distanceFilter: 50` + 30 s heartbeat; expose start/stop; pause on `AppLifecycleState.paused`, resume on `resumed` (FR-006/031, R4).

### Flutter — Cubit & UI (US3)

- [ ] T046 [US3] In `MapCubit`: `startSharing()`/`stopSharing()` (emit `shareLocation`, update `isSharing`), `locateMe()` (center camera on `selfLocation`), permission handling (FR-007/032); apply batched `onLocationUpdate` via the idempotent upsert (T026); remove user on `onLocationHidden`; cancel all subscriptions in `close()`.
- [ ] T047 [US3] In `MapCubit` + repository: `toggleGhostMode()` — optimistic `isGhostMode` flip, persist to `SharedPreferences`, call `PATCH /map/ghost-mode`; hydrate from `GET /map/ghost-mode` on init (FR-011/013). On enable, stop sharing/broadcast.
- [ ] T048 [US3] Wire `lib/features/map/presentation/widgets/map_fab_column.dart`: Share-Location FAB → `startSharing/stopSharing`; Locate-Me → `locateMe`; add Ghost Mode toggle affordance → `toggleGhostMode` (no visual redesign beyond existing controls).
- [ ] T049 [P] [US3] `test/features/map/map_location_test.dart` (`bloc_test`): sharing toggles, ghost-mode optimistic + persist, batched `locationUpdate` applied idempotently, `locationHidden` removes marker.

**Checkpoint**: US1 + US2 + US3 = full P1 set (live, filterable, private, batched).

---

## Phase 6: User Story 4 — Distance-Based Discovery (Priority: P2)

**Goal**: "Nearby Only" vs "All Locations" toggles the dataset; nearby is staleness-bounded; graceful handling when self-location is unknown.

**Independent Test**: With contacts at varied distances, "Nearby Only" shows only those within radius; "All Locations" restores; with combined filters, results satisfy all; with no self-location, the distance filter is inert with a hint.

### Backend (US4)

- [X] T050 [US4] Scope `GET /map/nearby` in `chat-app-backend/src/modules/users/users.repository.ts` to `authorizedObserverIds` + exclude ghost users + add staleness filter `locationUpdatedAt >= now - 24h` (R5); keep `radius` default 10 km.
- [X] T051 [P] [US4] Backend test in `map.service.spec.ts`/`users.service.spec.ts`: nearby returns only authorized ids passed through; ghost/staleness enforced at the query level (SC-006).

### Flutter (US4)

- [ ] T052 [US4] Implement `getNearbyUsers(lat, lng, radiusKm)` in `map_remote_data_source.dart` + repository.
- [ ] T053 [US4] In `MapCubit`: `setDistanceFilter` — `nearby` re-queries `/map/nearby` (needs `selfLocation`), `all` uses `/map/visible`; emit `loading→loaded/empty`; if `selfLocation == null`, keep filter inert and surface a hint (FR-018 edge case).
- [ ] T054 [US4] Wire the distance control in `map_filter_sheet.dart` to `setDistanceFilter` (existing UI).
- [ ] T055 [P] [US4] `test/features/map/map_distance_test.dart` (`bloc_test`): nearby/all switching re-fetches; self-location-unknown handled.

**Checkpoint**: US1–US4 functional.

---

## Phase 7: User Story 5 — Smooth, Non-Laggy Rendering (Priority: P2)

**Goal**: Cluster dense markers; convert avatars to icons off the main thread with a bounded pool + cache; placeholder-first; no jank at 50+ avatars.

**Independent Test**: Dense area shows count badges that split on zoom; panning/zooming with 50+ avatars resolving stays smooth (no frame drops); failed image falls back to initial.

### Flutter (US5)

- [ ] T056 [US5] Create `lib/features/map/presentation/utils/marker_icon_factory.dart`: avatar→PNG compositing (decode cached bytes → circle + border + online dot via `image`/`dart:ui`) run via `compute()`/isolate; `BitmapDescriptor.fromBytes` on main; bounded concurrency (≤4) + in-memory cache keyed `userId+avatarUrl+isOnline` (FR-026/027/028, SC-010).
- [ ] T057 [US5] Integrate marker clustering in `MapCubit._deriveMarkers()` + `map_screen.dart`: cluster manager recompute on `onCameraIdle`; cluster badge bitmap via `widget_to_marker` (low-volume); single markers via the icon factory (FR-024/025).
- [ ] T058 [US5] Placeholder-first rendering: emit initial-on-color markers immediately, swap to image markers as the factory resolves (FR-027); fallback to initial on image failure.
- [ ] T059 [P] [US5] `test/features/map/marker_icon_factory_test.dart`: cache hit returns same descriptor; cache key varies with `isOnline`; failure path yields placeholder.

**Checkpoint**: All user stories independently functional.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T060 [P] Add/replace localization strings used by wired controls (e.g., Ghost Mode, retry, empty state) in the app's localization assets.
- [ ] T061 Remove the obsolete `lib/features/map/presentation/mock/map_mock_data.dart` and any remaining mock references once all stories consume live data.
- [ ] T062 Verify logout teardown: `MapCubit.close()` cancels all subscriptions, geolocator stream, and TTL timer; confirm no mutable `isOnline` added to singletons (Constitution IV-B/V).
- [ ] T063 [P] Run `flutter analyze` (warnings-as-errors) and backend lint; fix naming/`const`/`final` issues (Constitution VI).
- [ ] T064 Execute `specs/018-snap-map-realtime/quickstart.md` manual verification matrix end-to-end (all SC checks).

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (P1)**: no dependencies.
- **Foundational (P2)**: depends on Setup — **blocks all user stories**.
- **US1 (P3)**: depends on Foundational. MVP.
- **US2 (P4)**, **US3 (P5)**: depend on Foundational; both build on US1's `allUsers` + idempotent upsert/derive, so sequence US1 → US2/US3 (US2 and US3 are largely independent of each other).
- **US4 (P6)**: depends on Foundational + US1 (reuses load/derive); independent of US2/US3.
- **US5 (P7)**: depends on US1's `_deriveMarkers()` (replaces its marker building); best after US1, parallel to US2–US4.
- **Polish (P8)**: after all targeted stories.

### Critical foundational ordering

- T005 → T006 (schema before authorization query).
- T007–T009 (entities) → T010 (abstract repo) → T011–T014 (data) → T015–T016 (state/cubit) → T017 (DI/build_runner).
- The **idempotent upsert (T026)** is created in US1 and reused by US3 (T046) and US4 (T053) — do not duplicate.

### Parallel opportunities

- Setup: T001–T004 all [P].
- Foundational: T007/T008/T009 [P]; T011/T012 [P]; backend T005 can proceed parallel to Flutter entities.
- US1: T021/T022 (backend tests) [P]; T031/T032 (Flutter tests) [P]; backend T018–T020 parallel to Flutter T023–T030 once contracts agreed.
- Across stories after US1: a backend dev can do US3 fan-out/batching (T038–T043) while a Flutter dev does US2 filtering (T034–T037) and another does US5 rendering (T056–T059).

---

## Parallel Example: User Story 1

```bash
# Backend authorization + coarse tests in parallel:
Task: "T021 Backend authorization test in chat-app-backend/src/modules/map/map.service.spec.ts"
Task: "T022 Backend Explore coarsening test in map.service.spec.ts"

# Flutter US1 unit tests in parallel:
Task: "T031 map_cubit_test.dart (load, idempotency, TTL)"
Task: "T032 map_repository_impl_test.dart (Either mapping)"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational (critical, blocks all) → 3. Phase 3 US1 → **STOP & validate**: real authorized contacts, live presence, race-safe + self-cleaning markers, coarse Explore. Deploy/demo.

### Incremental delivery

US1 (MVP) → +US2 (filtering) → +US3 (location/Ghost/batching = full P1) → +US4 (distance) → +US5 (clustering/perf). Each increment is independently testable and adds value without breaking prior stories.

### Notes

- [P] = different files, no incomplete dependencies.
- Backend tasks live in the separate `chat-app-backend` repo working dir.
- Every new socket handler MUST follow Constitution IV-A; data layer maps to `Failure`; repos return `Either` (VII); SharedPreferences (not Hive) for flags (III).
- Commit after each task or logical group.
