# Feature Specification: Native VoIP CallKit Integration

**Feature Branch**: `020-native-voip-callkit`  
**Created**: 2026-06-26  
**Status**: Draft  
**Input**: User description: "Elevate the calling feature to act as a native system VoIP call — lock-screen integration, in-app call history, background audio persistence, and hardware audio routing (Earpiece / Speakerphone / Bluetooth) with a speaker button in the call UI, plus an in-app Calls history screen."

## Clarifications

### Session 2026-06-26

- Q: How should the user control audio output routing (toggle vs. Bluetooth selection contradiction)? → A: Route picker sheet — the speaker button opens a sheet listing all available routes (Earpiece, Speakerphone, each connected Bluetooth device); the user selects one.
- Q: Where should completed/missed calls be recorded as "Call History"? → A: In-app history only (no OS system call log on either platform). Additionally, build a dedicated in-app "Calls" history screen as part of this feature (see FR-VoIP-04).
- Q: Which call types get native CallKit presentation? → A: One-to-one (1:1) voice & video calls use native presentation; group calls keep the existing in-app call screens.
- Q: What should the default audio route be when a call first connects? → A: Voice calls default to the earpiece; video calls default to the speakerphone. A connected Bluetooth device takes precedence over the default when present.

### Revision 2026-06-26 (post-implementation)

- Q: Should 1:1 calls also appear in the iOS Phone app's native Recents list? → A: Yes — revises the original "in-app only" decision above. 1:1 calls now appear in **both** the iOS native Recents (via CallKit `includesCallsInRecents: true`) and the in-app Calls history screen. Android is unaffected and remains in-app-only, since writing to the Android system call log requires the sensitive `WRITE_CALL_LOG` permission and Play Store justification that was the original reason for the in-app-only decision.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Native Incoming Call & In-App Call History (Priority: P1)

As a user, when someone calls me 1:1, I want the call to ring on my device's native lock screen — using the full-screen system call interface — and afterward to appear in the app's in-app Calls history, like a regular phone call.

**Why this priority**: This is the headline value of the feature. Without native presentation, the app cannot ring reliably when locked or backgrounded, and users cannot answer calls the way they expect from a phone. Everything else (routing, background audio, history screen) is meaningless if the call never reaches the user.

**Independent Test**: Lock the device, place a 1:1 call to the user from another account, and confirm the native call screen appears with the caller's name/avatar, the call can be answered or declined from the lock screen, and the completed/missed call is listed afterward in the in-app Calls history.

**Acceptance Scenarios**:

1. **Given** the recipient's device is locked, **When** an incoming 1:1 call arrives, **Then** the native full-screen incoming call UI is displayed on the lock screen with the caller's display name and avatar.
2. **Given** the native incoming call UI is showing, **When** the recipient taps Accept, **Then** the app opens directly into the active call screen and the call connects.
3. **Given** the native incoming call UI is showing, **When** the recipient taps Decline, **Then** the caller is notified the call was rejected and no call session is established.
4. **Given** an incoming call is not answered within the ring timeout, **When** the call ends, **Then** it is recorded as a missed call in the in-app Calls history.
5. **Given** a call has ended (answered or missed), **When** the user opens the in-app Calls history, **Then** the call appears with the correct contact, direction, outcome, and timestamp.

---

### User Story 2 - Seamless Background Audio (Priority: P2)

As a user, I want call audio to continue uninterrupted when I leave the app — switch to another app, lock the screen, or return to the home screen — so I can multitask during a call without dropping it.

**Why this priority**: A native-feeling call is expected to survive backgrounding. This depends on P1 being in place (a registered native call session) but delivers distinct, independently testable value: persistent audio.

**Independent Test**: Start a call, send the app to the background (home button / switch apps / lock screen), and confirm two-way audio continues without interruption for the duration, then return to the app and confirm the call is still active.

**Acceptance Scenarios**:

