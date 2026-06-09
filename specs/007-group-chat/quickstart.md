# Quickstart: Group Chat + Group Calls + Recording

**Phase 1 output** | Generated: 2026-05-14 | Revised: 2026-05-16

> **Revision (2026-05-16)**: Phase C expanded — recording now auto-formats by call type,
> saves to gallery/Downloads, AND shares to group chat. Added Phase B test for Join Call
> button visibility (FR-038).

This guide shows how to develop, run, and smoke-test the feature end-to-end.

---

## 1. Prerequisites

### Tools
- Flutter SDK 3.x
- Dart 3
- Node.js 20+ (backend)
- MongoDB (local or Atlas — backend connection string already in backend `.env`)
- Two physical devices OR two simulators/emulators (calls cannot be tested on a single device).

### Required environment

Flutter `.env` at project root (already present from prior work):
```
API_URL=https://<your-ngrok-or-local-host>
LIVEKIT_WS_URL=wss://ciro-chat-qc2pe2cz.livekit.cloud    # NEW: move from hardcoded
```

Backend `.env` (already present, verify keys):
```
LIVEKIT_WS_URL=wss://ciro-chat-qc2pe2cz.livekit.cloud
LIVEKIT_API_KEY=...
LIVEKIT_API_SECRET=...
```

---

## 2. Run the Stack Locally

### Backend
```
cd "/Volumes/Zeyad/Documents/work/Node js/chat-app-backend"
npm install
npm run start:dev
```
Backend runs on the port configured in its `.env` (default 3000).

### Flutter
```
cd "/Volumes/Zeyad/Documents/work/Flutter/ciro-chat-app"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d <device-id-A>
# in another terminal:
flutter run -d <device-id-B>
```

---

## 3. Feature Smoke Tests

### Phase A: Group Messaging
1. Device A — log in as user A.
2. Device B — log in as user B.
3. On Device A: Conversations → "New Group" → enter name "Test Group" → pick an avatar from gallery (NEW) → select user B → tap Create.
4. Verify on Device B: group appears in conversations list within ~2 s, with the chosen avatar visible.
5. Open the group on both devices.
6. From A: send a text message. ✅ B sees it within 2 s with "A" as the sender label above the bubble (NEW).
7. From A: confirm tick progression: single grey (sent) → double grey (delivered) → double blue (read after B opens the chat).
8. From B: while A is viewing the chat — type → ✅ A sees "B is typing…".
9. Send an image from A → ✅ B sees the image; tapping opens it full-screen.

### Phase A — Group Info
10. From A (admin): open group info → edit group name to "Renamed" → save. ✅ Both devices see "Renamed" in the conversations list within 3 s.
11. From A: tap user B → "Remove from group" → confirm. ✅ B's group disappears from interactive conversations; if B re-opens it (e.g., via local list), the chat shows "You are no longer a participant" and input bar is disabled (FR-030).
12. Re-add B (POST /chat/group/:id/add). From B: choose "Leave Group" → confirm. ✅ A sees B removed; B's group is now read-only (FR-029).

### Phase B: Group Calls + Join Call Button (FR-038)
13. Re-add B for a fresh state. Add a third device C as user C.
14. From A: in the group chat, tap "Start Video Call".
15. Devices B and C both see an incoming-group-call screen with caller name and group name (NEW).
16. **(FR-038)** On Device C: instead of accepting via the incoming screen, close the screen and open the group chat for that group. ✅ A green "Join Call" pill is visible in the AppBar within 5 s of the call starting (SC-008). Tap it → C joins the call.
17. B accepts; C is already in via the Join Call button. ✅ A sees B's tile appear, then C's. All three can hear and see each other.
18. From B: mute mic and toggle camera off. ✅ A and C see B's mic/camera indicators update.
19. From C: leave the call via the in-call End button. ✅ A and B continue; C's tile disappears (FR-026). On Device C, the group chat AppBar still shows "Join Call" (call still active for A & B).
20. From A: leave. ✅ B is the last participant and the call auto-ends (FR-026); B's UI returns to the group chat. **(FR-038)** Within 5 s, the Join Call pill disappears from all three devices' AppBars (SC-008).
21. **Hydration test**: start a fresh call with A & B. Force-quit and relaunch the app on Device C. Open the group chat. ✅ Within 5 s of socket reconnect, the Join Call pill appears (replay-on-connect, RD-4).

### Phase C: Recording — Voice Call (Audio Format)
22. Start a new **voice** call (any 2+ participants).
23. From A: tap "Record" in the call toolbar. ✅ A red REC banner appears at the top of every participant's screen with text like "A is recording" (FR-033).
24. Talk for ~30 seconds; tap "Stop" on A. ✅ Banner disappears for all (FR-034).
25. **(FR-035 share)** On all participants' devices, within 30 s of A's stop (SC-007), a media message appears in the group chat thread with the recording. ✅ B and C can tap and play it back in-place.
26. **(FR-035 save)** On Device A: open the Files app (iOS) or Downloads folder (Android) → confirm a file named `Recording <timestamp>.m4a` is present.
27. **(FR-036)** From A: open the Recordings list → ✅ the recording appears with status icon ✓ (shared), correct duration, audio playback works, long-press shows Rename/Delete.

