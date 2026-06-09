# Feature Specification: Screen Sharing in Calls

**Feature Branch**: `011-screen-share-in-call`
**Created**: 2026-05-24
**Status**: Draft
**Input**: User description: "Add a screen-sharing capability to in-call experience. A new icon in the in-call UI lets the user start (and stop) sharing their device screen with the other participants. While someone is sharing, their shared screen appears to the other participants as a new participant tile in the call grid (visually a 'new person' in the call), distinct from the sharer's camera tile. Anyone in the call must be able to start sharing; multiple participants sharing simultaneously should be supported or explicitly disallowed (clarify). Requires platform permission flows on iOS and Android."

## Clarifications

### Session 2026-05-24

- Q: Which call modes should screen sharing be available in? → A: Both 1-on-1 (peer-to-peer) calls AND group calls (LiveKit-mediated) — full coverage from day one
- Q: How many participants can share their screen at the same time? → A: At most 1 share at a time per call. A second tapper sees "X is already sharing. Ask them to stop first." No displacement, no take-over.
- Q: Should the share include device audio? → A: User-toggled. Before starting a share, the sharer chooses "Share screen only" or "Share screen + device audio". When audio is included it travels as a SEPARATE audio track (not mixed into the call audio stream), so each receiver can independently mute it without affecting the sharer's voice.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start and stop sharing my screen (Priority: P1)

A participant in an active call can tap a screen-share icon in the in-call UI to begin sharing their device screen with everyone else in the call. The icon shows a clear ON/OFF state. The user can tap the same icon (or use the OS-level stop control) to end sharing at any time. While sharing, the sharer's own UI clearly indicates "you are sharing your screen" so they cannot accidentally expose private content without realizing it.

**Why this priority**: This is the core capability — without it the feature does not exist. Every other story depends on the ability to toggle sharing on and off.

**Independent Test**: Join a call. Tap the screen-share icon. Grant OS permission. The icon switches to its ON state, and a "you are sharing" indicator appears in the sharer's UI. Tap the icon again. The icon switches to OFF and the indicator disappears.

**Acceptance Scenarios**:

1. **Given** the user is in an active call and has not yet shared, **When** the user taps the screen-share icon and grants the OS-level permission, **Then** screen sharing begins, the icon changes to its ON state, and a "you are sharing" indicator is visible to the sharer.
2. **Given** the user is currently sharing their screen, **When** the user taps the screen-share icon again, **Then** screen sharing stops within 2 seconds, the icon returns to OFF state, and the indicator disappears.
3. **Given** the user is currently sharing, **When** the user ends sharing via the OS-level control (iOS Broadcast banner or Android notification), **Then** the in-app icon also returns to OFF state and the indicator disappears.
4. **Given** the user taps the screen-share icon, **When** the OS permission dialog appears and the user denies the permission, **Then** the app does not crash, displays a clear message that screen-share permission is required, and the icon remains in OFF state.

---

### User Story 2 - See other participants' shared screens as separate tiles (Priority: P1)

When someone else in the call starts sharing their screen, every other participant sees the shared screen appear as a new participant tile in the call grid — distinct from the sharer's camera tile (which continues to display their face/video). The shared-screen tile is visually labelled so it is clear that this tile is a screen share and which participant is sharing.

**Why this priority**: Equal to Story 1 because the feature only delivers value if other participants can actually see the shared content. A "share" that nobody else can see is useless.

**Independent Test**: With two devices in a call, start sharing from device A. On device B, observe that a new tile appears in the call grid labelled as device A's shared screen, alongside device A's existing camera tile. Stop sharing on A. The shared-screen tile disappears from B's grid; device A's camera tile remains.

**Acceptance Scenarios**:

1. **Given** two participants are in a call and only their cameras are visible, **When** participant A starts sharing their screen, **Then** participant B sees a new tile appear in their call grid showing the shared content, labelled with participant A's name and an indicator that this is a screen share.
2. **Given** the previous state, **When** participant A stops sharing, **Then** the shared-screen tile disappears from participant B's grid but participant A's camera tile remains.
3. **Given** participant A's camera tile is visible on participant B's screen, **When** participant A starts a screen share, **Then** participant A's camera tile continues to be visible (it is not replaced by the share); the share is shown as an additional tile.
4. **Given** participant A is sharing their screen, **When** participant A's device drops the call (network failure, app killed, leaves the call), **Then** the shared-screen tile disappears from all other participants' grids within 5 seconds.

---

### User Story 3 - First-time permission flow handled gracefully (Priority: P2)

The first time a user attempts to share their screen on a given device, the OS prompts for the required permission (iOS Broadcast picker; Android `MediaProjection` consent dialog). The app handles all three outcomes — granted, denied, dismissed — without crashing and with a clear next step for the user.

**Why this priority**: Lower than P1 because it is a one-time edge case per device, but the experience matters: a crash or confusing error at first-share will block adoption.

**Independent Test**: Fresh install. Join a call. Tap screen-share for the first time. Verify the OS dialog appears. Test each outcome (allow, deny, dismiss) and confirm app behavior matches expectations below.

