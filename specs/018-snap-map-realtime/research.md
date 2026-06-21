# Phase 0 Research: Snap Map Real-Time Logic

All open questions from the spec's deferred items and the Technical Context are resolved below. The four clarification answers (Session 2026-06-21) are treated as fixed inputs.

## R1. Authorization model — who may see a user on the map

**Decision**: Authorized observers of user U = (participants of any chat room U belongs to) ∪ (mutual contacts of U), minus U's blocked users and users who blocked U. Computed and enforced **server-side**.

**Rationale**: The chat gateway already fans out the `userStatus` presence event to `this.server.to(roomId)` for every room U is in (`chat.gateway.ts:117-134`). PRIVATE rooms encode 1:1 contacts; GROUP rooms encode "circles". Reusing room channels means location fan-out hits exactly the authorized audience with zero new routing. `findMutualContactIds` (`users.repository.ts:130`) covers contacts who haven't opened a room yet. `blockedUsers` already exists on the User schema and must be subtracted.

**Alternatives considered**:
- *Separate opt-in map audience list* (like `defaultStatusAudience`) — rejected by clarification Q2 (no separate audience entity); more data + UI for no required benefit.
- *Return all nearby users* (current `getNearbyUsers` behavior) — rejected: violates FR-010/SC-001 (would leak strangers' locations).

## R2. Real-time transport for location & visibility

**Decision**: Push over the existing Socket.IO gateway. New events:
- Inbound: `shareLocation { longitude, latitude }` (client → server, throttled).
- Outbound: `locationUpdate { userId, longitude, latitude, isOnline, updatedAt }` and `locationHidden { userId }` (server → authorized room channels).
Ghost-mode toggle uses REST (`PATCH /map/ghost-mode`) since it is a durable setting, then the server emits `locationHidden`/`locationUpdate` as a side effect.

**Rationale**: Clarification Q3 chose push over the existing channel. Constitution IV mandates the singleton `SocketService`, WebSocket-only. Fan-out reuses room targeting (R1). Presence already arrives via `userStatus`, so the client merges `userStatus` + `locationUpdate` per userId.

**Alternatives**: Polling `/map/nearby` (laggy, heavier — rejected Q3); a dedicated namespace (unnecessary — the default gateway already auto-joins room channels on connect, `chat.gateway.ts:96-109`).

**Socket type-safety**: Every new client handler MUST follow Constitution IV-A:
```dart
_socket?.on('locationUpdate', (data) {
  if (data is! Map) return;
  final map = Map<String, dynamic>.from(data);
  // ...
});
```

**Server-side batching (thundering-herd guard)**: `shareLocation` is NOT re-emitted instantly. The gateway writes each update into an in-memory accumulator (`Map<roomId, Map<userId, LatestLocation>>`) and a single `setInterval`/`@Interval(5000)` timer flushes one `locationUpdate` batch frame per room per tick, coalescing repeated movement of the same user to the latest value (FR-006a). This caps emission at ~1 frame/recipient/interval regardless of group size (SC-012) and decouples DB-write cadence from fan-out cadence. The persisted location write (and `locationUpdatedAt`) still happens immediately on receipt; only the fan-out is batched. The outbound batch payload is `locationUpdate { updates: [{userId, longitude, latitude, isOnline, updatedAt}] }` (array form); the client iterates and applies the idempotent rule (R11) per item.

**Alternatives**: Instant per-event fan-out (overwhelms gateway in large groups — rejected); per-user timers (timer explosion — rejected in favor of one flush timer per process).

## R3. Ghost Mode storage & semantics

**Decision**: Add `isGhostMode: boolean` (default `false`) to the User schema (backend source of truth). Client mirrors it in `SharedPreferences` for instant startup state and offline read, but the server value wins. When `isGhostMode` is true: `shareLocation` is ignored for fan-out, `getNearbyUsers`/authorized queries exclude the user, and the server emits `locationHidden { userId }`.

**Rationale**: Clarification Q4 = global single toggle. Persistence requirement FR-013 satisfied by the DB field; SharedPreferences (Constitution III) handles the lightweight client flag — **not Hive**.

**Alternatives**: Per-contact exclusion list — rejected by Q4. Client-only ghost flag — rejected: server must enforce so location is never delivered (FR-015).

## R4. Device location capture, permission & throttling

**Decision**: Use `geolocator` for permission + position stream. Broadcast cadence: emit `shareLocation` on a distance filter of **~50 m** significant movement OR a **30 s** heartbeat while sharing & foregrounded, whichever first. Pause the stream on `AppLifecycleState.paused`; resume on `resumed` (mirrors `SocketService` lifecycle, Constitution IV).

**Rationale**: Balances freshness (SC-002) with battery/bandwidth (FR-006/FR-031). 50 m / 30 s is a standard live-location cadence (comparable to WhatsApp Live Location). `geolocator` is the de-facto Flutter geolocation package and exposes `LocationSettings(distanceFilter:)`.

**Alternatives**: Continuous high-frequency stream (battery drain — rejected); fixed 5 s timer regardless of movement (wasteful when stationary — rejected).

## R5. Staleness window for "Nearby"

**Decision**: Locations are displayable as last-known indefinitely, but excluded from "Nearby Only" results if `updatedAt` is older than **24 h**. The `$nearSphere` query adds `location.updatedAt >= now-24h` (tracked via a per-update timestamp; see data-model).

**Rationale**: Spec assumption flagged this for planning. 24 h keeps the nearby view meaningful without dropping recently-active contacts who paused sharing briefly.

**Alternatives**: No staleness (stale pins pollute "nearby" — rejected); aggressive 1 h window (drops legitimately idle contacts — rejected).

## R6. "Nearby" radius default

**Decision**: Default radius **10 km**, matching the existing `getNearbyUsers` default (`map.controller.ts:42`). Surfaced as the `radius` query param so it stays tunable.

**Rationale**: Reuse the established backend default; no need to ask the user (deferred in clarify).

## R7. Marker clustering

**Decision**: Use a Google-Maps cluster manager (`google_maps_cluster_manager` or equivalent that yields a `Set<Marker>` for `google_maps_flutter`). Cluster items implement `ClusterItem` with `LatLng`; the manager recomputes clusters on camera idle and emits either an avatar marker (single) or a count-badge marker (cluster). Cluster badge bitmap is generated the same way as avatars (widget → `BitmapDescriptor`).

**Rationale**: FR-024/025. `google_maps_flutter` has no built-in clustering; a cluster manager driven by `onCameraIdle` is the standard pattern and integrates with the existing `markers` set the screen already consumes (`map_screen.dart:45`).

**Alternatives**: Hand-rolled grid clustering (reinvents the package — rejected); server-side clustering (over-engineered at contact-list scale — rejected).

## R8. Avatar → BitmapDescriptor without UI lag (off-thread via isolates)

**Decision**: A dedicated `marker_icon_factory.dart` owns icon generation with three layers:
1. **Off-main-thread work**: image bytes decode, crop-to-circle, border/online-dot compositing, and PNG raster run inside a Dart **isolate via `compute()`** (raw `Uint8List` bytes in → `Uint8List` PNG out — isolate-safe; no Flutter handles cross the boundary). Only the final cheap `BitmapDescriptor.fromBytes(...)` runs on the main isolate. Keeps 50+ concurrent conversions off the UI thread (FR-026, SC-010).
2. **Bounded concurrency**: a small worker pool / semaphore (e.g., ≤4 in-flight `compute` calls) so a burst of 50+ avatars does not spawn 50 isolates at once.
3. **In-memory cache**: generated descriptors cached in `Map<String, BitmapDescriptor>` keyed by `userId + avatarUrl + isOnline` so panning/zoom never rebuilds them (FR-028). The initial-on-color placeholder marker shows first, then swaps to the image marker when the isolate returns (FR-027).

> **Isolate caveat**: `widget_to_marker` rasterizes a Flutter widget and CANNOT run in a background isolate (no `RenderObject`/`BuildContext` off the main thread). The avatar marker is therefore produced by **pure image compositing in the isolate** (decode cached bytes → draw circle + border + online dot via the `image` package / `dart:ui` byte APIs), NOT by widget rasterization. `widget_to_marker` is retained only for the low-volume cluster count-badge, generated on demand on the main isolate.

**Rationale**: The current cubit builds icons async but still on the main isolate (widget raster) — that is the jank source at scale. Moving the heavy pixel work into `compute` is the only way to hit SC-010 with 50+ images. Cache key includes `isOnline` because the border color changes with presence.

**Alternatives**: Widget rasterization inside an isolate (impossible — no render tree off-main-thread — rejected); synchronous icon build (freezes UI — rejected, the current risk); pre-baking all icons up front (wasteful for off-screen users — rejected in favor of lazy + bounded + cache).

## R9. Explore tab data source

**Decision**: Explore = users with an active `SHOW_ON_MAP` status. Reuse the status repository's map-visible query (`status.repository.ts:42` already groups `PUBLIC`/`SHOW_ON_MAP`) exposed via a map-scoped endpoint or the existing status feed filtered to `SHOW_ON_MAP`. These render as status markers, never as live non-contact location. For any user who is NOT a mutual/shared-group contact of the viewer, the backend returns a **coarse location**: coordinates truncated to ~2 decimal places (≈1.1 km grid) — or the status's own attached location — computed server-side before the response leaves the backend (FR-001b). Precise live coordinates are emitted only on the Following path to authorized observers.

**Rationale**: Clarification Q1 + privacy hardening. Returning precise coordinates for non-contacts who merely toggled `SHOW_ON_MAP` is a stalking/triangulation risk; coarsening to a ~1 km grid preserves the "someone's around here" discovery value without exposing a trackable point. Truncation (not rounding) avoids edge bias and is trivial server-side. Reuses 014-status-feature-integration plumbing (the nearby query already flags `showOnMap` statuses, `users.repository.ts:177-184`).

**Alternatives**: Live stranger discovery with precise coords (privacy violation — rejected Q1 + FR-001b); client-side coarsening (rejected — precise data would still leave the server, defeating FR-015); random jitter instead of grid truncation (non-deterministic, can still be averaged out over time — rejected in favor of stable grid snapping).

## R10. State shape & filter application

**Decision**: `MapState` (Equatable) holds: `allUsers` (authorized set from backend), `filter` (`MapFilter` value object), derived `visibleMarkers`/`googleMarkers`, `selfLocation`, `isSharing`, `isGhostMode`, `status` (loading/loaded/empty/error), `selectedUser`, `mapType`, `selectedTab`. Status & group filtering are applied **client-side** over `allUsers` (instant, < 300 ms, SC-004); changing the distance filter triggers a backend re-query (`/map/nearby` vs full authorized set). Live `userStatus`/`locationUpdate`/`locationHidden` events mutate `allUsers`, then re-derive visible markers through the active filter (FR-022).

**Rationale**: Client-side status/group filtering meets the instant-update requirement; distance is inherently a server geo-query. Single derive function keeps live events and filter changes consistent.

**Alternatives**: Server round-trip per filter change (too slow for SC-004 — rejected); all filtering server-side (chatty, breaks 300 ms target — rejected).

## R11. Marker TTL cleanup + idempotent timestamp ordering (lifecycle & race safety)

**Decision**: Two related rules anchored on a `lastUpdatedAt` (`DateTime`) carried by every location record (initial load + each live update):

- **Idempotent ordering (HTTP↔WS race guard)**: `MapState` upserts a `MapUser` ONLY IF the incoming `lastUpdatedAt` is strictly newer than the cached entry's (`incoming.lastUpdatedAt.isAfter(existing.lastUpdatedAt)`). A late-resolving `GET /map/nearby`/`/visible` therefore cannot overwrite a fresher `locationUpdate` that already arrived over the socket, and a stale re-delivered socket frame is a no-op (FR-022a, SC-011). This is the marker-coordinate analogue of the constitution's status-promotion "never regress" rule (II).
- **TTL cleanup (ghost-marker guard)**: `MapCubit` runs a periodic `Timer.periodic` (e.g., every 60 s) that, for each cached marker, compares `now − lastUpdatedAt` against a TTL (default **2 hours**). Markers past TTL with no fresh update are visually faded then removed, so users who dropped connection / killed the app don't linger forever (FR-003b/c, SC-009). The timer is cancelled in `close()` (Constitution V). The authoritative removal still comes from `locationHidden`/offline events; TTL is the backstop for ungraceful disconnects where no event fires.

**Rationale**: Real-time maps must converge to truth even with out-of-order/lost messages. Timestamp-gated upserts make every update idempotent and order-independent; the TTL sweep handles the "no goodbye event" case (force-quit, network loss) that `handleDisconnect` may miss or that arrives before the client subscribed.

**Alternatives**: Sequence numbers instead of timestamps (needs server-issued monotonic counter per user; timestamps already required by FR-003b so reuse them — rejected as redundant); server-side heartbeat reaper only (doesn't help a client that holds a stale marker from before it connected — rejected in favor of client TTL backstop); last-write-wins without timestamp check (the exact race bug being fixed — rejected).

> **Clock note**: `lastUpdatedAt` is **server-assigned** on every write so all clients compare against a single clock; client device time is never used for ordering.

## Resolved unknowns summary

| Item | Resolution |
|------|-----------|
| Authorization audience | Shared-room participants ∪ mutual contacts − blocked (server-enforced) |
| RT transport | Socket.IO push over existing room channels, **server-side batched (~5 s)** to avoid thundering herd |
| Ghost Mode | Global `isGhostMode` boolean on User; server-enforced |
| Location cadence | 50 m movement or 30 s heartbeat; pause on background |
| Staleness window | 24 h for "Nearby" eligibility |
| Nearby radius | 10 km default (tunable) |
| Clustering | cluster-manager over `google_maps_flutter` |
| Icon perf | off-thread `compute`/isolate compositing + bounded pool + in-memory cache + placeholder-first |
| Explore tab | `SHOW_ON_MAP` statuses; **coarse (truncated) location** for non-contacts |
| Filtering | status/group client-side; distance server-side |
| Marker TTL | client `Timer.periodic` (60 s) fades/removes markers older than 2 h (ghost-marker backstop) |
| Race safety | idempotent upsert gated on server-assigned `lastUpdatedAt` (strictly-newer wins) |
