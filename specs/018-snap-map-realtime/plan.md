# Implementation Plan: Snap Map Real-Time Logic

**Branch**: `018-snap-map-realtime` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/018-snap-map-realtime/spec.md`

## Summary

Replace the mock-driven Snap Map (`lib/features/map`) with a real, privacy-aware, real-time data pipeline. Build the missing Clean Architecture layers (domain/data) under the existing `map` feature, wire the existing presentation widgets to a live `MapCubit`, and extend the backend `map` module + chat gateway with authorization, Ghost Mode, and push-based location/visibility fan-out.

Technical approach (from clarifications + research):
- **Presence**: reuse the existing `userStatus` socket event (already fanned out to room members) to drive marker online/offline state — no new presence system.
- **Authorization**: a user's location is visible only to people who **share a chat room** (PRIVATE room = contact, GROUP room = group member) and/or are **mutual contacts**, minus blocked users — enforced server-side. This reuses the exact audience the presence broadcast already targets (`this.server.to(roomId)`).
- **Live location/visibility**: new socket events (`locationUpdate`, `locationHidden`) fanned out over the same room channels; client sends throttled `shareLocation` updates.
- **Server-side batching (thundering-herd guard)**: the gateway does NOT re-emit each `shareLocation` instantly. It buffers updates in an in-memory accumulator keyed by `roomId → userId → latest`, and a single timer flushes batched `locationUpdate[]` frames to each room every ~5 s (coalescing per user). Bounds emission volume as group size grows (FR-006a, SC-012).
- **Marker TTL & timestamps**: every location carries `lastUpdatedAt`. A `MapCubit` periodic cleanup timer fades/removes markers with no update inside the TTL window, killing "ghost" markers from disconnected/closed-app users (FR-003b/c, SC-009).
- **Idempotent, timestamp-ordered state (HTTP↔WS race guard)**: `MapState` upserts a marker only when the incoming `lastUpdatedAt` is strictly newer than the cached one, so a late-resolving `GET /map/nearby` can't clobber a fresher `locationUpdate` (FR-022a, SC-011).
- **Ghost Mode**: a single global boolean on the User document; when on, the server skips fan-out and emits `locationHidden`.
- **Distance**: reuse the existing `GET /map/nearby` (`$nearSphere`, 2dsphere index), now authorization-scoped.
- **Explore tab (coarse location)**: shows users with an active `SHOW_ON_MAP` status (existing flag) — never live non-contact location. The backend coarsens coordinates (truncated decimal degrees / status location) for non-contacts before responding; precise live tracking is reserved for authorized mutuals/groups (FR-001b).
- **Optimization**: marker clustering via a clustering package; avatar→`BitmapDescriptor` conversion done **off the main UI thread via Dart `Isolate`s (`compute`)** for image decode/crop/raster, with a bounded concurrency pool and an in-memory icon cache (extends the existing `widget_to_marker` approach) (FR-026, SC-010).

## Technical Context

**Language/Version**: Dart 3 / Flutter (stable); Backend TypeScript / NestJS (Node 20)
**Primary Dependencies**: Flutter — `flutter_bloc`, `google_maps_flutter`, `widget_to_marker`, `cached_network_image`, `geolocator` (device location/permission), `fpdart`, `get_it`/`injectable`, `equatable`, `shared_preferences`, a marker clustering helper (`google_maps_cluster_manager` or equivalent), `dart:isolate`/`compute` (off-thread icon work). Backend — `@nestjs/websockets` (Socket.IO), `@nestjs/mongoose` (Mongoose, `2dsphere`), `class-validator`, `@nestjs/schedule` or a plain `setInterval` timer for the batch flush.
**Storage**: Backend MongoDB (`User.location` GeoJSON Point + `2dsphere`; new `User.isGhostMode`). Flutter — `SharedPreferences` for the persisted Ghost Mode + share-location flags (lightweight booleans per Constitution III); map markers are ephemeral/in-memory (not persisted to SQLite — locations are volatile real-time data, offline display is not required).
**Testing**: Flutter `flutter_test` + `bloc_test` + `mocktail` (cubit/repository unit tests, as in `test/features/status`); Backend Jest (`*.spec.ts`) for service/gateway authorization.
**Target Platform**: iOS 15+ / Android (mobile app); NestJS server.
**Project Type**: Mobile app (Flutter, Clean Architecture) + existing NestJS backend.
**Performance Goals**: Filter apply < 300 ms (SC-004); presence/Ghost reflect within 5 s (SC-002/003); smooth interaction with ≥100 markers in viewport (SC-005); 60 fps map panning while avatar icons resolve; no dropped-frame jank converting 50+ avatars concurrently (SC-010, off-thread); batched location emission ≤ 1 frame/recipient/interval regardless of group size (SC-012).
**Constraints**: No UI redesign (presentation widgets are fixed contract); server-side authorization mandatory (SC-001/008); coarse location for non-contacts on Explore (FR-001b); marker TTL cleanup to prevent ghost markers (FR-003c); idempotent timestamp-ordered marker updates to survive HTTP↔WS races (FR-022a); server-side batching of location fan-out (FR-006a); avatar→icon conversion off the main thread via isolates (FR-026); Socket.IO map type-safety rule (IV-A); WebSocket-only transport (IV); no Hive (III).
**Scale/Scope**: Contact-list scale (tens–low hundreds of visible users per map); single new Flutter feature layer + targeted backend extension.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature split into `presentation` (existing widgets + new `MapCubit`), `domain` (`MapUser`, `MapFilter`, repository abstractions), `data` (models, remote datasource over Dio+Socket, repository impl). ✅
- [x] **II. State Management**: `MapCubit` (Cubit) with an `Equatable` `MapState`; dependencies constructor-injected via `injectable`. The existing cubit already uses Cubit+Equatable. ✅
- [x] **III. Offline-First / Storage**: Real-time location is volatile and intentionally NOT persisted to SQLite (offline map display is out of scope per spec). Ghost Mode / share-location booleans use `SharedPreferences` (correct per Constitution III — **not Hive**, which is forbidden). ✅ *(The plan template's "Key-value uses Hive" line is corrected to SharedPreferences per the constitution.)*
- [x] **IV. Socket.io**: All real-time logic flows through the singleton `SocketService`; new events follow the **IV-A type-safety rule** (`if (data is! Map) return; final map = Map<String,dynamic>.from(data);`) and are idempotent (last-write-wins per userId). Presence reuse honors **IV-B** (backend is source of truth; no mutable `isOnline` in singletons). ✅
- [x] **V. Teardown**: `MapCubit` cancels all `StreamSubscription`s, the geolocator position stream, AND the periodic marker-TTL cleanup `Timer` in `close()`; clears socket callbacks it registered; tears down any spawned isolate / `compute` work is fire-and-forget and self-completing. Backend batch-flush timer is cleared on gateway/module destroy. ✅
- [x] **Code Quality**: snake_case files, `const`/`final`, no gratuitous comments. ✅
- [x] **Error Handling**: Data layer maps exceptions to `Failure` subclasses; repository returns `Either<Failure, T>` (`fpdart`); presentation shows friendly empty/error states (FR-029). ✅

**Result: PASS** — no violations; Complexity Tracking not required.

## Project Structure

### Documentation (this feature)

```text
specs/018-snap-map-realtime/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (REST + socket events)
│   ├── rest-api.md
│   └── socket-events.md
└── checklists/
    └── requirements.md  # from /speckit-specify