**Acceptance Scenarios**:

1. **Given** this is the user's first attempt to share on this device, **When** the OS permission dialog appears and the user allows, **Then** the share begins normally.
2. **Given** the OS permission dialog is showing, **When** the user denies the permission, **Then** the share does not begin, an in-app message explains how to grant the permission later in device settings, and the user can tap-to-retry without restarting the app.
3. **Given** the OS permission dialog is showing, **When** the user dismisses it without choosing, **Then** the share does not begin and the in-app UI returns to its pre-tap state (no error message, no crash).

---

### User Story 4 - Sharing survives app backgrounding (Priority: P3)

If the sharer backgrounds the app (presses home, switches to another app, or locks/unlocks the screen) while sharing, the share continues uninterrupted and other participants continue to see the live screen content. The sharer can switch between apps to actually share what they want to show.

**Why this priority**: A "share" that only works while the sharer is staring at the in-call screen is useless — the whole point is to show something else. P3 because the underlying OS broadcast / foreground-service plumbing carries most of the load; the app mostly just needs to not tear down its own state on background.

**Independent Test**: With two devices in a call, start sharing on device A. Press home on A and open a different app (e.g., a browser). On device B, verify the shared tile is still showing and now displays device A's other app, in real time. Return to the call app on A. Sharing should still be active.

**Acceptance Scenarios**:

1. **Given** the sharer is actively sharing, **When** the sharer backgrounds the call app and opens another app, **Then** the other participants continue to see the shared screen showing the new app.
2. **Given** the sharer is actively sharing, **When** the device is locked and then unlocked, **Then** screen sharing resumes immediately when unlocked (or continues uninterrupted, depending on OS lock-screen behaviour).

---

### Edge Cases

