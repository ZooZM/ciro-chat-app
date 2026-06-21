# Feature Specification: Snap Map Real-Time Logic

**Feature Branch**: `018-snap-map-realtime`
**Created**: 2026-06-21
**Status**: Draft
**Input**: User description: "Implement the underlying business logic, state management, and real-time data flow for an Interactive 'Snap Map' feature within our chat application. The mobile UI is already fully implemented. The goal now is to build the functional architecture that connects the client state to the backend to display and filter user avatars on the map."

## Overview

The Snap Map screen currently renders a full-screen map with floating user avatars driven entirely by hardcoded mock data (`map_mock_data.dart`). The filter sheet, "Share My Location", "Locate Me", and group selection controls are present visually but are not connected to any live data. This feature replaces the mock layer with a real, privacy-aware, real-time data pipeline so the map reflects actual contacts, their live presence (Online/Offline), and their real locations, with user-controlled filtering and a Ghost Mode for hiding one's own location.

The mobile UI (widgets, layout, sheets, FABs) is out of scope and must not be redesigned. This feature delivers the data models, state management, privacy rules, and the real-time event flow that feed those existing widgets.

## Clarifications

### Session 2026-06-21

- Q: What should the "Explore" tab (Following/Explore toggle) show? → A: Public statuses, not live people — Explore surfaces users who posted a map-visible status (the existing `SHOW_ON_MAP` status flag), never the live location of non-contacts. "Following" shows live contacts. No private location is ever exposed to non-contacts.
- Q: Who is automatically authorized to see a user's live map location? → A: Mutual contacts + members of shared groups (minus blocked users); no separate opt-in audience or per-group toggle is introduced. Visibility is still globally gated by the user's Share Location / Ghost Mode state.
- Q: How should live location/visibility updates reach observers in near-real-time? → A: Push over the existing real-time channel (the same gateway that already broadcasts chat presence); not periodic polling.
- Q: What is the scope of Ghost Mode? → A: Global — a single setting that hides the user from all observers and halts all broadcasting; no per-contact/per-group selective hiding.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See My Contacts on the Map in Real Time (Priority: P1)

As a user, when I open the Map screen, I want to see avatars for the people I'm connected with placed at their real locations, with a clear visual distinction between who is currently online and who is offline, so the map reflects reality instead of placeholder data.

**Why this priority**: This is the core value of the feature — replacing mock markers with live, authentic data. Without it, nothing else (filtering, privacy, clustering) has anything real to operate on.

**Independent Test**: Sign in as a user who has at least one connected contact that has shared a location. Open the Map screen and confirm a marker appears at that contact's real coordinates with an online/offline border color that matches the contact's actual presence. Change the contact's presence (connect/disconnect them) and confirm the marker's status updates live without leaving the screen.

**Acceptance Scenarios**:

1. **Given** I have connected contacts who have shared their location and are not in Ghost Mode, **When** I open the Map screen, **Then** a marker is rendered for each visible contact at their last-known coordinates.
2. **Given** the map is showing a contact's marker, **When** that contact comes online, **Then** the marker's status indicator updates to "online" within a few seconds without a manual refresh.
3. **Given** the map is showing an online contact, **When** that contact goes offline, **Then** the marker updates to the "offline" appearance within a few seconds.
4. **Given** a contact has never shared a location or has location hidden, **When** I open the Map, **Then** no marker is shown for that contact.
5. **Given** the map data fails to load (network error), **When** I open the Map, **Then** I see an error/empty state and can retry, rather than a blank or stuck screen.

---

### User Story 2 - Filter Who Appears on the Map (Priority: P1)

As a user, I want to filter the map by presence status (All / Online Only / Offline Only) and by group/circle (All members or a specific chat group like "Tech Team"), so I can focus on a relevant subset of people. Filters must update the visible markers immediately.

**Why this priority**: The UI already exposes these filter controls; they are central to the product concept ("Advanced Filtering Engine"). Filtering is what makes a crowded map usable.

**Independent Test**: With several markers visible (mix of online/offline, across multiple groups), open the filter sheet, select "Online Only", and confirm only online contacts remain. Switch to a specific group and confirm only members of that group remain. Combine both and confirm the intersection is shown.

**Acceptance Scenarios**:

