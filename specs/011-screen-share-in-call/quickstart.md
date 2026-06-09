# Quickstart: Testing Screen Sharing in Calls (011)

## Prerequisites

- Two physical devices (one iOS, one Android ideally, or two of either).
- Backend running with Redis available.
- LiveKit cloud project credentials wired into `.env` (already present).
- iOS device: development team selected and Broadcast Extension target signed.

---

## Scenario 1 — Start and stop a video-only share (Story 1)

1. Device A: sign in as user A. Start a 1-on-1 call with user B (Device B).
2. Both devices answer. Cameras visible on both sides.
3. Device A: tap the new screen-share icon in the in-call toolbar.
4. The "Share with audio?" bottom sheet appears. Tap **Share screen only**.
5. iOS: the ReplayKit picker appears → confirm. Android: the MediaProjection consent dialog appears → confirm.
6. Within 3 seconds, Device B's grid shows a NEW tile labelled "User A • Screen" alongside User A's existing camera tile (Story 2 / SC-002).
7. Device A's UI shows a persistent "You are sharing your screen" banner; the share icon is in its ON state (FR-006).
8. Device A: tap the share icon again. Within 2 seconds, the tile disappears from Device B (FR-007 / SC-003).

---

## Scenario 2 — Share with device audio (FR-013 toggle ON)

1. Continue from Scenario 1 (call still active, no one sharing).
2. On Device A, open a YouTube/Spotify clip in another app and pause it.
3. Tap the share icon on Device A → bottom sheet → tap **Share screen + device audio**.
4. Grant the OS permission.
5. Background Device A's app and resume playback of the clip.
6. On Device B, hear the clip's audio through the call's audio output AND see a small speaker icon on the "User A • Screen" tile.
7. On Device B, tap the speaker icon. The clip audio mutes ONLY on Device B (FR-013b). If a third device were present, it would still hear it.
8. Tap again to unmute. Audio returns.

---

## Scenario 3 — One-share-at-a-time conflict (FR-012)

1. Three-way group call between Devices A, B, C.
2. Device A: start a share (any audio mode).
3. While A is sharing, Device B taps the share icon.
4. Device B sees the audio-toggle sheet, picks an option. Backend rejects.
5. Device B sees a SnackBar: **"User A is already sharing. Ask them to stop first."**
6. Device B's icon stays OFF; no LiveKit picker appears (the rejection happens before the OS prompt).
7. Device A: stop share.
8. Device B: tap share again. Now succeeds — toggle sheet → permission → tile appears on A and C.

---

## Scenario 4 — Permission denial (Story 3)

1. Fresh install of the app on a new device. Sign in. Start a call.
2. Tap the share icon → toggle sheet → "Share screen only".
3. When the OS picker appears, tap **Cancel** (iOS) or **Don't allow** (Android).
4. The app does NOT crash.
5. A SnackBar appears: **"Permission required to share your screen. Enable it in device settings."**
6. The share icon remains in its OFF state. The user can re-tap to try again.

---

## Scenario 5 — Sharer leaves call mid-share (FR-010 / SC-007)

1. With A sharing and B viewing, force-kill the app on Device A.
2. Within 5 seconds, the share tile disappears from Device B's grid.
3. Device A's camera tile also disappears (existing call-leave behaviour).
4. On the backend, `redis-cli GET screenshare:active:{chatRoomId}` returns `(nil)` — the lock was released by the disconnect handler.

---

## Scenario 6 — App backgrounding during share (Story 4 / FR-015)

1. Device A starts sharing.
2. Press home on Device A. Open another app.
3. Device B continues to see the new app on the share tile in real time.
4. On Android, the persistent foreground-service notification "Sharing your screen" appears in the notification shade. Tapping it does NOT terminate the share.
5. Tap the notification's STOP action — the share ends, Device A's app sees the OFF icon state, Device B's tile disappears (FR-008).

---

## Scenario 7 — Call recording while someone is sharing

Out of scope for this spec — verify only that the recording feature continues to record the call audio without crashing. Interaction polish ships in a follow-up.

---

## Backend smoke check

After Scenarios 1, 3, and 5, run:

```bash
redis-cli KEYS 'screenshare:active:*'
```

After a clean stop or a sharer-disconnect, this should return no entries
(zombie lock check). If a lock remains, the cleanup path in
`chat.gateway.ts` is broken.

---

## Scenario 8 — Before/after performance comparison (SC-005, FR-016)

Methodology — same hardware, same network, two distinct app builds.

**Baseline (pre-merge build, screen sharing not yet shipped)**:

1. Two devices in a 1-on-1 video call for 60 seconds.
2. On Device B, observe Device A's camera tile and record:
   - Subjective frame-rate notes (smooth / occasional stutter / visibly choppy).
   - Subjective audio quality notes (clear / occasional artifact / degraded).
   - If available, use the LiveKit debug overlay or any frame-stats hook to capture an objective FPS sample.
3. Repeat 3 times; record median.

**Post-merge (this branch built and installed on both devices)**:

1. Repeat the baseline measurement WITHOUT screen sharing first — confirm parity with the baseline build.
2. Start a screen + device audio share on Device A. On Device B, observe BOTH Device A's camera tile AND the screen-share tile.
3. Record the same frame-rate and audio-quality notes for the camera tile (NOT the screen-share tile, which is the new content).
4. Repeat 3 times; record median.

**Pass criterion**: the post-merge camera-tile frame rate and audio quality must not be visibly worse than the baseline. Any visible degradation that a non-expert observer can detect blocks release.

**Why this matters**: SC-005 / FR-016 require zero degradation of the existing call experience. Without a controlled before/after comparison, "no degradation" is unverifiable and the SLA is hand-wavy.
