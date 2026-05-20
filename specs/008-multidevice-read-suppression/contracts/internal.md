# Internal Contracts: Multi-Device Read Suppression

**Feature**: 008-multidevice-read-suppression
**Date**: 2026-05-19

This document captures the Dart-level public-surface changes inside the Flutter app. There are no REST contracts, no socket-event contract changes (see `socket.md`), and no SQLite contracts to update.

---

## 1. `ChatCubit` Public Surface

### NEW method

```dart
/// Clears the deliberate-open flag without tearing down the active room.
///
/// Called from `main.dart`'s `didChangeAppLifecycleState` on:
///   AppLifecycleState.paused
///   AppLifecycleState.inactive
///   AppLifecycleState.detached
///   AppLifecycleState.hidden (where emitted)
///
/// Does NOT cancel `_roomStreamSub`, does NOT clear `_activeRoomId`,
/// does NOT emit a new state. The room stays observed; only the
/// auto-read gate goes off.
///
/// Idempotent: calling when the flag is already `false` is a no-op.
void suspendDeliberateOpen();
```

### MODIFIED method semantics (signatures unchanged)

| Method | Behavioral delta |
|--------|------------------|
| `openRoom(String roomId, {ChatSession? contact, ChatSession? room})` | After `_activeRoomId = roomId;`, set `_isDeliberatelyOpen = true;`. As the last step of the method (after Background Sync section), call `markRoomMessagesRead(roomId)` so accumulated `delivered`/`sent` messages flush as a batched `markRead` per FR-008. If `openRoom` already invokes this elsewhere in the existing code path, do not double-invoke; confirm during implementation. |
| `closeRoom()` | Set `_isDeliberatelyOpen = false;` in addition to the existing `_activeRoomId = null;` and stream cancellation. |
| `markRoomMessagesRead(String roomId)` | Add a leading guard: `if (!_isDeliberatelyOpen) return;`. Existing behavior (mark `sent` AND `delivered` as `read` in SQLite, emit `markRead` on the socket) runs unchanged when the guard passes. |
| `reset()` | Set `_isDeliberatelyOpen = false;` in addition to existing teardown. Preserves Constitution §V-A logout order. |
| (incoming-message handler around `chat_cubit.dart:319–339`) | Change the auto-mark branch condition from `if (isActiveRoom)` to `if (isActiveRoom && _isDeliberatelyOpen)`. The `markDelivered` call on lines 325–328 stays unconditional (FR-007). The SQLite write at line 320 (`saveMessage(... incrementUnread: !isActiveRoom)`) also stays unchanged — the unread-counter behavior is the same as today. |

### NEW private state (informative — not part of the public contract)

```dart
bool _isDeliberatelyOpen = false;
```

Placed near the existing `String? _activeRoomId;` field. Documented as "Set in openRoom; cleared in closeRoom / suspendDeliberateOpen / reset. See specs/008-multidevice-read-suppression/data-model.md."

---

## 2. `main.dart` Lifecycle Observer

### MODIFIED method

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  final socket = getIt<SocketService>();

  // NEW: clear the read-emit gate as soon as we go background-ish.
  // Order matters: clear the flag BEFORE socket.disconnect() so any
  // in-flight `markRead` emit on the wire is the last one allowed.
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.detached ||
      state == AppLifecycleState.hidden) {
    getIt<ChatCubit>().suspendDeliberateOpen();
  }

  // EXISTING (unchanged):
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    socket.disconnect();
  } else if (state == AppLifecycleState.resumed && !socket.isConnected) {
    getIt<AuthLocalDataSource>().getAccessToken().then((token) {
      if (token != null && token.isNotEmpty) socket.connect(token);
    });
  }
}
```

> The two branches deliberately overlap on `paused` and `detached`. The first branch is read-only behavior, the second is socket lifecycle. Both must run.

---

## 3. Equality and Equatable

The new private boolean is **not** in any `ChatState` `props` list and **not** part of any emitted state. `ChatCubit` will not emit a new state when the flag flips — flag transitions are pure side-effect mutations of a guard.

Constitution §II compliance: states extend `Equatable`; this change does not modify any state class.

---

## 4. Tests Contract

| Test ID | Setup | Action | Expected |
|---------|-------|--------|----------|
| T-DO-1 | Fresh `ChatCubit` | call `openRoom('R')` | flag becomes true; `markRead` is emitted for any unread; `_activeRoomId == 'R'` |
| T-DO-2 | Flag true, in room R | call `closeRoom()` | flag becomes false; `_activeRoomId == null`; `_roomStreamSub` cancelled |
| T-DO-3 | Flag true, in room R | call `suspendDeliberateOpen()` | flag becomes false; `_activeRoomId` unchanged; `_roomStreamSub` still alive |
| T-DO-4 | Flag true, in room R | simulate `onNewMessage` for room R | `markDelivered` emitted AND `markRead` emitted; SQLite status promoted to `read` |
| T-DO-5 | Flag false (post-suspend), in room R | simulate `onNewMessage` for room R | `markDelivered` emitted; `markRead` NOT emitted; SQLite status stays at `delivered` |
| T-DO-6 | After T-DO-5: flag false, two messages received in delivered state | call `openRoom('R')` again (simulating leave-and-return) | flag becomes true; batched `markRead` emitted for the two messages |

Tests live in `test/features/chat/chat_cubit_deliberate_open_test.dart` and use `mocktail` for `SocketService` + `ChatLocalDataSource` fakes (matching the existing `bloc_test` patterns in this repo).

---

## 5. Migration / Compatibility

- **No SQLite migration.**
- **No socket protocol bump.**
- **No backend deploy required.**
- A single-device user who upgrades to the version containing this feature observes zero behavioral change. The flag is `true` for every navigation into a chat, exactly as before — the user always opened the chat deliberately, so all reads emit on time.
- A multi-device user observes the new behavior immediately on upgrade. No data migration needed.

---

## 6. Out of Scope for This Contract

- Per-device backend ack contracts.
- Telemetry endpoints for SC-004 (validated qualitatively in pilot per RD-5).
- Any new ChatState subclass or new emit shape.
