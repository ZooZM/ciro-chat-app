---
description: "Task list for Multi-Device Read Suppression — gates auto-`markRead` emission on a per-device deliberate-open flag"
---

# Tasks: Multi-Device Read Suppression

**Input**: Design documents from `/specs/008-multidevice-read-suppression/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Unit tests for the gated-emission logic are included because they catch regressions cheaply (a single boolean gate touches the §IX-A status pipeline, which the constitution treats as load-bearing). Two-device acceptance tests are manual per [quickstart.md](quickstart.md).

**Organization**: Tasks are grouped by user story (US1, US2) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps to user stories from spec.md (US1, US2)
- File paths are absolute project-root-relative for Flutter.

## Path Conventions

- **Flutter**: `lib/features/<feature>/{data,domain,presentation}/...`
- **Flutter Core**: `lib/core/...`
- **Tests**: `test/features/<feature>/...`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: This feature touches existing files only. No new packages, no DI changes, no router changes, no SQLite migration. Setup phase is intentionally near-empty.

- [X] T001 Confirm the four `ChatCubit` lifecycle anchors exist at the line numbers documented in plan.md before editing: `_activeRoomId` field declaration (`lib/features/chat/presentation/bloc/chat_cubit.dart` around line 59), the active-room auto-mark branch (around lines 330–339), `openRoom` (around line 351), `closeRoom` (around line 478), `markRoomMessagesRead` (around line 489), and the `reset()` method (around line 1519). If any line number has drifted, update the task descriptions for T003–T009 with the corrected anchors before starting them

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the in-memory flag and ensure it is cleared in the logout teardown sequence (Constitution §V-A). Both US1 and US2 depend on this.

- [X] T002 In `lib/features/chat/presentation/bloc/chat_cubit.dart`, add a new private field `bool _isDeliberatelyOpen = false;` immediately after the existing `String? _activeRoomId;` declaration (around line 59). No emit on flag change; the flag is a guard, not part of any `ChatState` (see [data-model.md](data-model.md) §1 invariants)
- [X] T003 In `lib/features/chat/presentation/bloc/chat_cubit.dart` `reset()` (around line 1519 where `_activeRoomId = null;` is set), add `_isDeliberatelyOpen = false;` on the next line. This preserves Constitution §V-A logout order — the flag is cleared as part of the existing `ChatCubit.reset()` step, before socket disconnect

**Checkpoint**: Foundation ready — the flag exists and is correctly cleared on logout. User-story phases can now proceed in parallel.

---

## Phase 3: User Story 1 — Read state is gated by an intentional re-open (Priority: P1) 🎯 MVP

**Goal**: When a user has the same chat open on two devices, sending from device A no longer causes device B to auto-emit a read acknowledgement. Read state advances only after the user deliberately re-enters the chat on device B.

**Independent Test**: Two devices signed into the same account, both showing the same 1-to-1 chat with Device C. Device C sends a message → sender (Device C) ticks stay at `delivered`. Device B leaves to conversations list and re-enters → Device C ticks advance to `read` within 2 s.

### Implementation for User Story 1

- [X] T004 [US1] In `lib/features/chat/presentation/bloc/chat_cubit.dart` `openRoom` (around line 351), after the line `_activeRoomId = roomId;` (around line 371), add `_isDeliberatelyOpen = true;` to establish the deliberate-open flag for this session. Place it BEFORE the existing stream subscription / background sync blocks so the flag is true for the rest of the method
- [X] T005 [US1] In `lib/features/chat/presentation/bloc/chat_cubit.dart` `openRoom`, as the final step before the method returns (after the Background Sync block completes), call `await markRoomMessagesRead(roomId);`. This flushes any messages that accumulated in `delivered`/`sent` state during the suppression window as a single batched `markRead` (FR-008). If `markRoomMessagesRead` is already invoked elsewhere in the existing `openRoom` flow, do NOT double-invoke — confirm by reading lines 351–478 in full first
- [X] T006 [US1] In `lib/features/chat/presentation/bloc/chat_cubit.dart` `closeRoom` (around line 478), add `_isDeliberatelyOpen = false;` after the existing `_activeRoomId = null;`. Order matters less here since neither writes to disk; just keep them adjacent for readability
- [X] T007 [US1] In `lib/features/chat/presentation/bloc/chat_cubit.dart` `onNewMessage` handler (the inline closure that assigns to `_socketService.onNewMessage` around lines 153–340), locate the `if (isActiveRoom)` branch at line 330 and change the condition to `if (isActiveRoom && _isDeliberatelyOpen)`. The body (calling `_socketService.markRead` + `_localDataSource.updateMessageStatus`) is unchanged. CRITICAL: the `_socketService.markDelivered` call at lines 325–328 stays UNCONDITIONAL — FR-007 requires delivered tracking to remain unaffected. Verify by inspection that `markDelivered` is outside the gated branch
- [X] T008 [US1] In `lib/features/chat/presentation/bloc/chat_cubit.dart` `markRoomMessagesRead` (around line 489), add a leading guard as the first statement: `if (!_isDeliberatelyOpen) { debugPrint('[ChatCubit] Suppressed markRoomMessagesRead for $roomId (deliberateOpen=false)'); return; }`. This makes the method a no-op when called from any path other than the deliberate-open trigger. The existing SQLite update + socket emit logic (lines 490–502) runs only when the guard passes
- [ ] T009 [US1] Manual two-device acceptance test per [quickstart.md](quickstart.md) §2: confirm that on Device C the message ticks stay at `delivered` while both Device A and Device B have the chat visible, and advance to `read` within 2 s after Device B leaves to conversations list and re-enters the chat (SC-001, SC-002)

**Checkpoint**: User Story 1 is complete. The original bug (auto-read on the user's second device while the chat is just visible) is fixed. The feature is shippable here as MVP if US2's stricter backgrounding semantic can be deferred.

---

## Phase 4: User Story 2 — Deliberate-open detection survives backgrounding (Priority: P2)

**Goal**: Locking or backgrounding the device clears the deliberate-open flag, even if the chat screen remains the top route. Resuming the app does NOT re-establish the flag — only an explicit leave-and-return does. This prevents the original bug from sneaking back in via lock-screen + arriving messages.

**Independent Test**: Device B is in a chat (deliberate-open is established). Lock Device B for 30 s while three messages arrive. Unlock Device B; the chat screen is restored. Confirm the three messages remain in `delivered` (NOT `read`) on the sender's UI. Confirm leaving to conversations list and re-entering the chat then promotes all three to `read`.

### Implementation for User Story 2

- [X] T010 [US2] In `lib/features/chat/presentation/bloc/chat_cubit.dart`, add a new public method directly after `closeRoom` (around line 488):
  ```dart
  /// Clears the deliberate-open flag without tearing down the active room.
  /// Called from main.dart's lifecycle observer on paused / inactive /
  /// detached / hidden. Idempotent.
  void suspendDeliberateOpen() {
    _isDeliberatelyOpen = false;
  }
  ```
  Do NOT cancel `_roomStreamSub`, do NOT clear `_activeRoomId`, do NOT emit a new state — see [contracts/internal.md](contracts/internal.md) §1
- [X] T011 [US2] In `lib/main.dart` `didChangeAppLifecycleState` (around lines 65–75), insert a new block BEFORE the existing `if (state == AppLifecycleState.paused || state == AppLifecycleState.detached)` socket-disconnect branch:
  ```dart
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.detached ||
      state == AppLifecycleState.hidden) {
    getIt<ChatCubit>().suspendDeliberateOpen();
  }
  ```
  Including `inactive` is necessary for iOS lock-screen correctness — iOS frequently fires `inactive` without `paused` on short locks (RD-2). `hidden` is defensive coverage for newer Flutter SDKs
- [X] T012 [US2] Verify by inspection that the `AppLifecycleState.resumed` branch in `main.dart` (around line 70) is NOT modified — the existing socket-reconnect logic stays as-is. The user MUST explicitly leave and re-enter the chat to re-establish the flag (FR-012)
- [ ] T013 [US2] Manual acceptance test per [quickstart.md](quickstart.md) §3: with the chat open on Device B, lock the device for 30 s, send 3 messages from Device C during the lock period, unlock Device B with chat still visible, wait 5 s, then confirm on Device C that all 3 messages are still at `delivered` (NOT `read`). Then have Device B leave to conversations list and re-enter the chat — confirm the 3 messages advance to `read` within 2 s (SC-005, batched per FR-008)

**Checkpoint**: User Story 2 is complete. The flag now correctly clears on every form of disengagement and only re-establishes on explicit navigation. The feature is feature-complete per the spec.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Unit-test coverage of the gated-emission logic, single-device regression, optional dev telemetry, lint pass.

### Unit Tests for the Gated-Emission Logic

- [X] T014 [P] Create `test/features/chat/chat_cubit_deliberate_open_test.dart` using `bloc_test` and `mocktail`. Fake `SocketService` (record calls to `markRead` and `markDelivered`) and `ChatLocalDataSource` (return empty lists; record calls to `updateMessageStatus`). Implement the six test cases T-DO-1 to T-DO-6 from [contracts/internal.md](contracts/internal.md) §4. All six MUST pass before merge
- [ ] T015 [P] Run `flutter test test/features/chat/chat_cubit_deliberate_open_test.dart` and confirm all six tests pass. If T-DO-6 fails, the most likely cause is T005 (the batched re-emit on second `openRoom`) being skipped — re-verify

### Single-Device Regression

- [ ] T016 [P] Manual single-device regression per [quickstart.md](quickstart.md) §4: sign out of Device B, confirm that on Device A (sole signed-in device for the account) all read-receipt timings match pre-feature baseline. Constitution §IX-A status promotion `pending → sent → delivered → read` must be observable end-to-end with no flicker, no error toast, no missed acknowledgement (SC-003, FR-010)

### Cold-Start Verification

- [ ] T017 [P] Manual cold-start test per [quickstart.md](quickstart.md) §5: force-kill the app while on a chat screen, send 2 messages from Device C, re-launch Ciro. If the app restores the chat as the last route, the 2 messages MUST advance to `read` within 2 s of launch (FR-011 — cold start counts as deliberate-open via the route-mount `openRoom` call). If the app instead launches to the conversations list, the 2 messages stay at `delivered` until tapped

### Optional Dev Telemetry

- [X] T018 [P] In `lib/features/chat/presentation/bloc/chat_cubit.dart`, in the gated branch added in T007, add a `debugPrint('[ChatCubit] Suppressed auto-markRead for ${incoming.clientMessageId} in ${incoming.roomId} (deliberateOpen=false)');` at the point where the auto-mark would have run but did not. This line is the dev-build telemetry signal referenced in [research.md](research.md) RD-5 and [quickstart.md](quickstart.md) §7. It does NOT affect production behavior (debugPrint is stripped in release builds)

### Lint & Static Analysis

- [X] T019 Run `flutter analyze` from repo root and confirm zero new warnings or errors introduced by T002–T018. Constitution §VI treats lints as merge blockers
- [ ] T020 Run the existing chat-feature regression smoke pass from `specs/007-group-chat/quickstart.md` §3 Phase D (text/media/voice messages, status promotion, 1-to-1 voice + video calls, typing indicator, logout teardown) on a single-device setup to verify no orthogonal regression from this change

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: T001. No dependencies — must complete before any code task to confirm line anchors
- **Phase 2 (Foundational)**: T002–T003. Depends on T001. Blocks all later phases.
- **Phase 3 (US1)**: T004–T009. Depends on Phase 2. T004–T008 are in the same file and must run sequentially (different methods, same file — `Edit` operations need exclusivity). T009 (manual test) depends on T004–T008 being merged.
- **Phase 4 (US2)**: T010–T013. Depends on Phase 2. **T010 can run in parallel with US1's T004–T008** (different sections of the same file but additive). T011 is in `main.dart` and is independent of any US1 task. T013 manual test depends on T010–T012.
- **Phase 5 (Polish)**: T014–T020. Depends on Phases 3 and 4 being complete in code. T014–T018 are all parallel-safe (independent files / independent verification work). T019 and T020 are the final gates.

### User Story Independence

- **US1** delivers the bug fix for the original user complaint (same chat open on 2 devices, send from one, the other should not auto-read). Fully shippable as MVP without US2.
- **US2** delivers the stricter "backgrounding clears the flag" semantic. Optional from a user-feedback standpoint but **strongly recommended** because without it the bug can sneak back in via lock-screen + arriving messages — defeating the whole point.

---

## Parallel Execution Examples

### Phase 3 + Phase 4 — partial parallelism

```
US1 path (sequential, same cubit file):
  T004 → T005 → T006 → T007 → T008 → T009 (manual test, after merge)