1. **Given** an active call, **When** the user sends the app to the background, **Then** audio continues in both directions without interruption.
2. **Given** an active call running in the background, **When** the user locks the screen, **Then** audio persists and call controls remain accessible from the lock screen / notification.
3. **Given** an active call running in the background, **When** the user returns to the app, **Then** the active call screen is restored with the correct elapsed time and call state.
4. **Given** an active call running in the background, **When** the user ends the call from the system call controls, **Then** the call terminates cleanly and resources are released.

---

### User Story 3 - Audio Output Routing with Speaker Button (Priority: P2)

As a user, I want a clearly visible speaker button in the active call screen so I can route call audio between the Earpiece, Speakerphone, and connected Bluetooth devices.

**Why this priority**: Core ergonomic control for any call. Independent of background and lock-screen work, but equally expected from a native-grade call experience.

**Independent Test**: During an active call, tap the speaker/audio-output button, choose a route from the picker, and confirm audio physically moves between earpiece, speakerphone, and (when paired) a Bluetooth device, with the button reflecting the current route.

**Acceptance Scenarios**:

1. **Given** an active call, **When** the user taps the speaker button, **Then** a route picker sheet opens listing all currently available output routes (Earpiece, Speakerphone, and any connected Bluetooth device) with the active route indicated.
2. **Given** the route picker is open, **When** the user selects Speakerphone, **Then** audio is routed to the speakerphone and the speaker button shows the speaker-on (speaker icon) state.
3. **Given** audio is on Speakerphone, **When** the user opens the picker and selects Earpiece, **Then** audio returns to the earpiece and the button shows the speaker-off state.
4. **Given** a Bluetooth audio device is connected, **When** the user selects the Bluetooth route from the picker, **Then** audio is routed to the Bluetooth device and the button reflects the Bluetooth route.
5. **Given** a Bluetooth device disconnects mid-call, **When** the connection drops, **Then** audio automatically falls back to a sensible default route (earpiece for voice, speaker for video) and the button and picker update accordingly.
6. **Given** the user has changed the audio route, **When** the route changes, **Then** the previously configured noise cancellation / audio enhancement behavior continues to function without degradation.

---

### User Story 4 - In-App Calls History Screen (Priority: P2)

As a user, I want a dedicated "Calls" tab where I can browse my recent call history, search it, and start a new call, so I have a familiar phone-style place to review and resume conversations.

**Why this priority**: Surfaces the call records produced by P1 in a usable, browsable screen and gives calling a first-class home in the app's navigation. Independently testable and valuable on its own once call records exist.

**Independent Test**: Open the app, tap the new "Calls" tab in the bottom navigation, and confirm the history list renders with correct avatars, names, call directions, timestamps, and call-type icons; missed calls are visually distinct; and search filters the list.

**Acceptance Scenarios**:

1. **Given** the app is open, **When** the user views the bottom navigation bar, **Then** a "Calls" tab is present alongside Chats, Updates, Map, and Profile.
2. **Given** the user opens the Calls tab, **When** the screen loads, **Then** a large "Calls" title and a rounded search bar are shown above a scrollable list under a "Recent" header.
3. **Given** the user has call history, **When** the list renders, **Then** each row shows a leading circular avatar (initials on a colored background), the contact name, a direction indicator (incoming / outgoing / missed arrow) with date/time (e.g., "Today 1:10 AM"), and a trailing call-type icon (video camera for video calls, phone handset for voice calls).
4. **Given** a call was missed, **When** its row renders, **Then** the contact name and direction indicator are styled in a distinct (e.g., red) treatment to mark it as missed.
5. **Given** the user types in the search bar, **When** the query changes, **Then** the list filters to call records whose contact matches the query.
6. **Given** the user wants to place a call, **When** they tap the new-call action on the Calls screen, **Then** they are taken to a contact/recipient selection flow to start a call.
7. **Given** the user taps a call history row, **When** the row is selected, **Then** the app initiates the appropriate action for that contact (e.g., redial / open the call or contact).

---

### Edge Cases

