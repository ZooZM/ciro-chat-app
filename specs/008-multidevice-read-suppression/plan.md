# Implementation Plan: Multi-Device Read Suppression

**Branch**: `008-multidevice-read-suppression` (working on `003-optimize-chat-lifecycle`) | **Date**: 2026-05-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/008-multidevice-read-suppression/spec.md`

## Summary

Suppress automatic "read" acknowledgements on a device unless the user has *deliberately* opened the chat on that device. A new local flag on `ChatCubit` (`_isDeliberatelyOpen`) gates the two existing emission points in [chat_cubit.dart](lib/features/chat/presentation/bloc/chat_cubit.dart): the auto-mark branch on `onNewMessage` (currently around lines 330–339) and the bulk `markRoomMessagesRead` path (lines 489–506). The flag is set true inside `openRoom`, cleared inside `closeRoom`, and cleared (without tearing down the active-room subscription) when the app moves to `AppLifecycleState.paused` / `inactive` / `detached` from [main.dart](lib/main.dart) (which already implements `WidgetsBindingObserver`). The flag is **not** re-established on `AppLifecycleState.resumed` — the user must explicitly navigate away and return for fresh acknowledgements to be emitted. Backend, socket protocol, and SQLite schema are unchanged. The feature is contained entirely in two existing Flutter files plus one trivial public method addition to `ChatCubit`.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.x
**Primary Dependencies**: `flutter_bloc` (Cubit), `socket_io_client ^3.1.4`, `sqflite`. No new packages.
**Storage**: SQLite via `sqflite` (no schema change). In-memory flag on the singleton `ChatCubit` instance. No new credentials.
**Testing**: `flutter_test` + `bloc_test` for the gated-emission logic; manual two-device test plan in [quickstart.md](quickstart.md).
**Target Platform**: iOS 15+ / Android 6+ (mobile only).
**Project Type**: Mobile app (Flutter) + NestJS backend with LiveKit Cloud SFU. Backend is untouched by this feature.
**Performance Goals**: No measurable change. The gating is two boolean comparisons per emit; zero added I/O.
**Constraints**:
- The flag MUST be cleared on `paused` / `inactive` / `detached` to satisfy clarification Q1 (background/lock = no auto-read).
- The flag MUST NOT be re-set on `resumed`; only explicit room navigation re-sets it.
- The gating is enforced strictly on the client (clarification Q2). Backend remains per-user; the first device of a user to satisfy deliberate-open is the one whose `markRead` is recorded.
- Existing 1-to-1 read-receipt semantics MUST continue to work for single-device users.
- Sender-side own-message reads emitted by their own other devices are also gated (US1 — this is the primary user complaint).
**Scale/Scope**: ≤ 100 LOC across [chat_cubit.dart](lib/features/chat/presentation/bloc/chat_cubit.dart) and [main.dart](lib/main.dart). Zero new files in production code. New test file `test/features/chat/chat_cubit_deliberate_open_test.dart`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Pre-design check (Phase 0 entry)**: PASS — see boxes below.
**Post-design check (Phase 1 exit, 2026-05-19)**: PASS — no new violations introduced.

- [x] **I. Clean Architecture**: Feature is entirely within `features/chat/presentation/bloc/chat_cubit.dart` (presentation layer) plus a single hook in `main.dart`. No domain or data-layer changes are required; the deliberate-open flag is a presentation-layer concern (it gates an existing socket emit, it does not represent a domain entity).
- [x] **II. State Management**: Uses `Cubit` (existing `ChatCubit`); the flag is plain instance state, not part of the emitted `ChatState`. No new state classes; no `Equatable` impact. Existing dependency injection via `get_it` / `injectable` is unchanged.
- [x] **III. Offline-First**: No schema change. The flag is in-memory only — it deliberately does not persist across app restarts (a cold-start launching into the chat counts as a fresh deliberate-open per FR-002 / FR-011). SQLite usage unchanged.
- [x] **IV. Socket.IO**: The existing `messageRead` event and the existing `markRead` emit are reused unchanged. No new socket events, no new handlers, no new map-safety surface area. Constitution §IV-A (safe-cast pattern) does not apply because no new handler is added.
- [x] **V. Teardown**: The deliberate-open flag is plain `bool`; no subscriptions or timers to dispose. `ChatCubit.close()` is unchanged. The logout sequence (§V-A) is unaffected — `ChatCubit.reset()` already clears `_activeRoomId`; we add one line to also clear `_isDeliberatelyOpen`.
- [x] **Code Quality**: `snake_case` files; `PascalCase` classes; `flutter_lints` baseline. No `print`/`debugPrint` added beyond the existing `debugPrint` in `markRoomMessagesRead`.
- [x] **Error Handling**: No new error paths. The gate is a synchronous boolean check; nothing can throw.
- [x] **§IX (Message Status Flow)** non-regression: §IX-C ("On `receiveMessage` / `newMessage`: save as `delivered`, emit `markDelivered` immediately") continues to fire unconditionally — only the **auto-`markRead`** branch is gated. Status promotion order `pending → sent → delivered → read` is preserved; `delivered` still arrives at the receiver's device on receipt regardless of the deliberate-open flag (FR-007).
- [x] **§IX-C Item 3** ("On room open (`markRoomMessagesRead`): mark ALL messages where `senderId != currentUserId` AND `status ∈ {sent, delivered}` as `read`. MUST include `sent`") is the exact place where the deliberate-open flag becomes the trigger: `openRoom` now invokes `markRoomMessagesRead(roomId)` as its concluding step, and `markRoomMessagesRead` is also the batched-emission point for FR-008. The "MUST include `sent`" rule is preserved.

## Project Structure

### Documentation (this feature)

```text
specs/008-multidevice-read-suppression/
├── plan.md              # this file
├── research.md          # decisions: deliberate-open detection, AppLifecycle hook, telemetry
├── data-model.md        # entity: ConversationOpenState (in-memory only)
├── quickstart.md        # two-device test plan + single-device regression
├── contracts/
│   ├── internal.md      # ChatCubit public surface changes
│   └── socket.md        # explicit "no socket contract change" statement
└── tasks.md             # generated by /speckit-tasks (not by this command)
```

### Source Code (repository root)

```text
lib/
├── features/chat/presentation/bloc/
│   └── chat_cubit.dart   # MODIFY: add `bool _isDeliberatelyOpen = false`;
│                         #         set true at end of `openRoom`;
│                         #         set false in `closeRoom`;
│                         #         gate auto-mark in onNewMessage (line ~330) on the flag;
│                         #         gate `markRoomMessagesRead` emit on the flag;
│                         #         add public `void suspendDeliberateOpen()` (called from main);
│                         #         clear flag in `reset()`
└── main.dart             # MODIFY: in `didChangeAppLifecycleState`, on `paused` / `inactive` /
                          #         `detached`, call `getIt<ChatCubit>().suspendDeliberateOpen()`
                          #         BEFORE the existing socket.disconnect() call. On `resumed`,
                          #         do NOT re-set the flag.

