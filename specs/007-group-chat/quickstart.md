# Quickstart: Group Chat + Group Calls + Recording

**Phase 1 output** | Generated: 2026-05-14

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

### Phase B: Group Calls
13. Re-add B for a fresh state. Add a third device C as user C.
14. From A: in the group chat, tap "Start Video Call".
15. Devices B and C both see an incoming-group-call screen with caller name and group name (NEW).
16. B accepts; C accepts a few seconds later (late join — FR-025). ✅ A sees B's tile appear, then C's. All three can hear and see each other.
17. From B: mute mic and toggle camera off. ✅ A and C see B's mic/camera indicators update.
18. From C: leave the call. ✅ A and B continue; C's tile disappears (FR-026).
19. From A: leave. ✅ B is the last participant and the call auto-ends (FR-026); B's UI returns to the group chat.

### Phase C: Recording
20. Start a new group call (any 2+ participants).
21. From A: tap "Record" in the call toolbar. ✅ A red REC banner appears at the top of every participant's screen with text like "A is recording" (FR-033).
22. Talk for ~30 seconds; tap "Stop" on A. ✅ Banner disappears for all (FR-034).
23. Open the new Recordings list (from the call screen toolbar or group info). ✅ The recording appears with the default name "Recording <YYYY-MM-DD HH:mm>", correct duration, audio playback works.
24. Rename and delete a recording — both succeed locally.
25. Verify file location: `<app-docs-dir>/recordings/<uuid>.m4a` exists and is **never** uploaded (network inspector shows no requests carrying the file).

### Phase D: 1-to-1 Regression Pass (must not break)
26. Send a text message in a private chat → status promotes pending → sent → delivered → read.
27. Send media in a private chat → preview and gallery open work.
28. Start a 1-to-1 voice call → both sides connect via LiveKit, mute/end controls work.
29. Start a 1-to-1 video call → same, plus camera toggle.
30. Log out from one device → push notifications stop, FCM token is unregistered (Constitution §V-A, §V-B).

---

## 4. Common Local Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Group call screen stays "Connecting…" forever | LiveKit WS URL mismatch or token invalid | Verify `LIVEKIT_WS_URL` matches in both Flutter `.env` and backend `.env` |
| Sender name label missing on inbound bubbles | `senderPhone` not arriving from socket OR `ChatSession.type != GROUP` locally | Inspect socket payload for `senderPhone`; confirm local room has `type: 'GROUP'` (it is upserted from the JSON during room sync) |
| Blue ticks never appear in groups | Backend `markMessagesRead` not emitting `readByCount`/`participantCount` | Check `chat.service.ts` change; verify socket payload in the Flutter console log |
| REC banner shows on recorder but not others | `groupCallRecordingStateChanged` socket emit failing | Verify the event is in `socket_events.dart` constants and the gateway broadcasts to all participants, not just the recorder |
| Recording file not appearing in list after stop | DB row not inserted OR migration v9 not applied | Run with a fresh database; check migration log; verify `recordings` table exists with `SELECT * FROM recordings` (via sqflite inspector) |

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
