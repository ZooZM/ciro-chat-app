# Data Model: Multi-Device Read Suppression

**Feature**: 008-multidevice-read-suppression
**Date**: 2026-05-19

This feature introduces **no new persisted data**. The only addition is one in-memory boolean on the singleton `ChatCubit`. SQLite schema, REST DTOs, and socket payloads are all unchanged.

---

## 1. New In-Memory State

### `ChatCubit._isDeliberatelyOpen` (private)

| Property | Value |
|----------|-------|
| Type | `bool` |
| Scope | Private instance field on the singleton `ChatCubit` |
| Default | `false` |
| Lifetime | App-process lifetime; lost on process kill (intentional — cold start with last-route restoration triggers `openRoom` → sets flag, per FR-011) |
| Persistence | None — not persisted to SQLite or `SharedPreferences`. Intentional. |
| Equatable impact | None — not part of any `ChatState` subclass, not in any `props` list |
| Thread safety | All Cubit code runs on the Dart UI isolate; no synchronization needed |

#### State transitions

```
[initial: false]
   │
   │  openRoom(roomId)        ──────────────►   true
   │
   │  closeRoom()              ──────────────►  false
   │
   │  suspendDeliberateOpen()  ──────────────►  false
   │
   │  reset()                  ──────────────►  false  (logout sequence; §V-A)
   ▼
```

#### Invariants

1. **I-1**: The flag is `true` only while `_activeRoomId` is non-null AND the app is in the foreground AND `openRoom` was invoked since the last clearing event. The flag cannot be `true` while `_activeRoomId` is `null`.
2. **I-2**: A transition `false → true` happens only inside `openRoom`. No other code path sets the flag to `true`.
3. **I-3**: A transition `true → false` happens in `closeRoom`, `suspendDeliberateOpen`, or `reset`. No other code path sets the flag to `false`.
4. **I-4**: The `AppLifecycleState.resumed` transition is NOT a state transition for this flag — it is explicitly a no-op for the flag (the active-room socket reconnection logic is the only thing that runs on `resumed`).
5. **I-5**: The flag is independent of `_activeRoomId`: clearing the flag via `suspendDeliberateOpen` does NOT clear `_activeRoomId` (which keeps the room stream observed and unread badge accurate).

---

## 2. Existing Entities — No Changes

The following entities and tables are **unchanged** by this feature. Listed here only to document the intentional non-changes against the Constitution §III storage rule.

| Existing entity | Change |
|-----------------|--------|
| `Message` (SQLite `messages` table) | None. The `status` field continues to follow `pending → sent → delivered → read` per Constitution §IX-A. |
| `ChatRoom` / `ChatSession` (SQLite `rooms` / `chat_sessions` tables) | None. |
| `messageRead` socket event payload | None. Same `{ roomId, messageIds, ... }` shape. |
| `markRead` socket emit payload | None. Same `{ roomId, messageIds }` shape. |
| `messageDelivered` socket event/emit | None — explicitly preserved because FR-007 requires delivered tracking to remain unaffected. |
| `MessageStatus` enum | None. |
| Backend-side per-user read tracking | None — clarification Q2 option A preserves it. |

---

## 3. Conceptual Entity Glossary

These conceptual entities exist in the spec but are realized as the single boolean above. They do **not** materialize as separate Dart classes or SQLite tables.

| Spec entity | Realization |
|-------------|-------------|
| **Device Session** | The currently-running `ChatCubit` instance is, by construction, the device's session. Per-device identity is implicit — `_isDeliberatelyOpen` exists once per process. |
| **Read Acknowledgement** | The existing `markRead` socket emit. Gated by `_isDeliberatelyOpen`. No new payload fields. |
| **Conversation Open State** | The pair `(_activeRoomId, _isDeliberatelyOpen)`. The pair `(roomId, true)` means "deliberately open on this device"; the pair `(roomId, false)` means "visible but suppressed"; `(null, false)` means "no room active". The pair `(null, true)` is unreachable per Invariant I-1. |

---

## 4. Risk: Stale Flag After Hot Restart

In dev mode, Flutter's hot restart re-runs `main()` and rebuilds the widget tree but may or may not call `dispose()` cleanly on all observers. The flag defaults to `false` at field initialization, so a hot restart trivially yields the correct state (the user must navigate to a chat to re-set it). **No mitigation required.**

---

## 5. Risk: Out-of-Order Lifecycle Events

Some Android devices emit `paused` followed by an immediate `resumed` (e.g., a transient notification-shade interaction). This briefly clears and then leaves the flag false. Per the spec (clarification Q1 / FR-012), this is the correct behavior — even a brief background was a clear signal that the user disengaged. **No mitigation required.**

---

## 6. Out of Scope (Explicit)

- Persisting the flag across cold starts. Intentional: cold start with last-route restoration is a deliberate-open event per FR-011, so the flag is re-set by the route-mount `openRoom` call.
- Multi-conversation flag state (e.g., "deliberately open on chat A, suspended on chat B"). Not needed — the app shows one chat at a time; `_activeRoomId` is single-valued.
- Per-device backend tracking. Decided against per RD-4.
- A separate "intent" enum (deliberate vs. visibility-only). Decided against per RD-1.