### Phase C-2: Recording — Video Call (Video Format) (FR-032a)
28. Start a fresh **video** call with the same 3 devices.
29. From A: tap "Record". ✅ REC banner appears for all (FR-033); iOS may show its system ReplayKit banner additionally — that's expected.
30. Talk for ~30 seconds (move around — record actual video content); tap "Stop".
31. **(FR-032a)** Within 30 s (SC-007), a video media message appears in the group chat. ✅ All participants can play it inline (uses `VideoPlayerController.file`, Constitution §VIII-C).
32. **(FR-035 save)** On Device A: open Photos (iOS) or Gallery (Android) → ✅ a new video appears with thumbnail and is playable.
33. **(FR-036)** Recordings list on A shows the new video recording with status ✓ (shared).

### Phase C-3: Recording — Retry on Upload Failure (RD-7)
34. Repeat steps 22–24 but disable Wi-Fi/data on Device A immediately after tapping "Record" (before "Stop"). Tap "Stop" with network off.
35. ✅ The recording row appears in the Recordings list with status ⚠ (failed).
36. Re-enable network → long-press the failed row → "Retry share". ✅ Status transitions ⟳ uploading → ✓ shared; the media message appears in the group chat.

### Phase C-4: Recording — Late Joiner Sees REC Banner (RD-5)
37. Devices A & B start a video call. From A: tap "Record".
38. From C: tap the Join Call AppBar pill to join the active call. ✅ The REC banner is visible on C immediately after the call view appears — no delay (closes the late-joiner gap M2 from /speckit-analyze).

### Phase D: 1-to-1 Regression Pass (must not break)
39. Send a text message in a private chat → status promotes pending → sent → delivered → read.
40. Send media in a private chat → preview and gallery open work.
41. Start a 1-to-1 voice call → both sides connect via LiveKit, mute/end controls work.
42. Start a 1-to-1 video call → same, plus camera toggle.
43. Log out from one device → push notifications stop, FCM token is unregistered (Constitution §V-A, §V-B). If a call/recording is in progress at logout, both stop cleanly before token deletion.

---

## 4. Common Local Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Group call screen stays "Connecting…" forever | LiveKit WS URL mismatch or token invalid | Verify `LIVEKIT_WS_URL` matches in both Flutter `.env` and backend `.env` |
| Sender name label missing on inbound bubbles | `senderPhone` not arriving from socket OR `ChatSession.type != GROUP` locally | Inspect socket payload for `senderPhone`; confirm local room has `type: 'GROUP'` (it is upserted from the JSON during room sync) |
| Blue ticks never appear in groups | Backend `markMessagesRead` not emitting `readByCount`/`participantCount` | Check `chat.service.ts` change; verify socket payload in the Flutter console log |
| REC banner shows on recorder but not others | `groupCallRecordingStateChanged` socket emit failing | Verify the event is in `socket_events.dart` constants and the gateway broadcasts to all participants, not just the recorder |
| Recording file not appearing in list after stop | DB row not inserted OR migration v9 not applied | Run with a fresh database; check migration log; verify `recordings` table exists with `SELECT * FROM recordings` (via sqflite inspector) |
| "Join Call" AppBar pill never appears | `groupCallActive` socket event not received | Inspect socket log for `groupCallActive`; verify `ChatCubit._activeCallRoomIds` is updated; check `socket_events.dart` constant matches backend emit name |
| Video recording fails silently on Android | Missing `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission in AndroidManifest.xml | Add the permission and the foreground service declaration (RD-1) |
| Recording saved to gallery but never appears in chat | Upload succeeded but `sendMessage` failed | Open Recordings list — row should show ⚠ (failed); long-press → Retry share (RD-7) |
| Gallery save fails with "permission denied" on Android 13+ | `gal` requires `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` runtime permission | Ensure `gal` is initialized with `Gal.requestAccess()` before `Gal.putVideo()` |

---

## 5. Tasks Pre-Requisites for `/speckit-tasks`

Before generating tasks, ensure:
- ✅ Spec frozen (clarifications session complete)
- ✅ Plan complete (this file + research.md + data-model.md + contracts/)
- ✅ Constitution Check passes (no violations)
- ✅ All NEEDS CLARIFICATION markers resolved in spec

Then run:
```
/speckit-tasks
```
This will generate `specs/007-group-chat/tasks.md` with concrete, ordered, executable tasks based on the four phases (A, B, C, D) described in plan.md.
