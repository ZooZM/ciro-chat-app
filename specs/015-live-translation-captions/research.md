# Phase 0 Research: Live Translation Captions Overlay (Frontend MVP)

No `NEEDS CLARIFICATION` markers remain in the Technical Context — this codebase's
conventions (Clean Architecture + Cubit + LiveKit + Socket.IO) are well established and
the backend contracts are already implemented and documented. This file records the key
design decisions and the alternatives considered.

## 1. State isolation for high-frequency captions

**Decision**: A single per-call `TranslationCubit` (constitution II: Cubit) owns a
`Map<String, ValueNotifier<Caption?>>` keyed by `speakerId`, created lazily via
`captionNotifier(speakerId)`. Caption updates call `.value =` on the relevant notifier —
never `emit()`. The Cubit's normal `Equatable` `state` (`TranslationState`) only tracks
coarse per-speaker subscription status (`off | pending | active | denied | unavailable`),
which changes a handful of times per call (user toggles, denial/unavailable events).

**Rationale**:
- FR-007/FR-015 and SC-003/SC-007 require zero video-grid/tile rebuilds from caption
  updates arriving multiple times/second.
- `ValueNotifier` + `ValueListenableBuilder` is the cheapest Flutter primitive for "one
  small subtree rebuilds on value change" and is **already used in this codebase** for
  exactly this kind of high-frequency, narrow-scope UI binding:
  `SocketService.isConnectedNotifier` (constitution IV file, line 15) drives a
  "Connecting…" banner without rebuilding the chat screen.
- Keeping a single Cubit (not one per tile) avoids dynamic `BlocProvider` lifecycle churn
  as participants join/leave or the grid re-paginates.

**Alternatives considered**:
- *Caption text inside `TranslationState` + narrow `BlocBuilder` per tile with
  `buildWhen`*: Still re-runs `Equatable.props` list comparisons and the `buildWhen`
  predicate on every interim update for every tile's `BlocBuilder`; strictly more
  overhead than a direct `ValueNotifier` set, for no behavioral benefit.
- *One `Cubit`/`BlocProvider` per video tile*: Requires creating/disposing a Cubit
  whenever a participant tile is added/removed/re-ordered (join, leave, grid re-layout,
  pagination) — significant added lifecycle complexity vs. one map entry.
- *Plain `setState` in `_ParticipantTile`*: `_ParticipantTile` is currently a
  `StatelessWidget` rebuilt from `GroupCallScreen`'s `setState`; converting it to
  `StatefulWidget` and calling `setState` per caption would still couple caption updates
  to the tile's full rebuild (acceptable for some features but exactly what FR-007
  forbids here) and offers no isolation benefit over `ValueListenableBuilder`.

## 2. Data-channel ingestion point

**Decision**: Ingestion lives entirely in the **data layer** so the UI stays decoupled
from raw LiveKit events (Constitution I). `TranslationCubit.attachRoom(Room room,
{required String roomId})` is called once after `_room!.connect(...)` in
`GroupCallScreen._connectToRoom`; it subscribes to
`TranslationRepository.attachRoom(room)`, which returns a `Stream<Caption>`. Inside the
repository, `TranslationDataChannelDataSource.attach(room)` creates its **own**
`EventsListener<RoomEvent>` (`room.createListener()`), filters
`DataReceivedEvent`s on `event.topic == 'translation'`, UTF-8 decodes `event.data`,
`jsonDecode`s it, and — using the same defensive pattern as constitution IV-A
(`data is! Map` guard, then `Map<String, dynamic>.from`) — parses a `CaptionModel`,
dropping `null` results with a single `debugPrint`. The `GroupCallScreen` never wires a
`DataReceivedEvent` handler itself.

**Rationale**: `DataReceivedEvent` (from `livekit_client` 2.6.4,
`package:livekit_client/src/events.dart`) is a `RoomEvent`. Routing it through the
repository's `Stream<Caption>` keeps the presentation layer ignorant of the wire format
and the LiveKit listener (Constitution I), and gives a single, clear ownership/teardown
point: the datasource's `EventsListener` and the Cubit's `StreamSubscription` are both
cancelled in `TranslationCubit.detachRoom()` / `close()` (Constitution V). This is a
single ingestion path — the earlier alternative of also wiring a
`handleDataPacket` callback directly into the screen's `_roomEventsListener` was rejected
to avoid two competing ingestion routes and to keep the UI decoupled.

