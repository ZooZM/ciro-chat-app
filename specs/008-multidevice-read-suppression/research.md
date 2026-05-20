# Research: Multi-Device Read Suppression

**Feature**: 008-multidevice-read-suppression
**Date**: 2026-05-19

This file resolves all unknowns in `plan.md`'s Technical Context. Each decision below was selected to minimize new surface area and integrate with existing `ChatCubit` and `WidgetsBindingObserver` infrastructure.

---

## RD-1: How is "deliberate open" detected in Flutter?

**Decision**: A boolean flag (`bool _isDeliberatelyOpen`) on the singleton `ChatCubit`, mutated only by three transitions:

1. **Set true** at the end of `ChatCubit.openRoom(roomId)`. `openRoom` is the single entry point invoked whenever the user navigates **into** a chat screen — whether from the conversations list (push from `GoRoute`), a push-notification tap (deep-link route push that mounts `ChatScreen`), a cold start that restores the last route (same mount path), or any deep link (same mount path). Because `openRoom` is invoked by `ChatScreen`'s mount lifecycle, all four FR-002 sub-cases naturally trigger it without further work.
2. **Set false** in `ChatCubit.closeRoom()`. `closeRoom` is invoked on `ChatScreen.dispose()` / `deactivate`, which fires on every navigation **away** (back button, opening a different chat, opening any other top-level screen).
3. **Set false** by a new `ChatCubit.suspendDeliberateOpen()` method, called from `main.dart`'s `didChangeAppLifecycleState` on `paused` / `inactive` / `detached`. This method does NOT clear `_activeRoomId` or cancel the room stream — only the flag is cleared. The active-room infrastructure (which drives realtime stream subscription and per-room unread counts) stays alive across backgrounding; only the read-emission gate is suspended.

**Rationale**:
- `openRoom` and `closeRoom` already exist as the canonical room-lifecycle hooks in `ChatCubit`. Reusing them keeps the new logic localized and aligns with the existing `_activeRoomId` lifecycle.
- A plain `bool` is the simplest possible representation; no state-class change, no Equatable surface area, no extra rebuild risk.
- Splitting "navigation lifecycle" (open/close) from "app lifecycle" (suspend) is necessary because `closeRoom` would also tear down `_roomStreamSub`, which we do NOT want on app pause — the room stays observed, only the auto-read gate goes off.

**Alternatives considered**:
- A `RouteObserver` listening to `GoRouter` route push/pop events: rejected because it would duplicate the existing `openRoom`/`closeRoom` lifecycle and add a second source of truth.
- A timestamp-based heuristic (e.g., "flag valid for N seconds after last user input"): rejected as user-hostile and contradicts the user's explicit clarification (clarification Q1, option B).
- A separate `ConversationOpenCubit` singleton: rejected as over-engineering for a single boolean.

---

## RD-2: Which AppLifecycleState transitions clear the flag?

**Decision**: Clear on **`paused`**, **`inactive`**, and **`detached`**. Do NOT touch the flag on `resumed`.

| State | Action | Reason |
|-------|--------|--------|
| `paused` | `suspendDeliberateOpen()` | Standard Android "user navigated away from app" signal. |
| `inactive` | `suspendDeliberateOpen()` | iOS lock-screen and incoming-call transitions fire `inactive` before (and sometimes without) `paused`. Necessary to cover the iOS lock-screen path in US2 scenario 1. |
| `detached` | `suspendDeliberateOpen()` | App is being torn down. Belt-and-suspenders — the flag will be gone anyway on next process start. |
| `resumed` | (no-op for the flag) | The user has come back, but per clarification Q1 they must explicitly leave and return. The existing `socket.connect(token)` call stays untouched. |
| `hidden` | `suspendDeliberateOpen()` (if encountered on the platform) | Newer Flutter SDKs may emit `hidden` on certain platforms before `paused`. Defensive coverage. |

**Rationale**: `main.dart` already implements `WidgetsBindingObserver` and handles `paused` / `detached` for socket lifecycle. Adding the flag-clear call at the top of those branches is one line. Adding `inactive` is necessary for iOS correctness — iOS Lock Screen often produces `inactive` without `paused` on short locks.

**Alternatives considered**:
- Only `paused`: rejected because iOS lock-screen would let the bug slip through on short locks (FR-002 explicitly says "Resuming the app from background … does NOT count" — this requires `inactive` to also be a clearing signal).
- Use `Visibility` widget callbacks: rejected — Flutter's app-level lifecycle observer is the canonical source for foreground/background transitions on mobile.

---

## RD-3: Does `markRoomMessagesRead` update SQLite even when the flag is false?