1. **Given** markers for both online and offline contacts are visible, **When** I select "Online Only", **Then** only online contacts' markers remain visible.
2. **Given** "Online Only" is active, **When** I select "Offline Only", **Then** only offline contacts' markers remain visible.
3. **Given** a status filter is active, **When** I select "All Users", **Then** all permitted contacts are shown regardless of presence.
4. **Given** I belong to multiple groups, **When** I select a specific group in the filter sheet, **Then** only contacts who are members of that group are shown.
5. **Given** a group filter and a status filter are both active, **When** the map updates, **Then** only contacts satisfying BOTH conditions are shown (logical AND).
6. **Given** filters are applied, **When** a contact's presence changes live, **Then** they appear or disappear from the map consistently with the active filters.
7. **Given** I have applied filters, **When** I close and reopen the filter sheet, **Then** my current selections are reflected as the active state.

---

### User Story 3 - Control My Own Location & Privacy (Ghost Mode) (Priority: P1)

As a user, I want to explicitly share my live location to the map and to be able to turn on Ghost Mode to hide my location entirely, so I am always in control of who can see where I am. My location must only ever be visible to people I am authorized to share with (connected contacts / shared groups), never to strangers.

**Why this priority**: Location is sensitive personal data. Privacy controls are not optional polish — they are a prerequisite for ethically and legally shipping the feature, and they gate what data the rest of the system is even allowed to broadcast.

**Independent Test**: As user A, enable location sharing and confirm user B (a connected contact) can see A on their map. Enable Ghost Mode as A and confirm A's marker disappears from B's map within a few seconds and that A no longer broadcasts coordinates. Confirm a non-contact C never sees A regardless of Ghost Mode state.

**Acceptance Scenarios**:

1. **Given** I have granted device location permission, **When** I tap "Share My Location", **Then** my current coordinates are sent to the backend and I become visible to authorized contacts.
2. **Given** I am sharing my location, **When** I move, **Then** my updated location is broadcast to authorized contacts within a reasonable interval.
3. **Given** I am sharing my location, **When** I enable Ghost Mode, **Then** I immediately stop broadcasting location and my marker is removed from every authorized contact's map within a few seconds.
4. **Given** Ghost Mode is enabled, **When** I reopen the app later, **Then** Ghost Mode remains enabled (the setting persists) and I am still hidden until I explicitly disable it.
5. **Given** I have not granted device location permission, **When** I tap "Share My Location", **Then** I am prompted to grant permission and no location is sent until permission is granted.
6. **Given** a user is NOT a connected contact and shares no group with me, **When** they query the map, **Then** my location is never returned to them, regardless of distance or my sharing settings.
7. **Given** I tap "Locate Me", **When** the map has my coordinates, **Then** the camera centers on my current position.

---

### User Story 4 - Distance-Based Discovery (Nearby Only) (Priority: P2)

As a user, I want to limit the map to people near me ("Nearby Only") versus everyone ("All Locations"), so I can discover who is physically close without scrolling a global map.

**Why this priority**: Distance filtering builds directly on the geospatial query the backend already supports (`getNearbyUsers` with a radius). It enhances discovery but the map is still useful without it, so it ranks below core sync, filtering, and privacy.

**Independent Test**: With contacts at varying distances, select "Nearby Only" and confirm only contacts within the defined nearby radius are shown; select "All Locations" and confirm distant contacts reappear.

**Acceptance Scenarios**:

1. **Given** contacts exist both within and beyond the nearby radius, **When** I select "Nearby Only", **Then** only contacts within the radius of my current location are shown.
2. **Given** "Nearby Only" is active, **When** I select "All Locations", **Then** contacts at any distance (subject to other filters and privacy) are shown.
3. **Given** "Nearby Only" is selected, **When** my own location is unknown (not shared / no permission), **Then** I am informed that a distance filter requires my location and the filter is disabled or clearly inert.
4. **Given** "Nearby Only" is active, **When** combined with status and group filters, **Then** results satisfy all active filters together.

---

### User Story 5 - Smooth, Non-Laggy Map Rendering (Priority: P2)

As a user, when many contacts are on the map, I want nearby avatars to be clustered into a single badge and avatar images to load without freezing the map, so the experience stays smooth even in dense areas.

**Why this priority**: Performance and clustering protect the experience at scale. The feature works for small contact lists without it, so it is important but not a blocker for an initial usable release.

**Independent Test**: Load the map with a large set of markers concentrated in a small area; confirm they collapse into cluster badges showing a count, that zooming in splits clusters into individual avatars, and that scrolling/zooming remains responsive while avatar images resolve.

**Acceptance Scenarios**:

1. **Given** multiple markers are close together at the current zoom level, **When** the map renders, **Then** they are grouped into a single cluster badge showing the number of users.
2. **Given** a cluster badge is visible, **When** I zoom in past the cluster's threshold, **Then** the cluster expands into individual avatar markers.
3. **Given** avatars reference remote images, **When** markers are built into map icons, **Then** the map remains interactive (no perceptible freeze) while images load, and a placeholder/initial is shown until the image is ready.
4. **Given** an avatar image fails to load, **When** the marker is built, **Then** a fallback (initial on colored background) is used instead of a broken marker.