US2 path:
  T010 (in chat_cubit.dart — needs scheduling against US1 edits)
  T011 (in main.dart — independent of US1)  ← can run in parallel with any US1 task
  T012 (inspection only — instant)
  T013 (manual test — after T010 + T011)
```

Practical recommendation: land T011 first (different file, zero conflict), then complete all US1 edits in chat_cubit.dart sequentially, then add T010 to chat_cubit.dart as the final cubit edit before tests.

### Phase 5 — all polish tasks parallel-safe

```
T014, T015 ─┐
T016        ├─ all independent verification work; can run concurrently
T017        │
T018        │
            │
T019, T020  ┴─ run last as final gates
```

---

## Implementation Strategy

### MVP (Phase 1 → 2 → 3)

1. T001 (line-anchor check)
2. T002–T003 (foundation: flag declaration + reset clear)
3. T004–T008 (US1 cubit edits)
4. T009 (manual two-device acceptance — the canonical bug-fix demo)
5. STOP and demo. The original user complaint is resolved.

### Incremental Delivery

6. Phase 4 (US2) — strengthen the flag against backgrounding/lock. Strongly recommended before broad rollout.
7. Phase 5 (polish) — unit tests, single-device regression, lint. Required before merge but does not gate the demo.

### Stop-Gate Decisions

- After **MVP (US1)**: ship to internal dogfood if the team is OK with the lock-screen edge case being momentarily unfixed. Most users will not encounter it within the dogfood window.
- After **US2**: ship to production. Feature is complete per the spec.
- After **Polish**: merge to main.

---

## Task Count Summary

| Phase | Tasks | Notes |
|-------|-------|-------|
| 1: Setup | 1 (T001) | Line-anchor verification only |
| 2: Foundational | 2 (T002–T003) | Flag declaration + reset clear |
| 3: US1 (P1) | 6 (T004–T009) | The canonical fix; 5 cubit edits + 1 manual test |
| 4: US2 (P2) | 4 (T010–T013) | suspendDeliberateOpen + main.dart wire + manual test |
| 5: Polish | 7 (T014–T020) | 1 unit-test file (6 cases), 2 manual regressions, 1 dev-print, 2 lint/smoke gates |
| **Total** | **20 tasks** | 0 completed [ ]; 20 remaining [ ] |

### Parallel Opportunities Identified

- T011 (main.dart) is parallel-safe with all US1 cubit edits.
- T014–T018 in Polish are all parallel-safe with each other.
- US1 and US2 user stories are independent at the feature-shipping level but share the cubit file; coordinate the merge order.

### MVP Scope (recommended)

User Story 1 only (T001–T009) — total 9 tasks. Estimated half-day of focused work. Demonstrates the original bug fix end-to-end.

---

## Notes

- All file paths above are valid as of plan.md / data-model.md / contracts/ dated 2026-05-19. If a file is moved, update the path in the corresponding task before starting it.
- Constitution §IV-A (Socket.IO Map safety) does not apply to this feature — no new socket handlers are added. The existing `messageRead` and `messageDelivered` handlers in `lib/core/network/socket_service.dart` are untouched.
- Constitution §IX-A (Status promotion order) is preserved by the strict separation in T007: `markDelivered` stays unconditional, only `markRead` is gated.
- Constitution §V-A (Logout teardown order) is preserved by T003: the flag is cleared inside the existing `ChatCubit.reset()` step, before any later step in the global logout sequence.
- The feature is small enough that the entire implementation will likely complete in one to two focused sessions. Stop at the MVP checkpoint to validate independently before committing to Phase 4 and 5.
