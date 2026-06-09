# Feature Specification: Map UI

**Feature Branch**: `[013-map-ui]`  
**Created**: 2026-06-09
**Status**: Draft  
**Input**: User description: "/speckit-specify Act as a Senior Flutter Developer. Analyze the attached images and generate a comprehensive UI-ONLY specification document for our Flutter application..."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Main Map Navigation (Priority: P1)

Users should be able to view a full-screen map with floating avatars indicating other users' locations.

**Why this priority**: The map interface is the core visual component that users interact with first to see their friends and surroundings.

**Independent Test**: Can be fully tested by launching the app to the map view, observing the layout of floating avatars with status colors, the right-side floating action buttons (where the first button toggles between Satellite and Normal map modes), and the top search/tab bar using dummy map markers and profiles on a Google Map.

**Acceptance Scenarios**:

1. **Given** the app is launched to the Map tab, **When** the screen renders, **Then** a full-screen map background should be visible.
2. **Given** the map is visible, **When** checking map markers, **Then** floating user avatars with colored borders indicating status should be placed on the map.
3. **Given** the map is visible, **When** checking the top bar, **Then** a search icon, "Following/Explore" pill-shaped toggle, and add/profile icons should be present.
4. **Given** the map is visible, **When** checking the right side, **Then** floating action buttons (Map Type Toggle, Settings/Filter, Locate Me, Share My Location) should be vertically stacked. The Map Type Toggle must switch the Google Map between Normal and Satellite modes.

---

### User Story 2 - Bottom Navigation Interaction (Priority: P1)

Users should be able to navigate between the main app sections using a custom bottom navigation bar.

**Why this priority**: Navigation is essential for moving between Chats, Updates, Map, Calls, and Profile.

**Independent Test**: Can be fully tested by tapping the Map tab icon from the existing app navigation bar and verifying the Map screen loads properly.

**Acceptance Scenarios**:

1. **Given** the app is open, **When** the existing bottom navigation bar is used, **Then** tapping the Map tab navigates to the MapScreen.
2. **Given** the map tab is active, **When** switching tabs, **Then** the existing navbar handles state correctly without needing a newly built navbar.

---

### User Story 3 - View User Details Bottom Sheet (Priority: P2)

Users should be able to tap a map marker to reveal a bottom sheet with detailed information about that user.

**Why this priority**: This interaction allows users to quickly view details and take actions like messaging or calling without leaving the map context.

**Independent Test**: Can be tested by triggering the bottom sheet programmatically or via a mock map marker tap, observing the user avatar, name, online status, location, and action buttons.

**Acceptance Scenarios**:

1. **Given** the map view, **When** a user avatar marker is tapped, **Then** a modal bottom sheet should slide up.
2. **Given** the bottom sheet is open, **When** reviewing its contents, **Then** it should display a large user avatar, name, "online" text (colored green), and general location (e.g., "Near Zamalek, Cairo").
3. **Given** the bottom sheet is open, **When** reviewing the action buttons, **Then** there should be a "Messaging" button and a "Call" button styled appropriately.

---

### User Story 4 - View Status/Reels Screen (Priority: P2)

Users should be able to view full-screen, immersive media content (Status/Reels) with interactive overlays.

**Why this priority**: Status and reels consumption is a major engagement feature.

**Independent Test**: Can be tested by launching the Status Viewer screen with mock media (images), observing the top tabs, right-side action column, and bottom text overlay.

**Acceptance Scenarios**:

1. **Given** the user navigates to a status/reel, **When** the screen renders, **Then** it should display a full-screen image or video background.
2. **Given** the status screen is visible, **When** looking at the top, **Then** a back arrow, search icon, "Following/Explore" toggle, and add/profile icons should overlay the content.
3. **Given** the status screen is visible, **When** looking at the right side, **Then** a vertical column of interactive icons (Like, Comment, Share, Refresh, Voice) should be visible over a darkened gradient or background pill.
4. **Given** the status screen is visible, **When** looking at the bottom, **Then** user name, time ago, and a caption should overlay the media.

---

### User Story 5 - Map Filter Modal/Sheet (Priority: P3)

Users should be able to apply complex filters to the map view using a dedicated filter menu.

**Why this priority**: Filtering helps users manage a cluttered map, but is secondary to the core map viewing experience.

**Independent Test**: Can be tested by opening the filter sheet and observing the search bar, Status radio buttons, Groups selection, and Distance sliders/filters.

**Acceptance Scenarios**:

1. **Given** the map view, **When** the filter settings button is tapped, **Then** a Filter modal/sheet should appear.
2. **Given** the filter sheet is open, **When** reviewing its layout, **Then** it must contain a search bar.
3. **Given** the filter sheet is open, **When** reviewing filter options, **Then** it must contain Status radio buttons, Groups selection, and Distance filter controls.

---

### Edge Cases

- What happens when a user's name is exceptionally long in the map marker or bottom sheet? (UI should truncate with ellipsis).
- How does the UI handle the Status/Reels viewer on devices with extreme aspect ratios or notches? (SafeArea should be used appropriately for top/bottom overlays).
- What happens when the map fails to load tiles? (UI should show a default grid or fallback color).
- How are overlapping avatars handled on the map? (Mock implementation can just render them in a specific order).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The UI MUST use `easy_localization` (`.tr()`) for all visible text strings. No hardcoded strings are allowed.
- **FR-002**: The UI MUST utilize purely mock data for all lists, map markers, user profiles, and media content. No backend integration.
- **FR-003**: The Map Screen MUST implement a full-screen `GoogleMap` background layout containing custom floating widgets for avatars, a top navigation bar, and right-aligned floating action buttons (including a Map Type toggle).
- **FR-004**: The feature MUST reuse the existing bottom navigation bar implementation in the app rather than creating a new one.
- **FR-005**: The User Details Bottom Sheet MUST be structured to display an avatar, name, online status, location text, and action buttons.
- **FR-006**: The Filter Modal/Sheet MUST include UI components for a search bar, status radio selections, group selections, and distance filters.
- **FR-007**: The Status/Reels Viewer Screen MUST display a full-screen media background with overlaid UI elements including top navigation tabs, a right-side action column, and a bottom caption area.

### Key Entities

- **MockUser**: Represents dummy data for a user (avatar URL, name, online status, location).
- **MockMapMarker**: Represents dummy data for a map marker (latitude, longitude, associated MockUser, status color).
- **MockStatus**: Represents dummy data for a status/reel (media URL, author MockUser, timestamp, caption, metrics like likes/comments).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the specified screens (Map, Bottom Nav, User Details Sheet, Filter Sheet, Status Viewer) are visually implemented and runnable using mock data.
- **SC-002**: 100% of visible text elements utilize `.tr()` translation keys.
- **SC-003**: 0% of the UI implementation contains backend API calls or complex real state management (everything is localized to the UI layer).
- **SC-004**: The UI perfectly matches the layout and composition described in the user stories and attached mockups (based on visual inspection).

## Assumptions

- The app uses a standard Flutter material/cupertino design system mixed with custom widgets.
- Mock images can be sourced from network URLs (e.g., placeholder image services) or local assets if provided.
- The map background will use the `google_maps_flutter` package. No actual API key billing is strictly required for development, but the package must be integrated.
- The provided mockups dictate the exact styling (colors, border radii, typography) which will be approximated using Flutter's `Theme` and `TextStyle`.
