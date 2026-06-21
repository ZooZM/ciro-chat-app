# Feature Specification: Avatar-Based Video Call

**Feature Branch**: `[017-avatar-video-call]`  
**Created**: 2026-06-20  
**Status**: Draft  
**Input**: User description: "/speckit-specify I have attached two screenshots showing a new UI feature we need to build: an Avatar-Based Video Call interface."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Incoming Call (Priority: P1)

As a user receiving a call, I want to see an incoming call screen with the caller's avatar and name, so I can recognize who is calling and decide whether to answer.

**Why this priority**: Essential first step of any call flow.

**Independent Test**: Can be fully tested by triggering a mock "incoming call" state and verifying the UI layout and buttons are rendered visually.

**Acceptance Scenarios**:

1. **Given** the app receives a mock incoming call, **When** the incoming call screen is presented, **Then** it shows a modal or full-screen layout with a large caller mock avatar, caller name, "Join", and "Not Now" buttons.
2. **Given** the incoming call screen is active, **When** the user taps "Join", **Then** the UI triggers a mock acceptance callback (to transition to Active Call).
3. **Given** the incoming call screen is active, **When** the user taps "Not Now", **Then** the UI triggers a mock decline callback (to dismiss).

---

### User Story 2 - Active Call Interface (Priority: P1)

As a user in an active call, I want to see the remote user's avatar prominently and my own avatar in a smaller PIP, along with call controls, so I can manage the call experience.

**Why this priority**: Core interface for the active call phase.

**Independent Test**: Can be tested by loading the mock Active Call screen widget directly in a sandbox or test environment.

**Acceptance Scenarios**:

1. **Given** the user is in an active call, **When** viewing the screen, **Then** a large mock remote avatar is centered and a small local mock avatar PIP is floating on the screen.
2. **Given** the active call screen is visible, **When** viewing the bottom control bar, **Then** it contains buttons for Mute, Camera toggle, and End Call.
3. **Given** the active call screen is visible, **When** tapping the End Call button, **Then** a mock end call callback is triggered.

---

### Edge Cases

- What happens when the device screen size is very small (e.g., iPhone SE)? The layout must remain responsive, scaling avatars and spacing so that action buttons do not overflow off-screen.
- How does the UI handle long caller names? The caller name text should truncate gracefully with an ellipsis rather than breaking layout.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The UI MUST implement an "Incoming Call" screen (modal or full-screen) matching the structural layout provided in the reference.
- **FR-002**: The Incoming Call screen MUST display a large placeholder avatar in the center and the caller's name.
- **FR-003**: The Incoming Call screen MUST include "Join" and "Not Now" buttons using `easy_localization` keys for text.
- **FR-004**: The UI MUST implement an "Active Call" screen matching the structural layout provided in the reference.
- **FR-005**: The Active Call screen MUST display a large placeholder remote avatar and a small floating PIP placeholder local avatar.
- **FR-006**: The Active Call screen MUST include a bottom control bar with icons for: Mute, Camera toggle, and End Call.
- **FR-007**: All displayed text MUST use `easy_localization` keys. No hardcoded text is permitted.
- **FR-008**: The UI MUST be strictly presentation-only (dumb widgets) using mock data, with no real WebRTC or backend logic wired up.
- **FR-009**: The colors and shapes MUST adapt to the app's existing theme while preserving the identical layout structure from the screenshots.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Both screens can be rendered independently in a widget catalog or test wrapper without crashing.
- **SC-002**: 100% of user-facing text strings use `easy_localization` keys.
- **SC-003**: 0% backend or WebRTC state logic is present in the UI widget files.
- **SC-004**: Visual layout structure matches the reference screenshots identically (verified by visual comparison).

## Assumptions

- The project has `easy_localization` already configured and functioning.
- The project has a defined app theme (colors, typography, shapes) that will be applied to these screens instead of the exact snapshot colors.
- Mock data (e.g., simple colored containers or static placeholder images) is sufficient for avatars at this stage; no avatar animations are needed.
