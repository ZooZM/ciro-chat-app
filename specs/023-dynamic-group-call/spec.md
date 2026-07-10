# Feature Specification: Dynamic Group Call Screen

**Feature Branch**: `023-dynamic-group-call`  
**Created**: 2026-07-09  
**Status**: Draft  
**Input**: User description: "Dynamic Group Call Screen UI with adaptive layouts based on participant count, participant cells with avatar/video states, overlay badges, mock data only, easy_localization, and vibrant branding."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Active Group Call with 4–6 Participants (Priority: P1)

A user joins a group call with 4 to 6 participants and sees a 2-column grid of participant cells. Each cell displays either a live video placeholder or a centered avatar on a vibrant solid-color background. Small floating badges indicate mute status and active speaker status.

**Why this priority**: The 4–6 participant grid is the most common group-call scenario and the primary layout depicted in the reference screenshot.

**Independent Test**: Set `participantCount = 4` (then 5, then 6) using the mock state variable. Verify the 2-column grid renders correctly, all cells show the correct avatar-or-video state, and overlay badges appear in the expected positions.

**Acceptance Scenarios**:

1. **Given** `participantCount` is set to 4, **When** the group call screen renders, **Then** the UI displays a 2-column grid with 4 equal-sized participant cells, each occupying roughly half the screen width.
2. **Given** a participant's `isVideoOn` is false, **When** their cell renders, **Then** it shows a centered avatar image on a vibrant solid-color background (e.g., purple, blue, yellow, pink).
3. **Given** a participant's `isVideoOn` is true, **When** their cell renders, **Then** it shows a placeholder video container filling the entire cell.
4. **Given** a participant is muted, **When** their cell renders, **Then** a small "mute" icon badge appears as a floating overlay inside the cell.
5. **Given** a participant is the active speaker, **When** their cell renders, **Then** a small "audio waveform" badge appears as a floating overlay inside the cell.

---

### User Story 2 - View Active Call with 2 Participants (P2P) (Priority: P2)

When only 2 participants are present, the screen re-uses the standard 1-on-1 call layout: the remote user is shown full-screen, and the local user appears in a small, draggable floating picture-in-picture (PIP) window.

**Why this priority**: Provides seamless visual continuity between a P2P call and a group call; avoids showing a sparse grid when only two people are present.

**Independent Test**: Set `participantCount = 2`. Verify the full-screen remote view and the floating PIP for the local user both render correctly.

**Acceptance Scenarios**:

1. **Given** `participantCount` is set to 2, **When** the group call screen renders, **Then** the remote participant fills the entire screen, and the local participant appears in a small floating PIP overlay.
2. **Given** the P2P layout is active, **When** the user views the PIP, **Then** it has smooth rounded corners and is visually consistent with app branding.

---

### User Story 3 - View Active Call with 3 Participants (Priority: P2)

When exactly 3 participants are present, the screen uses a split layout: the top half shows one participant at full width, while the bottom half is split into two equal columns for the other two participants.

**Why this priority**: Provides an optimized, balanced layout specifically for the 3-participant case, avoiding awkward empty cells in a standard 2-column grid.

**Independent Test**: Set `participantCount = 3`. Verify the top-half / bottom-half split renders correctly.

**Acceptance Scenarios**:

1. **Given** `participantCount` is set to 3, **When** the group call screen renders, **Then** one participant occupies the top half of the screen at full width, and the other two participants split the bottom half into two equal columns.
2. **Given** the 3-participant layout is active, **Then** all three cells display their avatar-or-video state with overlay badges consistent with the grid layout.

---

### User Story 4 - Manually Test Different Layouts via State Variable (Priority: P3)

A developer or tester can manually change the `participantCount` state variable to switch between layouts (2, 3, 4, 5, 6) and verify each layout without needing any live calling infrastructure.

**Why this priority**: Enables rapid UI development and QA without backend dependencies.

**Independent Test**: Change `participantCount` from 2 to 6 in increments; verify layout transitions are correct and no overflow or rendering errors occur.

**Acceptance Scenarios**:

