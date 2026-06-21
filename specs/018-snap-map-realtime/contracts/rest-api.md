# REST API Contract: Snap Map

Base: existing `MapController` (`@Controller('map')`, `JwtAuthGuard`). `userId` is taken from the JWT (`req.user`).

## EXISTING — extended

### `PATCH /map/location`
Update the caller's location. Now also writes `locationUpdatedAt` and triggers authorized fan-out (see socket `locationUpdate`). No-ops fan-out when caller `isGhostMode`.

Request:
```json
{ "longitude": 31.2197, "latitude": 30.0626 }
```
Response `200`:
```json
{ "message": "Location updated successfully" }
```
Validation: `UpdateLocationDto` (`-180..180`, `-90..90`).

### `GET /map/nearby?longitude&latitude&radius`
Now **authorization-scoped**: returns only users U where the caller ∈ `authorizedObserverIds(U)`, `U.isGhostMode == false`, and `U.locationUpdatedAt >= now - 24h` (staleness, R5). `radius` km (default `10`).

Response `200`:
```json
{
  "users": [
    {
      "_id": "u2",
      "name": "Mahmoud",
      "avatarUrl": "/uploads/a.jpg",
      "isOnline": true,
      "location": { "type": "Point", "coordinates": [31.226, 30.068] },
      "locationUpdatedAt": "2026-06-21T08:00:00.000Z",
      "sharedGroupIds": ["room123"]
    }
  ]
}
```

## NEW

### `GET /map/visible`
Returns the full authorized set (not distance-limited) for the "All Locations" distance filter. Same item shape as `/map/nearby`. Excludes ghost-mode users, blocked users (both directions), and users without a location.

Response `200`: `{ "users": [ MapUserDto, ... ] }`

### `PATCH /map/ghost-mode`
Set the caller's global Ghost Mode (FR-011/013). Side effect: emits `locationHidden` (enabling) or `locationUpdate` (disabling, if a location exists) to authorized observers.

Request (`SetGhostModeDto`):
```json
{ "enabled": true }
```
Response `200`:
```json
{ "isGhostMode": true }
```

### `GET /map/ghost-mode`
Returns the persisted flag for client startup hydration.
Response `200`: `{ "isGhostMode": false }`

### `GET /map/groups`
Returns the caller's GROUP chat rooms for the group filter (replaces the mock list). Reuses chat-room data.
Response `200`:
```json
{
  "groups": [
    { "id": "room123", "name": "Tech Team", "memberCount": 8, "avatarUrl": null, "initials": "TT" }
  ]
}
```

### `GET /map/explore`
Explore tab: users with an active `SHOW_ON_MAP` status (R9, clarification Q1). NEVER returns live non-contact location — only status-derived markers. For users who are NOT mutual/shared-group contacts of the caller, coordinates MUST be **coarsened server-side** (truncated to ~2 decimal places, ≈1.1 km grid) and flagged `isCoarse: true` (FR-001b). Precise coordinates are returned only for users who are already authorized contacts of the caller.
Response `200`:
```json
{
  "users": [
    {
      "_id": "...",
      "name": "...",
      "avatarUrl": "...",
      "statusId": "...",
      "isCoarse": true,
      "location": { "type": "Point", "coordinates": [31.22, 30.07] }
    }
  ]
}
```

**Privacy invariant (test target)**: for a non-contact result, the returned coordinates MUST equal the truncated grid value (no precise decimals beyond the coarsening precision ever leave the server).

## Authorization invariants (test targets — SC-001/008)

- A user NOT in `authorizedObserverIds(U)` MUST receive 0 records for U from `/map/nearby`, `/map/visible`.
- Ghost-mode users MUST appear in 0 results.
- Blocked users MUST be mutually invisible.
- Endpoints require a valid JWT (401 otherwise).