- **Sharer leaves the call mid-share**: the shared-screen tile is removed from all other participants' grids promptly (within 5 seconds), the same way a camera tile is removed when a participant leaves.
- **Network failure mid-share**: handled by the existing call-reconnect logic; on reconnect, the share is automatically re-established only if the OS-level broadcast is still active. Otherwise, the sharer must re-initiate.
- **Incoming phone call while sharing**: the OS interrupts the call (existing behaviour); the share ends with the call. No new behaviour required.
- **Sensitive on-screen content (passwords, banking apps)**: the OS-level permission dialog at first-use warns the user. The app does not perform any content-aware filtering; this is the user's responsibility, consistent with industry-standard screen-sharing apps.
- **Device rotation during share**: shared content reflows to the new orientation; other participants see the reflowed content.
- **Sharer's app crashes mid-share**: the OS tears down the broadcast; other participants see the shared tile disappear within 5 seconds.
- **Recording the call while someone is sharing**: out of scope for this spec; interaction with the existing call recording feature will be addressed separately if needed.
- **In a 1-on-1 call vs. a group call**: see Functional Requirements for scope clarification.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The in-call UI MUST display a screen-share icon visible to every participant, regardless of whether they are the call host or a guest.
- **FR-002**: Tapping the screen-share icon when the user is not currently sharing MUST initiate the OS-level screen-capture permission flow (iOS Broadcast picker, Android `MediaProjection` consent).
- **FR-003**: After permission is granted, the user's device screen MUST be published to the call as a media stream distinct from the user's camera stream.
- **FR-004**: To every other participant in the call, the shared-screen stream MUST appear as a new participant tile in the call grid, visually labelled to identify both that it is a screen share and which participant is sharing.
- **FR-005**: While a participant is sharing, that participant's own camera tile MUST continue to display their camera feed; the share MUST NOT replace the camera tile.
- **FR-006**: The sharer's own in-call UI MUST clearly indicate that they are currently sharing their screen (persistent indicator visible during the call), so the sharer cannot forget they are still sharing.
- **FR-007**: Tapping the screen-share icon while sharing MUST stop the share within 2 seconds and remove the shared-screen tile from all other participants' grids within 5 seconds.
- **FR-008**: An OS-level stop control (iOS Broadcast banner, Android persistent notification) MUST also be able to end the share; the in-app icon and indicator MUST update accordingly within 2 seconds of the OS-level stop.
- **FR-009**: If the user denies the OS-level screen-capture permission, the app MUST NOT crash, MUST surface a clear in-app message explaining that the permission is required and how to grant it later, and MUST return the icon to its OFF state.
- **FR-010**: If the sharer leaves the call (drops, force-kills the app, taps "end call"), the shared-screen tile MUST be removed from all other participants' grids within 5 seconds.
- **FR-011**: When a screen share starts, every other participant in the call MUST receive a subtle visual notification that the share has begun (consistent with existing presence/connection notifications in the call UI).
- **FR-012**: At most one participant may share their screen at any given moment in a call. When a participant taps the screen-share icon while another participant is already sharing, the app MUST surface a message of the form "**[Name of current sharer] is already sharing. Ask them to stop first.**" and MUST NOT begin a new share. The current sharer is NOT displaced and no take-over flow is offered. The icon on the second tapper's device MUST remain in its OFF state.
- **FR-013**: Before each share starts, the sharer MUST be presented with a two-option choice: **"Share screen only"** or **"Share screen + device audio"**. The choice persists only for the duration of that share session (next share asks again, defaulting to the previous choice).
- **FR-013a**: When the sharer chooses "Share screen + device audio", the device audio (system sounds, audio from videos/music playing on the sharer's device) MUST be transmitted as a SEPARATE audio track from the call's voice audio. The sharer's microphone audio continues to flow through the existing call voice channel unchanged.
- **FR-013b**: Every receiving participant MUST see, on the shared-screen tile, a per-tile audio mute toggle that lets them mute the shared device audio independently — without affecting the sharer's voice audio. The mute setting is per-receiver and does not propagate to other receivers or to the sharer.
- **FR-013c**: When the sharer chooses "Share screen only", no shared-audio track is published. Receiving tiles do not show the per-tile audio mute toggle for that share.
- **FR-014**: Screen sharing MUST be available in both 1-on-1 (peer-to-peer) calls and group calls (LiveKit-mediated). The icon, sharer-side indicator, and receive-side tile rendering MUST behave identically across both modes, even though the underlying transport differs.
- **FR-015**: Background continuity: the share MUST continue uninterrupted when the sharer backgrounds the call app, locks the device, or switches to another app. The share ends only on explicit stop (in-app icon, OS stop control), call end, or app crash.
- **FR-016**: Screen sharing MUST NOT measurably degrade the existing call's audio quality or perceived video frame rate for other participants. The shared stream is in addition to, not in lieu of, the camera/audio streams already flowing.

### Key Entities

- **Screen Share Track**: A media stream originating from the sharer's device that carries their screen content. It is a peer to the sharer's existing camera and microphone tracks, not a replacement. Its lifecycle is: created on share-start → published to the call session → consumed by all other participants → torn down on share-stop or call-end.
- **Sharer Identity Marker**: Metadata associated with the screen-share track identifying which participant is sharing, used by the receiving clients to render the new tile with the correct label and grouping.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From the in-call screen, a user can start sharing in at most 2 taps (icon + permission grant) on first use, or 1 tap on subsequent uses.
- **SC-002**: From the moment a sharer taps the screen-share icon (after permission grant), other participants see the shared-screen tile appear within 3 seconds, with the shared content visible and updating in real time.
- **SC-003**: Stopping a share — whether via the in-app icon or the OS-level stop control — removes the shared-screen tile from all other participants' grids within 5 seconds.
- **SC-004**: ≥95% of share-start attempts that proceed past the OS permission dialog (i.e., the user granted permission) complete successfully without error. Measured post-release via support-ticket review and backend `chat.gateway` logs (no client telemetry SDK is added by this feature, consistent with feature 009's SC measurement approach).
- **SC-005**: Existing call audio quality and camera-tile frame rate, measured on the same device/network conditions before and after the feature ships, show no statistically significant degradation while a share is active.
- **SC-006**: Screen sharing continues uninterrupted for at least 5 continuous minutes of typical use (sharer switching between apps, locking/unlocking device) in 95% of tested sessions.
- **SC-007**: After a sharer leaves the call or their app crashes while sharing, no shared-screen tile remains visible on any other participant's grid for more than 5 seconds (no "ghost" tiles).

## Assumptions

- **Single-direction sharing per participant**: While a participant is sharing, they remain a participant who is also receiving the call's audio/video. They cannot share *to* themselves; the share is always *outbound* to other participants.
- **No mid-share permission revocation**: If the user navigates to OS settings and revokes the screen-capture permission while a share is active, the OS will end the broadcast and the app will handle this through the same code path as an OS-level stop.
- **No content moderation by the app**: Screen content is not inspected, filtered, watermarked, or modified by the app. The user is responsible for what they choose to share, the same as with any other screen-sharing tool.
- **Reuse of existing call infrastructure**: The call already supports multiple media tracks per participant (camera + microphone); adding a screen track is an extension of existing capacity, not a new transport.
- **Platform permission UI is OS-driven**: The app does not attempt to reimplement, decorate, or pre-empt the iOS Broadcast picker / Android `MediaProjection` consent dialog. Whatever the OS shows is what the user sees.
- **Existing reconnect logic applies**: The existing call reconnect flow (network drop, brief disconnects) applies to the screen track the same way it applies to camera/microphone tracks.
- **Out of scope for this spec**: Annotation on the shared screen, remote control of the sharer's device by other participants, pointer/cursor highlighting, selective window/app sharing (only full-screen sharing is in scope), recording specifically of the shared track, interaction with the call-recording feature.
- **Platform-cost note for FR-013 (device audio)**: Capturing device audio on iOS requires a Broadcast Extension target with the appropriate entitlement; this adds build, signing, and review complexity beyond what video-only screen capture would need. Android `MediaProjection` supports audio capture in the same permission flow but requires `RECORD_AUDIO` in addition to screen-capture consent. The toggle UX (FR-013) must surface these OS prompts the first time a user enables "Share screen + device audio".