---

### Edge Cases

- **Stale location**: A contact shared a location days ago and hasn't updated it. The system should still show the last-known position but should treat very old locations per the staleness rule (see Assumptions) — e.g., not counted as "Nearby" if beyond a freshness window, or visually de-emphasized.
- **Presence flapping**: A contact rapidly connects/disconnects. Status updates should debounce so markers don't flicker.
- **Self marker**: The current user's own marker ("You") must always be derived from the device, must respect Ghost Mode for what is broadcast to others, but may still be shown to the user themselves locally.
- **Blocked users**: A blocked user must never appear on my map, and I must never appear on theirs, even if otherwise connected or nearby.
- **Permission revoked mid-session**: Device location permission is revoked while sharing is on; the app must stop sending updates and reflect that sharing is no longer active.
- **Group membership change**: A contact is removed from a group while a group filter is active; their marker should drop out on the next update.
- **Empty results**: All filters combined yield zero contacts; the map shows a clear empty state rather than appearing broken.
- **Backgrounding**: When the app is backgrounded, location broadcasting should pause or throttle per platform constraints and resume on return.
- **No location of own for distance filter**: Distance filter requires the user's own coordinates; handle gracefully when unavailable.

## Requirements *(mandatory)*

### Functional Requirements

**Real-Time Presence Sync**

