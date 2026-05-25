# Research: Screen Sharing in Calls (011)

## Decision 1 — Use LiveKit's native screen-share API

**Decision**: Use `LocalParticipant.setScreenShareEnabled(bool, screenShareCaptureOptions: ScreenShareCaptureOptions(captureScreenAudio: <bool>))` from `livekit_client: ^2.6.4`.

**Rationale**: The entire call stack (1-on-1 AND group) already runs on a single `Room` instance via `LivekitVideoCallRepositoryImpl`. LiveKit's `setScreenShareEnabled`:
- Internally invokes the OS-level screen-capture picker (ReplayKit on iOS, `MediaProjection` consent on Android).
- Publishes the captured frames as a new video track with `TrackSource.screenShareVideo`.
- With `captureScreenAudio: true`, additionally publishes an audio track with `TrackSource.screenShareAudio`.
- Both tracks are routed through LiveKit's existing SFU, so adaptive bitrate / dynacast / connection-loss reconnection all work without extra code.

This single API call covers FR-002, FR-003, FR-013a in one line per direction.

**Alternatives considered**:
- Raw `flutter_webrtc` `MediaStream` + manual SDP negotiation: would require building a parallel transport for screen tracks, then publishing through LiveKit anyway. Rejected as duplicative.
- The local `flutter_screen_recording` package: it captures to a local file for the call-recording feature (010); it is not a live transport. Not applicable.

---

## Decision 2 — Identify screen tracks on receivers via `TrackSource`

**Decision**: On receiving clients, iterate `participant.videoTrackPublications` and check `pub.source == TrackSource.screenShareVideo` (or `screenShareAudio` for audio). Each match becomes a `ScreenShareTile` instead of being lumped into the camera tile.

**Rationale**: LiveKit tags every track publication with its source at publication time; receivers see the source via `TrackPublication.source` without any extra signaling. This perfectly matches FR-004 ("appears as a new participant tile, distinct from the sharer's camera tile") and FR-005 ("sharer's camera tile continues to display").

**Alternatives considered**:
- Use a custom track name / metadata prefix: brittle and reinvents what LiveKit already does.
- Treat the screen share as a "virtual second participant" by joining a second LiveKit identity: high complexity, doubles billing per participant, breaks the "one identity per user" model in the call cubit.

---

## Decision 3 — Backend-authoritative "one share at a time" via new socket event

**Decision**: Add `screenShareStateChanged` socket event. Client emits on share-start/stop. Backend keeps a single key per call (`screenshare:active:{roomId} → userId`) in Redis with a TTL that matches the call lifecycle. Backend rejects a start request if the key is already set to a different userId, sending `screenShareRejected` back to the requester.

**Rationale**: FR-012 requires "at most one share at a time" globally per call. If two participants tap the share icon within the same socket round-trip, only a backend-enforced lock can deterministically choose one winner; without it, both clients would publish screen tracks to LiveKit and the UI would have to repair the inconsistency. Redis is already in use for OTP storage, so no new infrastructure.

**Alternatives considered**:
- Client-only consensus (each client tracks `activeSharerUserId` and self-rejects): races on near-simultaneous taps. Rejected.
- Use LiveKit's `Room.data` payload: works for advisory state but provides no atomic "first-writer-wins" guarantee.
- Backend lock without re-broadcast (only respond to the emitter): receivers would need to discover the sharer by polling LiveKit track events, which is also racy. The chosen approach broadcasts to ALL participants so the UI knows immediately.

---

## Decision 4 — iOS Broadcast Extension target with App Group IPC

**Decision**: Add a new iOS target `ScreenShareBroadcast` of type "Broadcast Upload Extension" (ReplayKit). Wire an App Group (e.g., `group.com.cirochat.shared`) shared between the main app target and the extension target. The extension uses the LiveKit-provided `SampleHandler` template that forwards captured `CMSampleBuffer`s to LiveKit's IPC channel.

**Rationale**: Apple does not permit in-process screen capture for non-system apps. The only path is a separate Broadcast Upload Extension running in a sandboxed process, communicating with the main app via an App Group. LiveKit's iOS SDK supplies the `SampleHandler` boilerplate; the work is target setup, entitlement plumbing, and code signing.

