# Phase 1 Data Model: Snap Map Real-Time Logic

Entities span the Flutter domain layer (entities), Flutter data layer (models/DTOs), and the backend (Mongoose schema deltas). Field names use the conventions of each side (camelCase Dart, Mongoose props).

## Backend schema deltas

### User (extend `user.schema.ts`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `isGhostMode` | `boolean` | `false` | NEW. Global Ghost Mode (FR-011, R3). When true, user is excluded from all authorized map results and fan-out. |
| `location` | `Location` (GeoJSON Point) | — | EXISTING. `{ type:'Point', coordinates:[lng,lat] }`, `2dsphere` index. |
| `locationUpdatedAt` | `Date` | — | NEW. Timestamp of last location write; drives the 24 h staleness window for "Nearby" (R5). |
| `isOnline` | `boolean` | `false` | EXISTING. Presence source of truth (Constitution IV-B). |
| `blockedUsers` | `ObjectId[]` | `[]` | EXISTING. Subtracted from authorized observers (FR-014). |
| `syncedContacts` | `string[]` | `[]` | EXISTING. Drives mutual-contact computation. |

No new collections. "Groups/Circles" reuse `ChatRoom` where `type = GROUP` (`chat-room.schema.ts`).

### Authorization derivation (server, no schema)

`authorizedObserverIds(U)` =
`( ⋃ participants of ChatRoom where U ∈ participants )`
`∪ findMutualContactIds(U)`
`− U.blockedUsers − { users whose blockedUsers ∋ U }`
`− { self }`.

`visibleMapUsers(viewer V)` = users U where `V ∈ authorizedObserverIds(U)` AND `U.isGhostMode == false` AND `U.location` present.

**Coarse-location rule (Explore, FR-001b)**: for the Explore path, when U is NOT in `authorizedObserverIds(V)` (i.e., not a mutual / shared-group contact), the server emits `coarseLocation(U)` = coordinates truncated to 2 decimal places (≈1.1 km grid), or the attached status location. Precise `U.location` is emitted only on the Following path to authorized observers. `lastUpdatedAt` is **server-assigned** on every location write (single clock for cross-client ordering, R11).

## Flutter domain entities

### MapUser (`domain/entities/map_user.dart`)
Replaces `MockUser` + `MockMapMarker`. Extends `Equatable`.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | User id |
| `name` | `String` | Display name |
| `avatarUrl` | `String?` | Resolve via `UrlUtils.resolveMediaUrl` (Constitution VIII-A) before rendering |
| `initial` | `String` | Fallback glyph when no avatar |
| `avatarBgColor` | `int` (ARGB) | Fallback bg color (domain stays Flutter-free except equatable → store as int, map to `Color` in widget) |
| `isOnline` | `bool` | From presence stream |
| `latitude` | `double` | Last-known |
| `longitude` | `double` | Last-known |
| `lastUpdatedAt` | `DateTime?` | Server-assigned timestamp of last location refresh. Drives idempotent ordering (FR-022a) AND client TTL cleanup (FR-003c). Maps from backend `locationUpdatedAt`. |
| `isCoarse` | `bool` | True when coordinates were coarsened for Explore (non-contact); precise tracking disabled for this marker. |
| `groupIds` | `List<String>` | GROUP room ids this user shares with viewer (group filter) |
| `isCurrentUser` | `bool` | Self marker |

### MapFilter (`domain/entities/map_filter.dart`)
Value object, Equatable.

| Field | Type | Values | Default |
|-------|------|--------|---------|
| `status` | `MapStatusFilter` enum | `all` / `online` / `offline` | `all` |
| `groupId` | `String?` | null = All groups, else specific GROUP id | `null` |
| `distance` | `MapDistanceFilter` enum | `all` / `nearby` | `all` |
| `nearbyRadiusKm` | `double` | — | `10.0` (R6) |

`bool matches(MapUser u, {LatLng? self})` applies status + group locally; distance is enforced by which dataset (`/map/nearby` vs full) was fetched.

### MapGroup (`domain/entities/map_group.dart`)
Sourced from the user's GROUP chat rooms (replaces mock group list).