1. **Given** a developer changes `participantCount` from 4 to 2, **When** the widget rebuilds, **Then** the layout switches from a 2-column grid to the P2P full-screen + PIP layout.
2. **Given** a developer changes `participantCount` from 2 to 3, **When** the widget rebuilds, **Then** the layout switches to the split top-half / bottom-half layout.
3. **Given** a developer changes `participantCount` from 3 to 5, **When** the widget rebuilds, **Then** the layout switches to the 2-column grid with 5 cells.

---

### Edge Cases

- What happens when `participantCount` is 1 (only the local user)? → The screen should show a "waiting" state or a single full-screen view of the local user with a localized message such as "Waiting for others to join…".
- What happens when `participantCount` exceeds 6? → The 2-column grid scrolls vertically to accommodate additional participants, capped at a reasonable maximum (e.g., 9 visible + a "+N others" overflow tile).
- What happens if a participant's avatar image fails to load? → A fallback initial-letter avatar on the vibrant background color is shown.
- How do overlay badges behave when the cell is very small (e.g., 6 participants on a small device)? → Badges scale down proportionally but remain legible, with a minimum size threshold.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST render a dynamic layout that adapts based on the number of participants: P2P layout for 2, split layout for 3, and 2-column grid for 4–6+.
- **FR-002**: Each participant cell MUST support two visual states: a "Video Stream" state (showing a placeholder container) and an "Avatar Mode" state (showing a centered avatar on a vibrant solid-color background such as purple, blue, yellow, or pink).
- **FR-003**: Each participant cell MUST display floating overlay badges for mute status (mic-off icon) and active speaker status (audio waveform icon).
- **FR-004**: The entire UI MUST be built with mock data only — a dummy list of participants (e.g., `List<CallParticipant> mockParticipants`) with no WebRTC, Agora, or any live calling logic.
- **FR-005**: A simple state variable (e.g., `int participantCount`) MUST control the number of visible participants, allowing developers to manually change it to test different layouts.
- **FR-006**: All user-visible text strings MUST use `easy_localization` keys. Hardcoded strings are strictly forbidden.
- **FR-007**: The UI MUST maintain smooth rounded corners and vibrant, branded color schemes consistent with the app's existing design language.
- **FR-008**: When `participantCount` is 1, the system MUST show a waiting state with the local user displayed full-screen and a localized "waiting" message.
- **FR-009**: When `participantCount` exceeds 6, the 2-column grid MUST scroll vertically, with overflow participants represented by a "+N others" tile when exceeding the maximum visible count (9).
- **FR-010**: Each participant cell MUST display the participant's name as a localized text overlay at the bottom of the cell.

### Key Entities

- **CallParticipant**: Represents a single participant in the group call, including their display name, avatar image, background color, video-on status, mute status, and speaking status.
- **GroupCallState**: Represents the overall call state, including the list of participants and the selected participant count for layout testing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Changing `participantCount` from 2 to 6 renders the correct layout for each count without any layout overflow errors on standard mobile screen sizes.
- **SC-002**: 100% of visible text in the group call screen uses `easy_localization` keys — zero hardcoded strings.
- **SC-003**: Each participant cell correctly toggles between "Video Stream" and "Avatar Mode" based on the mock participant's `isVideoOn` property.
- **SC-004**: Overlay badges (mute icon, speaking waveform) render at the correct positions within participant cells and remain legible at all supported participant counts (2–6+).
- **SC-005**: The UI renders at 60fps with no visible jank during layout transitions when changing participant count.
- **SC-006**: All vibrant background colors (purple, blue, yellow, pink) are used across participant cells, matching the reference screenshot's aesthetic.

## Assumptions

- The group call screen is a standalone, self-contained screen that can be navigated to from the app's existing routing system.
- Participant data (names, avatars, colors, statuses) comes from a mock data source and does not require any network calls or real-time data streams.
- The existing app design system (colors, typography, border radii) is followed for branding consistency.
- The P2P layout (2 participants) re-uses or closely mirrors the existing 1-on-1 call screen layout already present in the codebase.
- Avatar images can be represented by placeholder containers or local asset images; no network image fetching is required for the mock version.
- The call control bar (mic, camera, end call, etc.) is out of scope for this specification — it will be handled by the existing call controls or a separate feature.
- The "+N others" overflow tile for >9 participants follows the same visual style as the existing group call implementation in the codebase.