**Decision**: **No.** When the flag is false, `markRoomMessagesRead` returns early without touching SQLite or emitting `markRead`.

**Rationale**:
- The whole point of the feature is that the user has NOT deliberately viewed the messages. Promoting them locally to `read` would change the unread badge for the local user — that is the wrong UX (the user has not "read" the messages).
- Keeping messages in `delivered` state locally also means that when the user later navigates away and returns (deliberate-open trigger), the existing `markRoomMessagesRead` logic (which marks all `delivered` and `sent` messages as read) naturally re-emits the batched `markRead` per FR-008. Free batching, no extra code.
- Backend has no opinion either way — the emit never happened, so no contradiction.

**Alternatives considered**:
- Update SQLite to `read` but skip the socket emit: rejected because it would lie to the local user about their own read state, defeating the "user has not seen this yet" intent.
- Mark a new `pending-read` intermediate state: rejected as needless schema growth for a transient situation that resolves naturally on next deliberate-open.

---

## RD-4: How does the existing per-user (not per-device) backend handle this without change?

**Decision**: **No backend changes.** The existing `markRead` socket event keeps its current contract. Only the trigger condition shifts: instead of "any of the user's devices that has the chat visible emits `markRead` on receipt", now "only a device that has been deliberately opened emits `markRead`". The backend's per-user read-tracking is fed by whichever single device emits first — which is exactly what FR-006 requires.

**Rationale**: Backend already counts reads per user (one ack per (user, message) pair). The clarification Q2 answer (option A — Flutter-only gating) means we do not need to introduce per-device state on the backend. The first of a user's devices to satisfy the deliberate-open rule contributes that user's ack; subsequent devices satisfying the rule emit again (idempotent) but the backend treats the second as a no-op.

**Alternatives considered**:
- Backend per-device tracking (Q2 option B): rejected per clarification.
- Hybrid with optional `clientReadIntent` payload field (Q2 option C): rejected per clarification.

---

## RD-5: How is SC-004 (95% sender-visible read-receipt accuracy) measured?

**Decision**: Add a dev-only debug counter on `ChatCubit` that increments every time the deliberate-open flag suppresses a would-be emit. Surfaced only via `debugPrint` in dev builds. For production validation, rely on user survey during a 7-day pilot (the feature is observable enough that survey + telemetry sampling on the receiver side suffices). Defer any production-grade telemetry to a separate future spec if SC-004 becomes a contractual obligation; for v1 the success criterion is validated qualitatively during the pilot.

**Rationale**: This feature is a UX improvement, not a billable SLO. Heavy-weight telemetry would be disproportionate to the change's scope. The dev counter gives engineers visibility during development and bug triage without adding production infrastructure.

**Alternatives considered**:
- Backend instrumentation comparing visibility-time vs. read-emit-time: rejected as out-of-scope for a Flutter-only change.
- Anonymous opt-in telemetry to a remote endpoint: rejected as out-of-scope; can be added later if accuracy becomes contested.

---

## RD-6: Interaction with the existing `chat_cubit_deliberate_open_test.dart` test suite

**Decision**: New test file `test/features/chat/chat_cubit_deliberate_open_test.dart` using `bloc_test` and `mocktail`. Six tests (one per Phase D bullet in plan.md). Existing tests in `test/features/chat/` are not modified — the gating logic is additive and does not change any existing public contract.

**Rationale**: Per Constitution §VI and existing `bloc_test` conventions in this repo.

---

## RD-7: Backwards compatibility for single-device users

**Decision**: **Zero behavioral change for single-device users.** A single device that follows the normal flow (open conversations list → tap a chat → `ChatScreen` mounts → `openRoom` is called → flag is set → messages auto-mark on arrival) sees identical timing to today. The flag's existence is invisible to single-device users because, in practice, every chat-open they perform is by definition deliberate.

**Rationale**: FR-010 demands no observable regression for single-device users. The flag's design above guarantees it.

---

## Summary of Phase 0 Outputs

| Item | Status | Owner |
|------|--------|-------|
| Deliberate-open detection mechanism | Decided (RD-1) | — |
| AppLifecycleState transitions | Decided (RD-2) | — |
| SQLite update semantics under suppression | Decided (RD-3) | — |
| Backend change scope | Decided: none (RD-4) | — |
| Telemetry for SC-004 | Decided: dev-counter only (RD-5) | — |
| Test surface | Decided (RD-6) | — |
| Single-device backwards compatibility | Confirmed (RD-7) | — |

All NEEDS CLARIFICATION items from the Technical Context are resolved. Proceeding to Phase 1 design.
