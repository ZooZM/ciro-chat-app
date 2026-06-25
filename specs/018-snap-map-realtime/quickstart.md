# Quickstart: Snap Map Real-Time Logic

How to build, wire, and validate this feature. Assumes the existing `lib/features/map` presentation layer and the NestJS `map` module are in place.

## Prerequisites

- Flutter: add `geolocator` and a clustering helper (`google_maps_cluster_manager`) to `pubspec.yaml`. `google_maps_flutter`, `widget_to_marker`, `cached_network_image`, `fpdart`, `injectable`, `shared_preferences` already present.
- iOS/Android location permission strings (`NSLocationWhenInUseUsageDescription`, `ACCESS_FINE_LOCATION`).
- Backend: MongoDB with the `2dsphere` index on `User.location` (already defined).

## Build order (vertical slices, by user story)

1. **US1 — live contacts (P1)**: Backend `/map/visible` + authorization in `map.service`; add `isGhostMode`/`locationUpdatedAt` to User schema. Flutter domain (`MapUser`, repository abstract) + data (`MapUserModel`, remote datasource, repo impl) + rewrite `MapCubit` to fetch authorized users and subscribe to `userStatus`. Wire `map_screen` markers to live data.
2. **US3 — location & Ghost Mode (P1)**: `geolocator` capture + permission; `shareLocation` emit (throttled); `PATCH /map/ghost-mode` + `locationHidden`/`locationUpdate` fan-out; wire Share/Locate/Ghost FABs; persist Ghost flag in SharedPreferences.
3. **US2 — filtering (P1)**: lift `MapFilterSheet` local state into `MapFilter` on the cubit; `GET /map/groups`; client-side status+group derive.
4. **US4 — distance (P2)**: distance filter toggles `/map/nearby` vs `/map/visible`; handle "self location unknown" case.
5. **US5 — clustering & perf (P2)**: cluster manager on `onCameraIdle`; `marker_icon_factory` doing avatar compositing in `compute`/isolate with a bounded pool + in-memory `BitmapDescriptor` cache; placeholder-first icon generation.

Cross-cutting hardening (fold into the slices above):
- **Server-side batching** (`location-batch.service.ts`): accumulate `shareLocation` → flush batched `locationUpdate[]` every ~5 s (with US3).
- **Marker TTL** (`MapCubit` `Timer.periodic` 60 s, remove > 2 h stale) + **idempotent strictly-newer upsert** on `lastUpdatedAt` (with US1/US3).
- **Coarse location** for Explore non-contacts in `map.service` (with the Explore tab work).

## Manual verification (maps to spec acceptance)

| Check | Steps | Expected |
|-------|-------|----------|
| Live presence (US1) | Open Map as A with contact B sharing location; connect/disconnect B | B's marker appears; status flips within 5 s (SC-002) |
| Authorization (US3/SC-001) | As non-contact C, query map for A | A never returned |
| Ghost Mode (US3/SC-003) | A enables Ghost Mode | A's marker leaves B's map ≤5 s; persists after A restarts |
| Filter status (US2) | Select "Online Only" | Only online markers; instant (<300 ms, SC-004) |
| Filter group (US2) | Select "Tech Team" | Only that group's members |
| Combined filters (SC-007) | Online + Tech Team + Nearby | Intersection only |
| Distance (US4) | Toggle Nearby/All | Distant contacts hide/reappear |
| Blocked (SC-008) | Block a contact | Mutually invisible on map |
| Clustering (US5) | Zoom out over dense area | Count badge; zoom in splits |
| Icon perf (US5/SC-010) | Load 50+ avatars; pan/zoom while images load | No frame jank (off-thread); placeholder → image |
| Ghost markers (SC-009) | Force-quit a sharing contact (no disconnect event) | Marker fades & removes within one TTL cycle (~2 h cap; lower TTL in test) |
| HTTP↔WS race (SC-011) | Delay `GET /map/nearby`; deliver newer `locationUpdate` first | Stale HTTP response does NOT move the marker back |
| Batching (SC-012) | N contacts in one group all moving | Each client gets ≤1 batched frame per ~5 s interval, not N×/move |
| Coarse Explore (FR-001b) | View Explore tab as a non-contact | Coordinates are grid-truncated (`isCoarse`), never precise |

## Automated tests

- **Flutter** (`test/features/map/`): `bloc_test` for `MapCubit` (load→loaded/empty/error; filter derive; live `userStatus`/`locationUpdate`/`locationHidden` mutation; Ghost toggle). Repository unit tests with `mocktail` for `Either<Failure,T>` mapping. Follow `test/features/status` patterns.
- **Backend** (`*.spec.ts`): `map.service` authorization (authorized vs unauthorized vs blocked vs ghost vs stale) + Explore coarsening (non-contact coords truncated); `location-batch.service` (coalesces multiple updates/user to one per flush; one frame/room/interval); `map.gateway` fan-out targeting (only shared-room channels receive `locationUpdate`).
- **Flutter idempotency/TTL**: `bloc_test` that a stale-timestamp update is ignored (SC-011) and that the TTL tick removes an aged marker (SC-009).

## Constitution gates to honor while coding

- IV-A socket type-safety on every new handler (including the batched `updates` array parse).
- IV-B: do not add mutable `isOnline` to any singleton; backend is source of truth.
- V: cancel all subscriptions + geolocator stream + the TTL `Timer.periodic` in `MapCubit.close()`; clear the backend batch-flush timer on module destroy.
- Idempotency (mirrors II "never regress"): apply marker updates only when `lastUpdatedAt` is strictly newer.
- Off-thread icon work via `compute`/isolate (pure image compositing — never widget raster in an isolate).
- VII: data layer → `Failure`; repo → `Either`; UI shows friendly empty/error.
- VIII-A: resolve avatar URLs via `UrlUtils.resolveMediaUrl`; use `CachedNetworkImage`.
- III: SharedPreferences for flags — never Hive.
