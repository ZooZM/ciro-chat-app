# Quickstart: Multi-Device Read Suppression

**Feature**: 008-multidevice-read-suppression
**Date**: 2026-05-19

This file is a hands-on test plan for engineers. It covers the two-device acceptance scenarios from the spec (SC-001, SC-002, SC-003, SC-005), the single-device regression (FR-010, SC-003), and the unit-test matrix.

---

## 1. Setup

### Hardware

- **Device A**: any iOS or Android device with a unique screen (so you can see the sender-side ticks).
- **Device B**: a second physical device or a second emulator, signed in to the same account as Device A.
- **Device C** (optional, for the 1-to-1 regression with another user): a third device or emulator signed in to a different account, so Device C is "the recipient" in the single-device baseline.

### Build

```bash
flutter clean
flutter pub get
flutter run -d <device_A>
flutter run -d <device_B>
flutter run -d <device_C>   # only for §3 regression
```

### Account state

- Devices A and B: same account, both signed in concurrently.
- Device C: a different account, listed as a contact on the A/B account.
- Verify a 1-to-1 chat between (A/B account) and (Device C account) exists. If not, send one message to create the room.

---

## 2. Acceptance Test — Multi-Device Read Suppression (US1)

**Maps to**: SC-001, SC-002, FR-001, FR-003, FR-004.

### Steps

1. On both Device A and Device B, navigate to the same 1-to-1 chat with Device C. **Both screens MUST be showing the chat view.**
2. On Device C, send the message "hello A/B" to the A/B account.
3. On Device A, observe the message arrive. ✅ Note: in the sender's UI on Device C, the ticks transition to `delivered` (double grey).
4. **Critical**: on Device C, look at the sender-side ticks. They MUST stay at `delivered` and MUST NOT advance to `read` (double blue), even though both A and B currently have the chat visible.
5. On Device B, tap the back arrow / system back to return to the conversations list. **Do not tap the chat from the list yet.**
6. Wait 2 seconds. Re-confirm on Device C that the ticks are still `delivered`.
7. On Device B, tap the chat in the conversations list to re-enter it.
8. Within 2 seconds, the ticks on Device C MUST advance to `read` (double blue) — SC-002.

### Pass criteria

- Step 4: ticks at `delivered` ✅
- Step 6: ticks still at `delivered` ✅ (proves Device B's continued visibility alone does NOT count)
- Step 8: ticks at `read` within 2 s ✅

### Failure modes to watch for

- Ticks turn `read` at step 3: **bug**, the gating is not effective.
- Ticks never turn `read` at step 8: **bug**, `openRoom` is not setting the flag and triggering the batched `markRead`.
- Ticks turn `read` between step 4 and step 7 (without B leaving and returning): **bug**, the flag is set without an explicit deliberate-open trigger.

---

## 3. Acceptance Test — Backgrounding Does NOT Auto-Read (US2)

**Maps to**: SC-005, FR-002, FR-012.

### Steps

1. On Device B, navigate INTO the chat with Device C. Confirm any pending unread is marked read (deliberate-open on B has fired).
2. Lock Device B (press the power button) OR switch to a different app. Leave Device B's chat screen as the top-most route inside Ciro.
3. On Device C, send 3 messages over 30 seconds.
4. On Device C, confirm all 3 messages reach `delivered` (Device B's `markDelivered` continues to fire — FR-007). Confirm none of them advance to `read`.
5. Unlock Device B (or switch back to Ciro). Confirm the chat screen is still on top.
6. Wait 5 seconds. On Device C, the 3 messages MUST still be at `delivered`, NOT `read` — backgrounding cleared the flag, and resume does NOT re-set it.
7. On Device B, navigate back to conversations list, then re-enter the chat.
8. On Device C, all 3 messages MUST advance to `read` within 2 seconds (batched per FR-008).

### Pass criteria

- Step 4: all 3 at `delivered`, none at `read` ✅
- Step 6: still all at `delivered`, none at `read` ✅
- Step 8: all 3 at `read` within 2 s ✅

---

## 4. Single-Device Regression (FR-010, SC-003)

**Maps to**: FR-010, SC-003, Constitution §IX-C item 3.

### Steps

1. Sign out of Device B (or fully kill it). Leave only Device A as the sole signed-in device for the A/B account.
2. On Device A, navigate INTO the chat with Device C.
3. On Device C, send "regression check".
4. On Device A, observe the message appear.
5. On Device C, the ticks MUST advance to `read` within 2 seconds — identical to pre-feature behavior.
6. Lock Device A for 10 seconds, unlock, and re-enter the chat. Confirm no flicker, no error toast, no unexpected re-emission.

### Pass criteria

- Step 5 timing identical to baseline (today's timing measured on the same network) ✅

### Additional regression smoke

- Group chat from another spec (007) — confirm group reads still aggregate correctly when only one device of each member is involved.
- Recording media messages in groups (007) — confirm the `markRead` for a recording media message follows the same gated path.

---

## 5. Cold-Start Deliberate-Open Verification (FR-011)

### Steps

1. On Device A, navigate into the chat with Device C. (Auto-read fires for any existing unread.)
2. Force-kill Ciro on Device A (swipe away in app switcher).
3. On Device C, send 2 messages while Device A is killed.
4. On Device A, re-launch Ciro. If the app restores the last route (chat screen), the messages should mark read within 2 seconds of launch (cold start with last-route restoration counts as deliberate-open).
5. Alternatively, if the app launches to the conversations list, the messages stay at `delivered` until Device A taps the chat.

### Pass criteria

- Either path is acceptable. The behavior MUST be consistent with whatever last-route restoration the app implements.

---

## 6. Unit Tests

Run from repo root:

```bash
flutter test test/features/chat/chat_cubit_deliberate_open_test.dart
```

The test file covers T-DO-1 to T-DO-6 from [contracts/internal.md](contracts/internal.md). All 6 tests MUST pass before this feature is merged.

---

## 7. Telemetry Spot-Check (Dev Build Only)

In a dev build, watch the `flutter run` console output while running §2 steps:

```
[ChatCubit][DEBUG] Suppressed auto-markRead for message <id> in room <id> (deliberateOpen=false)
```

This line is emitted by the new `debugPrint` in the gated branch (Phase E in plan.md). Its presence on the Device B run confirms the flag is doing its job. Absence of this line on Device A (in §4) confirms single-device behavior is unchanged.

---

## 8. Sign-Off Checklist

- [ ] §2 passes on iOS + Android.
- [ ] §3 passes on iOS + Android.
- [ ] §4 passes on iOS + Android.
- [ ] §5 verified for the app's last-route restoration policy.
- [ ] §6 unit tests green in CI.
- [ ] No regression in existing chat / group / call flows on the A/B device after this feature is enabled (smoke test from `specs/007-group-chat/quickstart.md` §3 Phase D).
