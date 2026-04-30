# Feature Specification: Status Updates Screen

**Feature Branch**: `004-status-updates`  
**Created**: April 28, 2026  
**Status**: Draft  

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Recent Statuses (Priority: P1)

Users should be able to view a list of recent, unread statuses from their contacts on the "Updates" screen, which auto-syncs in real time via Socket.io.

**Why this priority**: Viewing new statuses is the primary function of this screen.

**Independent Test**: Can be tested by opening the Updates tab and verifying the list of "Recent status" populates from the local SQLite cache and updates when a new socket event is received.

**Acceptance Scenarios**:

1. **Given** the user is on the Updates tab, **When** they have unviewed statuses from contacts, **Then** those statuses appear under the "Recent status" header.
2. **Given** a new status is posted by a contact, **When** the network is connected, **Then** the socket stream receives the update and the "Recent status" list updates in real-time.

---

### User Story 2 - View Presented/Viewed Statuses (Priority: P1)

Users should be able to see a separate list of statuses they have already viewed, loaded directly from the local SQLite history table.

**Why this priority**: Differentiates between new content and already consumed content.

**Independent Test**: View a status, return to the list, and verify the status moves from "Recent status" to "Status that were presented".

**Acceptance Scenarios**:

1. **Given** the user views a status, **When** they return to the Updates screen, **Then** the status is moved to the "Status that were presented" section.
2. **Given** the app launches offline, **When** the user navigates to Updates, **Then** the viewed statuses are loaded from the local SQLite database instantly.

---

### User Story 3 - Add New Status (Priority: P2)

Users must be able to add a new status using the persistent "Add Status" tile at the top or via the Pencil and Camera Floating Action Buttons.

**Why this priority**: Content creation is essential for engagement.

**Independent Test**: Tap the Camera FAB, capture an image, send it, and verify the "Add Status" section reflects the new user status.

**Acceptance Scenarios**:

1. **Given** the user taps the Camera FAB or "Add Status" tile, **When** they capture and post a status, **Then** it is uploaded, saved locally, and their profile tile shows the active status ring.
2. **Given** the user taps the Pencil FAB, **When** they type and post a text status, **Then** it is uploaded and saved.

---

### User Story 4 - Search Statuses (Priority: P2)

Users must be able to search for specific statuses by author name across both the "Recent" and "Presented" sections.

**Why this priority**: Helps users find specific contacts' updates quickly.

**Independent Test**: Type a contact's name in the search bar and verify only their statuses are shown.

**Acceptance Scenarios**:

1. **Given** the search bar on the Updates screen, **When** the user types "Amr", **Then** the list filters to show only statuses authored by "Amr Mohamed" across all sections.

---

### User Story 5 - Automatic Expiry (Priority: P1)

Statuses must automatically disappear 24 hours after creation.

**Why this priority**: Ephemerality is a core feature of status updates.

**Independent Test**: Change the device time to >24 hours after a status was created, open the app, and verify it is purged from SQLite and the UI.

**Acceptance Scenarios**:

1. **Given** a status that is exactly 24 hours old, **When** the app checks expiry logic, **Then** the status is deleted from SQLite and Hive and removed from the UI.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST strictly adhere to Clean Architecture with Domain (`StatusEntity`, `StatusRepository`), Data (`StatusModel`, `StatusRepositoryImpl`, `StatusLocalDataSource`, `StatusRemoteDataSource`), and Presentation (`StatusCubit`, UI) layers.
- **FR-002**: System MUST use `flutter_bloc` (`Cubit`) for managing the state of 'Recent Status', 'Viewed Status', and 'User Status'.
- **FR-003**: System MUST load statuses from SQLite locally first (offline-first approach) and sync with Socket.io when the network is available.
- **FR-004**: System MUST implement separate data loading logic: `Recent statuses` update via a socket stream, while `Status that were presented` are fetched from the local viewed history table in SQLite.
- **FR-005**: System MUST purge statuses from local storage (SQLite and Hive) automatically when they exceed 24 hours from their `timestamp`.
- **FR-006**: System MUST implement search logic within the Cubit to filter `StatusEntity` by `authorName` across all sections.
- **FR-007**: System MUST replicate the provided design exactly, including "Updates" title, Search Bar, "Status" header, "Add Status" tile with circular (+) icon, "Recent status" section, "Status that were presented" section, and custom Circular Avatars with status rings (green for recent, grey for viewed).
- **FR-008**: System MUST integrate Pencil and Camera Floating Action Buttons stacked vertically above the bottom navigation bar.
- **FR-009**: System MUST ensure the Bottom Navigation Bar remains consistent with the rest of the application.

### Key Entities

- **StatusEntity**: Domain entity with `id`, `authorName`, `authorAvatar`, `timestamp`, `expiresAt`, and `isViewed`.
- **StatusModel**: Data Transfer Object handling JSON serialization and SQLite mapping.
- **StatusCubit**: State manager handling offline-first loading, search filtering, and socket updates.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All unexpired statuses load from SQLite within 100ms when offline.
- **SC-002**: Statuses older than 24 hours are successfully purged from SQLite without user intervention.
- **SC-003**: Incoming statuses via Socket.io appear in the "Recent status" list within 200ms of receipt.
- **SC-004**: The UI layout passes a pixel-perfect review against the provided `image_0.png` design.
- **SC-005**: Searching filters the list instantly without API calls, relying strictly on Cubit-level filtering of local data.

## Assumptions

- Hive will be used to store simple preferences (e.g., last sync timestamp), while SQLite is used for the actual status records.
- The `google_fonts` package or core typography is already configured to match the design's font styles.
- Socket.io infrastructure is already set up and can simply be hooked into via `SocketService`.