- **Concurrent native phone call (GSM/PSTN)**: When a regular cellular call is active and an app VoIP call arrives (or vice versa), the system call prioritization is honored and the app call is held or rejected gracefully without leaving a stuck call session.
- **App terminated / killed**: When the app is not running and a 1:1 call arrives, the incoming call still rings natively (via push wake-up) and answering launches the app into the active call.
- **Group calls**: Group calls do not use native CallKit presentation; they continue to use the existing in-app call screens and are still recorded in the in-app Calls history.
- **Permission denied**: When the user denies microphone, notification, or Bluetooth permissions, the app explains the limitation and degrades gracefully rather than presenting a broken call.
- **Missed-call accuracy**: A call answered on another of the user's devices is not also recorded as "missed" on this device.
- **Route unavailable**: When a previously selected route is no longer available (e.g., Bluetooth went out of range), the picker and button do not get stuck on an invalid route.
- **Stale call cleanup**: If a call ends abnormally (network loss, crash), the native call session is dismissed so the user is not left with a ghost ongoing-call indicator.
- **Duplicate call events**: A retried or duplicated incoming-call signal does not produce two stacked native call screens for the same call.
- **Empty history**: When the user has no call records, the Calls screen shows a clear empty state rather than a blank list.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-VoIP-01 (Native Call UI)**: System MUST present the native operating-system incoming and outgoing call interface for one-to-one (1:1) voice and video calls, including on the lock screen.
- **FR-VoIP-02 (Lock-Screen Answering)**: Users MUST be able to accept or decline an incoming 1:1 call from the native lock-screen call interface without first unlocking and manually opening the app.
- **FR-VoIP-03 (Background Audio Persistence)**: System MUST keep call audio active and bidirectional when the app is backgrounded, the screen is locked, or the user is in another app, for the full duration of the call.
- **FR-VoIP-04 (In-App Call History UI)**: System MUST provide a dedicated in-app "Calls" history screen, reachable from a new "Calls" tab in the bottom navigation bar (alongside Chats, Updates, Map, and Profile). The screen MUST include:
  - a large "Calls" title with a rounded search bar beneath it;
  - a "Recent" section header above a scrollable list of call history records;
  - list rows each showing a leading circular avatar (contact initials on a colored background), the contact name as the title, a subtitle combining a call-direction indicator (incoming / outgoing / missed arrow) with the date/time (e.g., "Today 1:10 AM"), and a trailing call-type icon (video camera for video calls, phone handset for voice calls);
  - a distinct visual treatment (e.g., red) for missed calls;
  - search that filters the list by contact;
  - an action to start a new call.
- **FR-VoIP-05 (Call History Recording)**: System MUST record every call (1:1 and group, voice and video) in the in-app call history with the correct contact identity, direction, outcome, type, and timestamp. 1:1 calls additionally appear in the iOS native Recents (CallKit-managed); the app does NOT write to the Android system call log (see Revision 2026-06-26).
- **FR-VoIP-06 (System Call Controls)**: System MUST allow ending an active 1:1 call and toggling mute from the native/system call controls and notification, with the in-app call state staying synchronized with those controls.
- **FR-VoIP-07 (Audio Routing Control)**: Users MUST be able to route active-call audio between Earpiece, Speakerphone, and connected Bluetooth devices. Tapping the speaker button MUST open a route picker sheet that lists all currently available output routes, indicates the active route, and applies the route the user selects.
- **FR-VoIP-08 (Speaker Button State & Icon)**: The active call screen MUST display a speaker button using a speaker icon that visually reflects the current audio output route (earpiece / speaker-on / Bluetooth) at all times.
- **FR-VoIP-09 (Route Change Resilience)**: System MUST automatically update the active route, the speaker button, and the route picker when an output device becomes available or unavailable mid-call (e.g., Bluetooth connect/disconnect), falling back to the type-appropriate default when the active route disappears.
- **FR-VoIP-10 (Default Audio Route)**: When a call connects, the system MUST default voice calls to the earpiece and video calls to the speakerphone, except that a connected Bluetooth device takes precedence over the default route when present.
- **FR-VoIP-11 (Noise-Cancellation Compatibility)**: Audio routing changes MUST integrate with the previously configured audio session and MUST NOT disable or degrade the existing noise cancellation / audio enhancement behavior.
- **FR-VoIP-12 (Wake from Terminated State)**: System MUST ring natively for incoming 1:1 calls even when the app has been terminated, and answering MUST launch the app into the active call.
- **FR-VoIP-13 (Clean Session Lifecycle)**: System MUST dismiss the native call session and release call resources when a call ends normally or abnormally, leaving no lingering ongoing-call indicator.
- **FR-VoIP-14 (Required Background/Foreground Capabilities)**: System MUST declare the platform capabilities required for active VoIP calls so that audio and call-session continuity are permitted by the operating system while the app is backgrounded.
- **FR-VoIP-15 (Missed/Rejected Accuracy)**: System MUST classify each call outcome (answered, declined, missed, ended) correctly in the call history, including when a call is handled on another of the user's devices.
- **FR-VoIP-16 (Group Call Scope)**: Group calls MUST continue to use the existing in-app call screens (no native CallKit presentation) while still being recorded in the in-app call history.

