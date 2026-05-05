# Feature Specification: Comprehensive Refactoring & Bug Fix Batch

**Feature Branch**: `005-refactor-bugfix-batch`  
**Created**: 2026-05-05  
**Status**: Draft  
**Input**: User description: "Resolve 8 items of technical debt, architectural improvements, and critical bugs across routing, sockets, data layer, and dead code."

## User Scenarios & Testing *(mandatory)*

### User Story 1 – Crash-Free Call Initiation (Priority: P1)

As a user, I can initiate or receive a video/voice call from any screen without the app crashing due to a missing router context.

**Why this priority**: This is a crash-level bug that blocks the core call feature from functioning at all. Any user triggering a call from the overlay experiences an unhandled exception.

**Independent Test**: Can be fully tested by initiating a call from the chat room and verifying no crash occurs. Delivers immediate stability value.

**Acceptance Scenarios**:

1. **Given** a user is in a chat room, **When** they tap the video call button, **Then** the call screen appears without any "No GoRouter found in context" error.
2. **Given** an incoming call arrives while the user is on any screen, **When** the CallOverlay processes the incoming call state, **Then** navigation to the incoming call screen succeeds without error.
3. **Given** the user is outside the router tree (e.g., in an overlay), **When** a navigation action is triggered, **Then** the system uses the global navigator key to resolve context correctly.

---

### User Story 2 – Reliable Typing Indicators (Priority: P1)

As a user chatting with another person, I see a "typing…" indicator appear when the other party is typing and disappear when they stop, in both the active chat room and the chat list subtitle.

**Why this priority**: The typing indicator is a core real-time feature that is currently unreliable. Users cannot trust the UI, which degrades the chat experience.

**Independent Test**: Can be tested by having two devices exchange typing events and verifying the indicator appears/disappears in both the chat room and the chat list screen.

**Acceptance Scenarios**:

1. **Given** User B is typing in a shared room, **When** User A views that chat room, **Then** a "typing…" indicator appears in the app bar or subtitle area.
2. **Given** User B stops typing (or the debounce timer expires), **When** User A views that chat room, **Then** the typing indicator clears and reverts to the default subtitle (e.g., "online").
3. **Given** User B is typing, **When** User A views the chat list, **Then** the chat tile for that room shows "typing…" as the subtitle instead of the last message.
4. **Given** User B stops typing, **When** User A views the chat list, **Then** the chat tile reverts to the last message preview.

---

### User Story 3 – Accurate Online/Offline Presence (Priority: P1)

As a user, I see accurate online/offline status indicators for my contacts in the chat room header and chat info screen.

**Why this priority**: Incorrect presence information erodes trust in the application's real-time capabilities.

**Independent Test**: Can be tested by toggling a user's connectivity and observing the status indicator on the other device's chat room and chat info screens.

**Acceptance Scenarios**:

1. **Given** User B goes online, **When** User A has a chat open with User B, **Then** the status indicator updates to "online" within a few seconds.
2. **Given** User B goes offline, **When** User A has a chat open with User B, **Then** the status indicator updates to "offline" within a few seconds.
3. **Given** User B's status changes, **When** User A is on the chat list, **Then** the green dot indicator on the avatar correctly reflects User B's online state.

---

### User Story 4 – Consistent Route Navigation (Priority: P2)

As a developer, all navigation across the app uses named route constants from a centralized class, ensuring no hardcoded strings exist that could break silently.

**Why this priority**: Hardcoded route strings are a maintainability hazard. They cause silent navigation failures and make refactoring error-prone. This is a critical architectural hygiene issue.

**Independent Test**: Can be verified by a codebase search confirming zero hardcoded route strings remain outside the `AppRouterName` constants class.

**Acceptance Scenarios**:

1. **Given** any file in the codebase, **When** navigation is performed (push, go, pop with path), **Then** only `AppRouterName.*` constants are used, never raw string literals.
2. **Given** a new route is added, **When** a developer follows the established pattern, **Then** they define the constant in `AppRouterName` first and reference it everywhere.

---

### User Story 5 – Centralized Socket Event Constants (Priority: P2)

As a developer, all socket event names used across the SocketService and Cubits reference a single `SocketEvents` constants class, ensuring consistency and eliminating typo risks.

**Why this priority**: Hardcoded socket event strings scattered across SocketService and Cubits create a fragile coupling where a single typo can silently break real-time features.

**Independent Test**: Can be verified by a codebase search confirming zero hardcoded socket event strings remain outside the constants class.

**Acceptance Scenarios**:

1. **Given** the `SocketService`, **When** it listens on or emits a socket event, **Then** it uses a constant from the `SocketEvents` class.
2. **Given** a Cubit that interacts with sockets, **When** it references a socket event, **Then** it uses the same `SocketEvents` constant.

---

### User Story 6 – Correct Block User Payload (Priority: P2)

As a user, when I block another user, the correct identifier (user ID) is sent to the backend, not the phone number.

**Why this priority**: Sending the wrong identifier means the backend may not process the block correctly, leading to data integrity issues.

**Independent Test**: Can be tested by blocking a user and inspecting the network request payload to confirm it contains the user's ID.

**Acceptance Scenarios**:

1. **Given** User A taps "Block user" on User B's chat info screen, **When** the API request is sent, **Then** the request path/body contains User B's unique user ID, not their phone number.

---

### User Story 7 – Correct Media Image Display (Priority: P2)

As a user viewing the chat info screen's media gallery, all shared images render correctly because their URLs are fully qualified with the server's base URL.

**Why this priority**: Without the base URL prepended, images fail to load and show broken placeholders, degrading the user experience.

**Independent Test**: Can be tested by opening a chat info screen with shared media and verifying all images load correctly.

**Acceptance Scenarios**:

1. **Given** a chat with shared image messages, **When** the user opens the chat info screen, **Then** all images in the media section load and display correctly.
2. **Given** a media message stored with a relative URL path, **When** displayed via `CachedNetworkImage`, **Then** the base URL is automatically prepended.

---

### User Story 8 – Clean Codebase Without Dead Code (Priority: P3)

As a developer, the `ChatRemoteDataSource` and `ChatRepository` abstract interfaces contain only methods that are actively used, with no empty stubs or vestigial methods.

**Why this priority**: Dead code increases cognitive load and creates confusion about the intended architecture. Removing it ensures Clean Architecture compliance per the constitution.

**Independent Test**: Can be verified by confirming the removed methods (`connect()`, `disconnect()`, `sendMessage()`) no longer exist in the abstract class, implementation, or any callers.

**Acceptance Scenarios**:

1. **Given** the `ChatRemoteDataSource` abstract class, **When** reviewed, **Then** it does not contain `connect()`, `disconnect()`, or `sendMessage(String text)`.
2. **Given** the `ChatRemoteDataSourceImpl`, **When** reviewed, **Then** the empty implementations of those methods are removed.
3. **Given** the `ChatRepository` abstract class, **When** reviewed, **Then** the corresponding dead methods are removed.
4. **Given** the `ChatRepositoryImpl`, **When** reviewed, **Then** the pass-through implementations are removed.

---

### Edge Cases

- What happens if the globalNavigatorKey is accessed before the MaterialApp is mounted?
- What happens if a typing event arrives for a room that has been deleted locally?
- What happens if a block request fails server-side — does the UI revert the optimistic update?
- What happens if an image URL is already fully qualified (starts with `http://` or `https://`)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST implement a `GlobalKey<NavigatorState>` in the routing configuration and inject it into `GoRouter` as the `navigatorKey`, enabling contextless navigation from overlays and services.
- **FR-002**: All navigation calls throughout the app MUST use `AppRouterName` constants. Zero hardcoded route strings (e.g., `'/home'`, `'/video_call'`) are permitted outside the constants class.
- **FR-003**: System MUST define a `SocketEvents` (or `SocketConstants`) class containing all socket event name strings used for both listeners and emitters, used globally.
- **FR-004**: The typing indicator MUST appear reliably when a remote user is typing and clear when they stop, in both the `ChatRoomScreen` (app bar/subtitle) and the `ChatListScreen` (chat tile subtitle).
- **FR-005**: The online/offline presence indicator MUST accurately reflect each user's connectivity state, synchronized via socket `userStatus` events and properly updating the local data layer and UI.
- **FR-006**: The Block User API request MUST send the target user's unique ID (not phone number) in the request payload/path.
- **FR-007**: All `CachedNetworkImage` instances displaying media in `chat_info_screen.dart` MUST resolve the full image URL by prepending the server's base URL when the stored path is a relative endpoint.
- **FR-008**: The dead methods `connect()`, `disconnect()`, and `sendMessage(String text)` MUST be removed from `ChatRemoteDataSource` (abstract), `ChatRemoteDataSourceImpl`, `ChatRepository` (abstract), and `ChatRepositoryImpl`.
- **FR-009**: Media and audio waveform widgets MUST NOT reload their content when scrolled out of and back into the ListView viewport. Voice note waveforms MUST render instantly from cached/persisted data without showing a loading spinner. Image thumbnails MUST be served from disk cache on scroll-back.
- **FR-010**: Opening a chat room MUST display messages instantly from local SQLite storage with zero loading state. Remote API synchronization MUST happen silently in the background. New messages from the server MUST seamlessly appear in the UI via the existing reactive stream without any explicit loading indicator.

### Key Entities

- **AppRouterName**: Centralized constants class for all named route paths.
- **SocketEvents**: Centralized constants class for all socket event strings (listeners and emitters).
- **GlobalNavigatorKey**: A global `GlobalKey<NavigatorState>` for contextless navigation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero crashes related to "No GoRouter found in context" when initiating or receiving calls from any screen.
- **SC-002**: Typing indicators appear within 1 second of the remote user starting to type and clear within 3 seconds of them stopping, in both chat room and chat list views.
- **SC-003**: Online/Offline status transitions are reflected in the UI within 5 seconds of the actual connectivity change.
- **SC-004**: A codebase-wide search for hardcoded route strings returns zero results outside `AppRouterName`.
- **SC-005**: A codebase-wide search for hardcoded socket event strings returns zero results outside `SocketEvents`.
- **SC-006**: The Block User network request payload contains the user ID, confirmed via network inspection.
- **SC-007**: All media images on the chat info screen load successfully with no broken image placeholders.
- **SC-008**: Zero dead methods remain in `ChatRemoteDataSource`, `ChatRepository`, and their implementations.
- **SC-009**: Voice note waveforms render in under 100ms on scroll-back (no spinner). Image bubbles display from cache with zero network requests on scroll-back. Message list scrolls at 60fps with 50+ mixed-media messages.
- **SC-010**: Opening a chat room with cached messages shows content in under 50ms with zero `CircularProgressIndicator` visible. Offline room opens display all locally-cached messages.

## Assumptions

- The `GoRouter` package supports `navigatorKey` for injecting a global navigator key.
- The server's base URL is already available in a centralized location (e.g., `DioClient` base URL or `AppConstants`).
- The backend API for blocking users accepts user IDs in the path parameter `/chat/block/{userId}` — no body-level change is needed.
- The existing `onUserTyping` and `onUserStatusChanged` callbacks in `SocketService` fire correctly from the server; the bugs are on the client-side state management.
- The `messageStream` getter on `ChatRemoteDataSource` is still in active use and should NOT be removed with the dead code cleanup.