**Alternatives considered**:
- *Wiring `..on<DataReceivedEvent>(cubit.handleDataPacket)` into the screen's existing
  `_roomEventsListener`*: avoids a second `EventsListener`, but couples the presentation
  layer to raw data-channel events and the caption wire format, violating the clean-layer
  boundary. Rejected — the data layer owns ingestion (decided above).

## 3. Stale / out-of-order caption suppression (FR-012)

**Decision**: For each `speakerId`, `TranslationCubit` tracks the last-applied
`(segmentId, seq, type)`. An incoming update is applied only if:
- its `segmentId` differs from the tracked one (new utterance — always applied), OR
- its `segmentId` matches AND (`type == 'final'` OR `seq >= trackedSeq`).

A `final` always applies and "freezes" the line (per
`contracts/caption-data-channel.md` client rendering rules); a late/duplicate `interim`
for an already-finalized or higher-`seq` segment is dropped.

**Rationale**: Directly implements the backend contract's "Client rendering rules" and
FR-012 ("never regress to older text") with O(1) state per speaker — a single small
record, not a buffer/queue.

**Alternatives considered**: Buffering and re-sorting by `seq`/`ts` before display —
rejected as unnecessary complexity; the contract already guarantees finals are reliable
and monotonic `seq` per segment, so a simple high-water-mark check suffices.

## 4. Off-screen / camera-off speaker fallback (FR-010, Edge Cases)

**Decision**: In addition to the per-tile `CaptionOverlay`, `TranslationCubit` exposes
one extra `ValueNotifier<Caption?> latestActiveCaption` updated on every applied caption
(same de-dup rule as §3, scoped across all subscribed speakers by recency). A
`CaptionBanner` widget (`ValueListenableBuilder`) is placed once, above
`_buildControls()`, and shows `"{speakerName}: {text}"` for the most recent caption,
regardless of whether that speaker's tile is currently scrolled into view.

**Rationale**: Matches FR-010 ("system MUST still surface that caption ... via a fallback
location") with a single additional `ValueNotifier` and one small always-mounted widget —
no scroll-position tracking or per-tile visibility detection needed for the MVP grid
sizes (≤ a few participants, 2-column grid).

**Alternatives considered**: `VisibilityDetector` per tile to know when to fall back —
rejected as an added dependency and complexity not justified for the MVP slice; the
always-present banner is simpler and strictly additive (does not need to be hidden when
the tile *is* visible — seeing the same caption twice briefly is acceptable per "best
effort" captions).

## 5. Translation control plane (subscribe/unsubscribe/changeLanguage)

**Decision**: Extend the existing `SocketService` singleton (constitution IV) with three
emitters (`translationSubscribe`, `translationUnsubscribe`,
`translationChangeLanguage` — payloads per `contracts/socket-events.md`) and four typed
callbacks (`onTranslationSubscribed`, `onTranslationUnsubscribed`,
`onTranslationDenied`, `onTranslationUnavailable`), each registered with the
`data is! Map` → `Map<String,dynamic>.from(data)` guard (IV-A). `TranslationCubit` sets
these callbacks in its constructor and updates `TranslationState` (coarse, per-speaker
status) accordingly.

**Rationale**: Constitution IV mandates one `SocketService` singleton with typed
callbacks and forbids ad-hoc socket instances. The translation control events are
low-frequency (user-initiated toggles, occasional server notifications) — a perfect fit
for normal Cubit `state`/`BlocBuilder`, unlike the caption stream itself.

**Alternatives considered**: A dedicated second Socket.IO connection for translation —
explicitly forbidden by constitution IV ("Singleton: One `SocketService` instance").

## 6. Scope: `GroupCallScreen` only for this MVP

**Decision**: This slice wires captions and the toggle UI into `GroupCallScreen` only.
`VideoCallScreen` (1:1) and `VoiceCallScreen` are out of scope (spec Assumptions:
"Existing call screen and video tiles" — builds on existing screens without redesign;
the request frames the constraint around "video-grid rebuilds").

**Rationale**: `VideoCallScreen` has its own separate `_ParticipantVideoView`/tile
classes and `EventsListener<RoomEvent>`
(`lib/features/video_call/presentation/pages/video_call_screen.dart`) — wiring it in is
mechanically similar (same `TranslationCubit`/`CaptionOverlay` reused) but doubles the
manual-test surface for an MVP. All `translation/` module code (Cubit, widgets, models)
is screen-agnostic, so adding `VideoCallScreen` later is additive wiring, not a redesign.

**Alternatives considered**: Covering both screens now — deferred to keep the MVP
checkpoint demoable against a single, well-understood screen (group calls, where the
"video grid" performance constraint is most visible with multiple tiles).