**Alternatives considered**:
- `RPScreenRecorder.shared().startCapture(...)` (in-process API): only captures THE APP'S OWN screen — not the system screen, not other apps. Useless for "share what I'm doing across my whole device" use case.
- Third-party plug-in: livekit_client already provides Broadcast Extension support; adding another plug-in would conflict.

---

## Decision 5 — Android `FOREGROUND_SERVICE_MEDIA_PROJECTION` + notification channel

**Decision**: Add to `AndroidManifest.xml`:
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />`
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />` (required from Android 14)
- A `<service>` declaration for LiveKit's foreground service class with `android:foregroundServiceType="mediaProjection"`.

Notification channel: create at app startup; LiveKit's foreground service uses it for the persistent "Sharing your screen" notification while the share is active.

**Rationale**: Android 10+ requires `MediaProjection` to run via a foreground service so the user can dismiss the share via the system notification (FR-008). Android 14+ requires the specific `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission. livekit_client expects this manifest setup.

**Alternatives considered**:
- Skip the foreground service: the share would terminate when the app backgrounds (violates FR-015 / Story 4).
- Custom service implementation: livekit_client already provides one; reinventing it adds maintenance burden.

---

## Decision 6 — Pre-share modal sheet captures the audio toggle

**Decision**: When the share icon is tapped (and no one else is sharing), present a `showModalBottomSheet` with `ScreenShareToggleSheet`. Two primary buttons:
- *"Share screen only"* → `startScreenShare(withDeviceAudio: false)`
- *"Share screen + device audio"* → `startScreenShare(withDeviceAudio: true)`

The OS permission dialog appears only AFTER the user picks an audio mode, because LiveKit needs to know whether to set up audio capture before triggering the picker.

**Rationale**: Per FR-013, the choice is per-share. A modal sheet is faster than a settings screen and matches the user's mental model ("I just tapped share — what should happen next?"). Pinning the choice BEFORE the OS picker also means we don't need to roll back the picker if the user mis-toggles afterward.

**Alternatives considered**:
- A settings page with a default "always share audio" preference: adds an extra screen for a per-share decision; rejected.
- A long-press menu on the share icon: hidden affordance, fails discoverability.
- Inline two icons (one for video-only, one for video+audio): clutters the in-call toolbar.

---

## Decision 7 — Per-receiver audio mute is local-only

**Decision**: Each receiving client maintains a local `Set<String> mutedScreenAudioBySharerId` in the cubit. When the user taps the mute icon on a `ScreenShareTile`, the cubit:
1. Adds/removes the sharer's userId from the set.
2. Locates the corresponding `RemoteAudioTrack` (via `participant.audioTrackPublications.firstWhere(source == screenShareAudio)`) and calls `.mute()` / `.unmute()` on the publication. LiveKit's `mute()` on a `RemoteTrack` is a local-only operation that does NOT propagate to the sharer or other receivers.

**Rationale**: FR-013b explicitly requires per-receiver mute that does not affect other receivers or the sharer. LiveKit's `RemoteTrackPublication.mute()` documentation confirms it is local-only — it stops the SDK from decoding the track on this device without affecting the publishing track.

**Alternatives considered**:
- Adjusting the audio gain locally: works but is more code than the SDK's built-in mute.
- Per-receiver mute broadcast as a socket event: violates FR-013b (would affect other receivers). Rejected.

---

## Decision 8 — Screen-share teardown integrates with existing call lifecycle

**Decision**: Add `if (state.isLocallySharingScreen) await _repo.setScreenShareEnabled(false);` BEFORE the existing room-disconnect call in:
- `CallCubit.endCall()`
- `CallCubit.leaveGroupCall()`
- `CallCubit.reset()`
- `MainApp` lifecycle observer (when `state == AppLifecycleState.detached`)

The constitution's V-A global logout sequence already runs `CallCubit.reset()` as step 2, so logout teardown is automatically covered.

**Rationale**: A screen track left running after the call ends would attempt to publish to a disconnected room, log noisy errors, and on iOS leave the Broadcast Extension banner indefinitely until the user manually dismisses it. Stopping the track first ensures a clean shutdown sequence.

**Alternatives considered**:
- Rely on LiveKit's `Room.disconnect()` to teardown the track implicitly: works for the LiveKit side but doesn't stop the OS-level broadcast on iOS until LiveKit's SDK explicitly tells the extension to stop. Explicit stop is more reliable.