test/features/chat/
└── chat_cubit_deliberate_open_test.dart   # NEW: 6 unit tests (see quickstart.md §4)
```

**Structure Decision**: No new feature slice. The whole feature is a narrow extension of the existing `chat` slice's `ChatCubit`. The "deliberate open" concept is implementation-private to `ChatCubit`; only the new `suspendDeliberateOpen()` method is exposed publicly, and only to `main.dart`'s lifecycle observer. No DI changes, no router changes, no `pubspec.yaml` changes.

## Complexity Tracking

No constitution violations. No architectural deviations from minimalism. The feature is small enough that a dedicated subfolder, abstraction, or service would be over-engineering. The single public method addition (`suspendDeliberateOpen`) is the only API surface change.

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| (none) | — | — |

## Implementation Phases (Reference for /speckit-tasks)

This section is **descriptive** — `/speckit-tasks` will generate the actionable task list.

### Phase A: Flag plumbing

1. Add `bool _isDeliberatelyOpen = false;` field to `ChatCubit` near `_activeRoomId`.
2. Set `_isDeliberatelyOpen = true` at the bottom of `openRoom` (after `_activeRoomId` is set).
3. Set `_isDeliberatelyOpen = false` in `closeRoom`.
4. Set `_isDeliberatelyOpen = false` in `ChatCubit.reset()`.

### Phase B: Gate the two emission points

1. In the `onNewMessage` handler (currently around line 330), change `if (isActiveRoom)` to `if (isActiveRoom && _isDeliberatelyOpen)`. The `markDelivered` call (FR-007) remains unconditional.
2. In `markRoomMessagesRead`, add a leading guard: if `_isDeliberatelyOpen` is false, return without emitting (still update SQLite? — see research RD-3). Currently `markRoomMessagesRead` is only called as part of room-open flow; with the deliberate-open semantic, we move the call to be the last line of `openRoom` itself, so this gate is naturally satisfied. Any other in-app callers must satisfy the gate or the call is a no-op.

### Phase C: AppLifecycle wiring

1. In `main.dart`'s `didChangeAppLifecycleState`, before the existing `socket.disconnect()` call on `paused` / `detached`, add `getIt<ChatCubit>().suspendDeliberateOpen();`. Also add the same call on `AppLifecycleState.inactive` (which fires before `paused` on iOS lock-screen transitions).
2. Add public method `void suspendDeliberateOpen() => _isDeliberatelyOpen = false;` to `ChatCubit`. No emit, no state change — it is a pure flag mutation.
3. On `AppLifecycleState.resumed`, do NOT touch the flag. The existing socket-reconnect logic is preserved.

### Phase D: Tests

1. Unit tests (`chat_cubit_deliberate_open_test.dart`):
   - `openRoom` sets the flag and `markRoomMessagesRead` emits.
   - `closeRoom` clears the flag.
   - `suspendDeliberateOpen` clears the flag and does NOT call `closeRoom`.
   - Incoming new message while flag is true → `markRead` is emitted.
   - Incoming new message while flag is false (room open but flag suspended) → `markRead` is NOT emitted; `markDelivered` IS emitted.
   - After `suspendDeliberateOpen` then `openRoom` (same room) → flag is re-set and accumulated unread is re-emitted as a batched `markRead`.
2. Manual two-device regression per [quickstart.md](quickstart.md).

### Phase E: Telemetry (optional, gated on SC-004 buy-in)

1. Add an optional debug counter incremented every time the flag suppresses a would-be emit. Surfaced only in dev builds via `debugPrint`. Used to validate SC-004 during pilot.

**End of plan.md.** See `research.md`, `data-model.md`, and `contracts/` for design specifics.