```

### Source Code (repository root)

```text
lib/features/map/
├── data/
│   ├── datasources/
│   │   └── map_remote_data_source.dart      # NEW: Dio (/map/*) + Socket events
│   ├── models/
│   │   ├── map_user_model.dart              # NEW
│   │   └── location_update_model.dart       # NEW
│   └── repositories/
│       └── map_repository_impl.dart         # NEW: Either<Failure,T>, fan-in streams
├── domain/
│   ├── entities/
│   │   ├── map_user.dart                    # NEW (replaces MockUser/MockMapMarker)
│   │   ├── map_filter.dart                  # NEW (status/group/distance)
│   │   └── map_group.dart                   # NEW
│   └── repositories/
│       └── map_repository.dart              # NEW (abstract)
└── presentation/
    ├── bloc/
    │   ├── map_cubit.dart                   # REWRITE: live data, filters, location
    │   └── map_state.dart                   # EXTEND: filter + location + status
    ├── pages/map_screen.dart                # WIRE existing widget to real data
    ├── utils/
    │   └── marker_icon_factory.dart         # NEW: off-thread (compute/Isolate) avatar→BitmapDescriptor + in-memory cache (FR-026)
    └── widgets/                             # EXISTING — wire callbacks, no redesign
        ├── map_filter_sheet.dart            # lift local state → cubit
        ├── map_fab_column.dart              # wire Share/Locate/GhostMode
        └── map_avatar_marker.dart           # reuse for icon generation

test/features/map/                           # NEW: cubit + repository + marker_icon_factory tests

# Backend (chat-app-backend)
src/modules/map/
├── map.controller.ts                        # EXTEND: ghost-mode + /visible + /explore (coarse) endpoints; scope nearby
├── map.service.ts                           # EXTEND: authorization, ghost mode, coarse-location for non-contacts (FR-001b)
├── map.gateway.ts                           # NEW (or extend chat.gateway): shareLocation → buffer
├── location-batch.service.ts               # NEW: in-memory accumulator + ~5s flush timer → batched locationUpdate[] (FR-006a)
└── dto/
    ├── update-location.dto.ts               # EXISTING
    └── set-ghost-mode.dto.ts                # NEW
src/modules/users/                           # EXTEND: isGhostMode + locationUpdatedAt fields + authorized-observers query
```

**Structure Decision**: Extend the **existing** `lib/features/map` feature in place — the presentation layer already exists; this plan adds the missing `domain` and `data` layers and rewrites the cubit. Backend work extends the existing `map` module and reuses the `chat.gateway` presence/room infrastructure rather than introducing a parallel system.

## Complexity Tracking

> No constitution violations — section intentionally empty.