- **FR-001**: The map MUST display a marker for each contact the current user is authorized to see who has a shareable, non-hidden location.
- **FR-001a**: The "Following" tab MUST show live contacts (authorized contacts with shared, non-hidden locations). The "Explore" tab MUST show only users who have posted a map-visible status (the existing map-visible status flag) and MUST NOT expose the live location of non-contacts. No private location is ever disclosed to non-contacts via either tab.
- **FR-001b**: For the "Explore" tab, the system MUST return only a **coarse location** for non-contacts (e.g., truncated/reduced-precision coordinates, or the status's own location) — never precise live coordinates. Precise, live-tracking coordinates MUST be reserved for authorized mutual contacts / shared-group members ("Following"). Coarsening MUST be applied server-side before the data leaves the backend.
- **FR-002**: Each marker MUST reflect the contact's live presence state (online/offline), sourced from the same presence system used by the chat experience.
- **FR-003**: When a contact's presence changes, the map MUST update that contact's marker status in near-real-time (target within a few seconds) without requiring the user to refresh or leave the screen.
- **FR-003a**: Live presence, location, and visibility updates MUST be delivered to authorized observers by push over the existing real-time channel (the same channel that already broadcasts chat presence), not by client-side periodic polling.
- **FR-003b**: Every location record delivered to a client (initial load and live updates) MUST carry a `lastUpdatedAt` timestamp indicating when that location was last refreshed.
- **FR-003c**: Marker Time-To-Live (TTL): the client MUST treat a marker as stale and visually fade it out (and remove it) when it has received no location update for that user within a defined TTL window. A background cleanup process MUST run periodically so stale ("ghost") markers from disconnected/closed-app users do not persist indefinitely on the map.
- **FR-004**: Presence updates MUST be debounced/coalesced so that rapid connect/disconnect cycles do not cause visible marker flicker.

**Location Tracking & Broadcasting**

- **FR-005**: The user MUST be able to start sharing their live location from the map (the existing "Share My Location" control).
- **FR-006**: When sharing is active, the user's location updates MUST be broadcast to authorized recipients at a reasonable cadence (interval and/or significant-movement threshold) rather than continuously.
- **FR-006a**: The system MUST protect the real-time channel against a "thundering herd" in large shared groups: incoming location updates MUST be collected and emitted to recipients in **server-side batches** on a fixed interval (e.g., every ~5 seconds), rather than fanning out every individual update instantly. Batching MUST coalesce multiple updates for the same user within an interval to the latest value.
- **FR-007**: The system MUST request and respect device location permission; no coordinates may be captured or sent without permission.
- **FR-008**: The "Locate Me" control MUST center the map on the user's current location when available.
- **FR-009**: The user's own location MUST persist as a last-known value so the map can display it across sessions until changed.

**Privacy & Authorization**

- **FR-010**: A user's location MUST only be disclosed to authorized recipients — defined as connected contacts and/or members of groups shared with that user — and MUST NEVER be disclosed to unauthorized users regardless of distance.
- **FR-011**: The system MUST provide a Ghost Mode as a single global setting that, when enabled, hides the user's location from ALL recipients and stops location broadcasting entirely. Selective (per-contact / per-group) hiding is explicitly out of scope.
- **FR-012**: Enabling Ghost Mode MUST remove the user's marker from all authorized recipients' maps in near-real-time.
- **FR-013**: The Ghost Mode setting MUST persist across app restarts until the user explicitly changes it.
- **FR-014**: Blocked users MUST be mutually excluded from each other's map at all times, overriding all other visibility rules.
- **FR-015**: Authorization MUST be enforced on the backend (server-side), not solely by client-side filtering, so that location data is never delivered to an unauthorized client.

**Filtering Engine**

- **FR-016**: The user MUST be able to filter markers by presence status: All Users, Online Only, or Offline Only.
- **FR-017**: The user MUST be able to filter markers by group/circle: All members, or a single specific group.
- **FR-018**: The user MUST be able to filter markers by distance: Nearby Only (within a defined radius of the user's location) or All Locations.
- **FR-019**: When multiple filters are active, the map MUST show only contacts satisfying ALL active filters simultaneously (logical AND).
- **FR-020**: Applying or changing a filter MUST update the visible markers immediately (perceived as instant) without a full screen reload.
- **FR-021**: Active filter selections MUST be retained for the duration of the session and reflected when the filter sheet is reopened.
- **FR-022**: Live presence/location updates MUST be re-evaluated against the active filters so markers appear/disappear consistently as data changes.
- **FR-022a**: Marker state updates MUST be idempotent and timestamp-ordered: an incoming location (whether from the initial load response or a live push) MUST overwrite an existing marker ONLY IF its `lastUpdatedAt` is strictly newer than the cached marker's. This prevents a late-resolving initial fetch from overwriting fresher real-time data (and vice versa).
- **FR-023**: The group filter MUST allow searching/selecting from the user's actual groups (replacing the current mock group list).

**Map Optimization**

- **FR-024**: Markers that are visually close at the current zoom level MUST be grouped into a single cluster badge displaying the count of contained users.
- **FR-025**: Zooming in past a cluster's threshold MUST expand the cluster into individual avatar markers; zooming out MUST re-cluster them.
- **FR-026**: Converting remote avatar images into map marker icons MUST be performed without blocking or freezing the map UI, including when 50+ avatars must be converted concurrently. Image decoding/cropping and icon rasterization MUST NOT run on the main UI thread.
- **FR-027**: Until an avatar image is available, a placeholder (initial on the contact's colored background) MUST be shown; if the image fails, the placeholder MUST remain as the fallback.
- **FR-028**: Generated marker icons SHOULD be cached/reused so the same avatar is not rebuilt repeatedly during normal panning/zooming.

**State, Errors & Lifecycle**

- **FR-029**: The map screen MUST present distinct states for loading, populated, empty (no contacts after filters/privacy), and error (with retry).
- **FR-030**: Tapping a marker MUST surface that contact's detail (feeding the existing user detail sheet) using real contact data.
- **FR-031**: Location broadcasting MUST pause or throttle when the app is backgrounded and resume appropriately when foregrounded.
- **FR-032**: If device location permission is revoked while sharing is active, the system MUST stop broadcasting and reflect that sharing is inactive.

### Key Entities *(include if feature involves data)*

- **Map User / Contact**: A person the current user may see on the map. Key attributes: identity (id, display name), avatar reference (URL or initial + color), presence state (online/offline), last-known location (coordinates + freshness timestamp), location-visibility state (sharing / hidden via Ghost Mode), group memberships, and relationship to the current user (connected, shared groups, blocked). Replaces the current `MockUser`/`MockMapMarker`.
- **Current User Location State**: The current user's own location and broadcasting status. Attributes: current/last-known coordinates, sharing-enabled flag, Ghost Mode flag (persisted), device permission status, and last-broadcast timestamp.
- **Map Filter State**: The active filter selection. Attributes: status filter (All/Online/Offline), group filter (All or a specific group id), distance filter (Nearby/All) and the nearby radius. Drives which markers are shown and which backend query is issued.
- **Group / Circle**: A chat group the user belongs to, used for the group filter. Attributes: id, name, member set, avatar/initials. Sourced from existing group/chat-room data; replaces the mock group list.
- **Map Marker / Cluster**: A rendered representation on the map — either a single contact avatar or a cluster badge aggregating multiple contacts with a count, derived from the visible contacts after filtering at the current zoom/viewport.
- **Presence Event**: A real-time signal that a user's online state changed (carrying user id + new state), consumed to update markers live.
- **Location Update Event**: A real-time signal that an authorized user's coordinates (or visibility) changed, consumed to move/add/remove markers live.

### Real-Time Event Flow *(reference for planning)*

This describes the expected client↔backend interaction at a behavioral level (not an implementation contract):

1. **Initial load**: Client opens Map → requests the set of visible contacts with their locations and presence, scoped server-side to authorization rules and the active distance filter.
2. **Subscribe**: Client subscribes to live updates for map-relevant events (presence changes and authorized location/visibility changes).
3. **Presence change**: A contact connects/disconnects → backend emits a presence event to authorized observers → client updates the corresponding marker's status, re-applying active filters.
4. **Location/visibility change**: A contact moves or toggles Ghost Mode → backend emits a location/visibility event only to authorized observers → client moves, adds, or removes that marker.
5. **Self broadcast**: User shares location/moves → client sends location updates at a throttled cadence → backend persists last-known location and fans out to authorized observers; if Ghost Mode is on, no fan-out occurs and the marker removal is propagated.
6. **Filter change**: Client applies a filter → handled client-side for status/group when data is already present; distance changes may trigger a new scoped backend query.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of markers shown on a user's map correspond to contacts that user is authorized to see; unauthorized users' locations are returned in 0% of cases (verified by authorization tests).
- **SC-002**: A contact's presence change is reflected on an observer's map within 5 seconds in 95% of cases.
- **SC-003**: Enabling Ghost Mode removes the user's marker from authorized observers' maps within 5 seconds in 95% of cases, and the setting persists across 100% of app restarts.
- **SC-004**: Applying any filter updates the visible markers in under 300 ms (perceived as instant) for a typical contact list.
- **SC-005**: With at least 100 markers concentrated in the viewport, the map maintains smooth interaction (no perceptible freeze) while clustering and resolving avatar images.
- **SC-006**: Distance filtering ("Nearby Only") returns only contacts within the configured radius in 100% of test cases where the user's own location is known.
- **SC-007**: Combined filters (status + group + distance) yield exactly the intersection of matching contacts in 100% of test cases.
- **SC-008**: Blocked users never appear on each other's maps in 100% of test cases.
- **SC-009**: Stale ("ghost") markers — users who lost connection or closed the app — are faded/removed within one TTL-cleanup cycle in 100% of cases; no marker persists beyond the TTL window without a fresh update.
- **SC-010**: With 50+ avatar markers converting concurrently, the map sustains smooth interaction (no dropped-frame jank perceptible to the user) because image/icon work runs off the main thread.
- **SC-011**: A late-arriving stale update never overwrites fresher marker data: in 100% of out-of-order delivery tests, the marker reflects the value with the newest `lastUpdatedAt`.
- **SC-012**: In a shared group of N members all moving, the real-time channel emits at most one batched location frame per recipient per batch interval (not N× per movement), keeping gateway emission volume bounded as group size grows.

## Assumptions

- **Reuse of existing presence system**: The chat presence mechanism (online/offline broadcast already emitted on connect/disconnect) is the authoritative source for marker status; this feature consumes it rather than building a new presence system.
- **Reuse of existing geospatial backend**: The existing location storage (GeoJSON point with geospatial index) and the existing nearby-query endpoint are the foundation for distance filtering; this feature extends them with authorization and privacy/Ghost-Mode handling rather than replacing them.
- **"Groups/Circles" map to existing chat groups**: A "group" or "circle" for filtering is an existing group chat the user belongs to; no separate circle entity is introduced. The mock group list in the filter sheet is replaced by the user's real groups.
- **"Authorized recipients" definition**: Authorized recipients are connected contacts (mutual contacts) and/or members of groups the user shares, minus any blocked users. This matches the existing contact/blocking model. No separate "map audience" entity or opt-in list is introduced; visibility to this set is gated globally by the user's Share Location / Ghost Mode state.
- **Ghost Mode default**: Ghost Mode is OFF by default; users opt into hiding. Location sharing itself is also opt-in via the "Share My Location" control.
- **Location update cadence**: Live location is broadcast on a throttled basis (e.g., on significant movement and/or a periodic interval) rather than as a continuous high-frequency stream, to balance freshness with battery and bandwidth. Exact interval to be set during planning.
- **Staleness window**: Locations older than a defined freshness window are still displayable as last-known but are excluded from "Nearby Only" results; exact window to be confirmed in planning.
- **UI is fixed**: The existing Snap Map UI (screens, widgets, sheets, FABs, marker visuals) is the contract; this feature wires data into it and must not alter the visual design.
- **Status filter & group filter are currently local-only**: The filter sheet's selections are presently held in local widget state and not propagated to the map; this feature lifts that selection into shared state that drives the visible markers.