### Key Entities *(include if feature involves data)*

- **Call Session**: A single voice/video call instance. Key attributes: unique call identifier, direction (incoming/outgoing), call type (voice/video), participant scope (1:1/group), remote participant identity (name, avatar/initials), state (ringing, connecting, active, ended), start/connect/end timestamps, and outcome (answered, declined, missed).
- **Call History Entry**: The record surfaced in the in-app Calls history screen. Attributes: associated contact (name, avatar initials, avatar color), direction, outcome (incl. missed flag), call type (voice/video), timestamp, and duration.
- **Audio Route**: The current and available output destinations for call audio. Attributes: active route (earpiece, speakerphone, Bluetooth), list of available routes, and route-change events.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Incoming 1:1 calls present the native call interface on a locked device within 5 seconds of the call being initiated, in at least 95% of attempts on a normal network.
- **SC-002**: 100% of completed and missed calls appear in the in-app Calls history with the correct contact, direction, outcome, and call type.
- **SC-003**: Call audio continues without an audible interruption in 99% of cases when the app is backgrounded or the screen is locked during an active call.
- **SC-004**: Users can change the audio output route from the picker and hear the change take effect within 1 second of selection.
- **SC-005**: The speaker button reflects the actual active audio route correctly in 100% of route changes, including automatic Bluetooth connect/disconnect transitions.
- **SC-006**: Enabling speakerphone or switching routes does not measurably reduce noise-cancellation effectiveness compared to the pre-existing earpiece behavior.
- **SC-007**: Zero "ghost" ongoing-call indicators remain after a call ends (normal or abnormal termination) across a test suite of end scenarios.
- **SC-008**: 1:1 calls ring natively even when the app is terminated in at least 95% of attempts, and answering opens the active call.
- **SC-009**: The Calls history screen loads and renders the recent list within 1 second of tapping the Calls tab for a history of up to 500 records, with missed calls visually distinguishable at a glance.

## Assumptions

- The existing real-time calling backend, signaling, and media transport remain in place; this feature wraps native call presentation, audio routing, and an in-app history screen around the current call flow rather than replacing it.
- The audio enhancement / noise cancellation configuration delivered in feature 019 (call-audio-enhancement) is the audio session this feature must coexist with and must not break.
- Push-based wake-up (the platform's standard mechanism for waking an app for an incoming VoIP call) is available and provisioned for the app on both iOS and Android, used for 1:1 calls.
- Bluetooth, microphone, and notification permissions are requested through the standard platform flows; users who deny them receive a degraded-but-safe experience rather than a crash.
- Only one-to-one calls use native CallKit-style presentation; group calls remain on the existing in-app call screens.
- "Call History" is maintained inside the app for both platforms; 1:1 calls are also surfaced in iOS's native Recents via CallKit. The app does not read from or write to the Android system call log.
- The in-app Calls history derives its contact display (name, initials, avatar color) from existing contact/profile data already available in the app.
- Target platforms are iOS and Android as used by the current app; desktop/web are out of scope for native VoIP presentation in this iteration.