| Field | Type |
|-------|------|
| `id` | `String` |
| `name` | `String` |
| `memberCount` | `int` |
| `avatarUrl` | `String?` |
| `initials` | `String` |

## Flutter data models (DTOs)

### MapUserModel (`data/models/map_user_model.dart`)
`fromJson` / `toEntity`. JSON keys match backend response (`_id`→id, `location.coordinates`→[lng,lat], `isOnline`, `locationUpdatedAt`, `sharedGroupIds`). Follows the `StatusModel` pattern.

### LocationUpdateModel (`data/models/location_update_model.dart`)
Parses the `locationUpdate` socket payload using the IV-A safe pattern:
`userId`, `longitude`, `latitude`, `isOnline`, `updatedAt`.

## Flutter presentation state

### MapState (extend `presentation/bloc/map_state.dart`, Equatable)

| Field | Type | Notes |
|-------|------|-------|
| `status` | `MapViewStatus` enum | `loading` / `loaded` / `empty` / `error` (FR-029) |
| `allUsers` | `List<MapUser>` | Authorized set from backend; mutated by live events |
| `filter` | `MapFilter` | Active filter (FR-021 retained for session) |
| `googleMarkers` | `Set<Marker>` | Derived: clustered + filtered (built from `allUsers`) |
| `groups` | `List<MapGroup>` | For the filter sheet |
| `selfLocation` | `LatLng?` | Device location |
| `isSharing` | `bool` | Location sharing active |
| `isGhostMode` | `bool` | Mirror of backend flag (persisted) |
| `permissionGranted` | `bool` | Device location permission |
| `selectedUser` | `MapUser?` | For the user-detail sheet (FR-030) |
| `selectedTab` | `MapTab` enum | `following` / `explore` |
| `mapType` | `MapType` | normal/satellite (existing) |
| `failure` | `Failure?` | For error display |

State transitions:
- `loading → loaded` (data fetched, ≥1 visible) / `→ empty` (0 after privacy+filter) / `→ error` (Failure).
- Filter change (status/group): re-derive `googleMarkers` from `allUsers` — no fetch.
- Distance filter change: re-fetch (`/map/nearby` ↔ authorized full set) → `loading → loaded/empty`.
- Live `userStatus`: update matching `MapUser.isOnline`, re-derive markers (debounced, FR-004).
- Live `locationUpdate` (batched array): for each item, **idempotent upsert** — apply only if `item.lastUpdatedAt` strictly newer than cached (FR-022a); then re-derive.
- Live `locationHidden`: remove `MapUser`, re-derive.
- Initial-load merge: applying the `GET` response also uses the strictly-newer rule, so a late HTTP response never clobbers a fresher socket value (SC-011).
- TTL tick (`Timer.periodic` ~60 s): mark markers with `now − lastUpdatedAt > 2 h` as fading, then remove; re-derive (FR-003c, SC-009). Timer cancelled in `close()`.
- Ghost Mode toggle: optimistic `isGhostMode` flip + persist; on confirm, self stops broadcasting.

## Validation rules

- Coordinates: `-180 ≤ lng ≤ 180`, `-90 ≤ lat ≤ 90` (existing `UpdateLocationDto`).
- `nearbyRadiusKm > 0`.
- Status filter `offline` excludes users with `isOnline == true`; `online` excludes `isOnline == false`.
- A `MapUser` with null/empty location is never added to `allUsers`.
- Ghost Mode true ⇒ self excluded from every other viewer's `allUsers` (server-enforced).
- Blocked users never appear in `allUsers` in either direction (server-enforced).
- Idempotency: a marker is overwritten ONLY IF incoming `lastUpdatedAt` is strictly newer than the cached value (applies to both HTTP load and socket updates) — FR-022a.
- TTL: a marker with `now − lastUpdatedAt > 2 h` and no fresh update MUST be removed by the cleanup tick — FR-003c.
- Explore non-contacts: precise coordinates MUST NOT reach the client; only `isCoarse` markers — FR-001b.
