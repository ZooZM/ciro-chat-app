# Socket.IO Event Contract: Snap Map

Transport: existing Socket.IO gateway (WebSocket-only, Constitution IV). Sockets auto-join the user's room channels on connect (`chat.gateway.ts:96-109`); map events reuse those channels so fan-out targets exactly the authorized audience. Add handlers in the gateway and register client callbacks in `SocketService`.

> **Client handler rule (Constitution IV-A)** — every new `_socket?.on(...)` MUST:
> ```dart
> if (data is! Map) return;
> final map = Map<String, dynamic>.from(data);
> ```
> Never `data as Map<String, dynamic>`.

## Inbound (client → server)

### `shareLocation`
Throttled live-location broadcast while sharing (50 m / 30 s cadence, R4).
```json
{ "longitude": 31.2197, "latitude": 30.0626 }
```
Server behavior:
1. Persist `location` + server-assigned `locationUpdatedAt` **immediately** (DB write is not batched).
2. If sender `isGhostMode` → do NOT enqueue for fan-out.
3. Else write the latest value into the in-memory batch accumulator (`roomId → userId → latest`). A single flush timer (~5 s, FR-006a) emits one batched `locationUpdate` frame per room, coalescing repeated movement of the same user to the latest value. This is the thundering-herd guard (SC-012) — individual `shareLocation` events are NOT re-emitted one-for-one.

## Outbound (server → client)

### `userStatus` (EXISTING — reused for presence)
```json
{ "userId": "u2", "isOnline": true }
```
Client: existing `onUserStatusChanged`; MapCubit also listens to update the matching `MapUser.isOnline` and re-derive markers (debounced, FR-004).

### `locationUpdate` (NEW — batched array)
A **batch** of authorized users' location changes for a room, emitted on the ~5 s flush tick (FR-006a). Sent only to authorized room channels.
```json
{
  "updates": [
    {
      "userId": "u2",
      "longitude": 31.226,
      "latitude": 30.068,
      "isOnline": true,
      "lastUpdatedAt": "2026-06-21T08:00:00.000Z"
    }
  ]
}
```
Client: for each item, **idempotent upsert** into `allUsers` — apply only if `item.lastUpdatedAt` is strictly newer than the cached marker's (FR-022a, SC-011) — then re-derive visible markers through the active filter. `lastUpdatedAt` is server-assigned (single clock).

### `locationHidden` (NEW)
A user enabled Ghost Mode (or otherwise stopped sharing); remove their marker.
```json
{ "userId": "u2" }
```
Client: remove `MapUser` from `allUsers`, re-derive.

## Fan-out / authorization invariants (test targets)

- `locationUpdate`/`locationHidden` MUST only reach sockets in the sender's shared room channels (authorized observers) — never broadcast globally.
- While a user `isGhostMode`, the server MUST emit no `locationUpdate` for them, even on `shareLocation`.
- **Batching (SC-012)**: regardless of how many `shareLocation` events arrive within a flush interval, each room receives at most one `locationUpdate` frame per interval, with at most one entry per moving user (latest value).
- **Idempotency (SC-011)**: updates are timestamp-ordered by server-assigned `lastUpdatedAt`; the client applies strictly-newer-wins, so duplicate/out-of-order/late frames cause no regression (Constitution IV idempotency; mirrors the II status-promotion rule).

## SocketService additions (Flutter)

```dart
// callbacks (batch form)
void Function(List<LocationUpdateModel> updates)? onLocationUpdate;
void Function(String userId)? onLocationHidden;

// emit
void shareLocation(double longitude, double latitude) =>
    _socket?.emit('shareLocation', {'longitude': longitude, 'latitude': latitude});
```
Handler parses the batch with the IV-A safe pattern:
```dart
_socket?.on('locationUpdate', (data) {
  if (data is! Map) return;
  final map = Map<String, dynamic>.from(data);
  final raw = map['updates'];
  if (raw is! List) return;
  final updates = raw
      .whereType<Map>()
      .map((e) => LocationUpdateModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();
  onLocationUpdate?.call(updates);
});
```
MapCubit registers/clears these callbacks, applies the strictly-newer idempotent rule, and cancels related subscriptions + the TTL timer in `close()` (Constitution V).
