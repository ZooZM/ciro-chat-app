# Feature Specification: Optimize Chat Lifecycle

**Feature Branch**: `003-optimize-chat-lifecycle`  
**Created**: April 24, 2026  
**Updated**: April 27, 2026  
**Status**: Draft  
**Input**: User description: "Conduct a comprehensive review and optimization of the Chat feature (both P2P and Group Chat). Requirements: 1. Logic Alignment: Ensure the frontend implementation strictly follows the Chat, Voice, and Video call Lifecycle defined in the backend's .md file @E:\zeyad\ciro-chat-app\AGENT_CHAT_LIFECYCLE.md. 2. Optimization over Refactoring: Focus on improving and refining the existing code and fixing bugs rather than rewriting the architecture from scratch. 3. Core Usage: Strictly use existing constants, theme data, and utility classes from the 'lib/core/' directory. Replace any hardcoded strings, colors, or icons with their corresponding 'const' versions from core. 4. Call Integration: Verify that Voice and Video call triggers are properly hooked into the chat lifecycle without breaking the P2P message flow. 5. Performance: Optimize Cubit states to prevent unnecessary UI rebuilds during real-time socket updates."

## Clarifications

### Session 2026-04-25

- Q: Should all 7 new tasks (Group Chat bug, Group Info, message rendering, attachment actions, voice notes, cleanup, audit) be folded into this spec or split into a new feature? → A: Option A — Add all 7 tasks to the existing `003-optimize-chat-lifecycle` spec as new user stories.
- Q: How does the backend represent system/admin event messages? → A: Confirmed from `message.schema.ts`: `MessageType.SYSTEM = 'system'` with sentinel `senderId` `ObjectId('000000000000000000000000')` and event text in `content`. Root cause of rendering bug: Flutter `messageTypeFromString()` has no `'system'` case.
- Q: Backend `MessageType` enum lacks `location` and `audio`. How to handle Location and Audio attachments? → A: Option A — Add `LOCATION = 'location'` and `AUDIO = 'audio'` to the backend `MessageType` enum. Full backend editing is authorized (`E:\zeyad\chat-app-backend`).
- Q: Which Flutter package for Location picker, and how to render location messages? → A: Option A — Use `google_maps_flutter` for full interactive map picker + Google Maps Static API thumbnail in rendered bubble. Create a `.env` file for `GOOGLE_MAPS_API_KEY`.
- Q: Should Poll and Event attachment actions also be implemented, or only the 6 explicitly requested? → A: Option B — Implement all 8 actions (Camera, Gallery, Document, Location, Contact, Audio, Poll, Event). Poll is available in **group chat only**. Excluded from scope: Invoice, Chip-in, AI Images.

### Session 2026-04-27

- Q: Should the 6 new post-implementation issues (Video messages, Resend failed, Block user, Search in chatroom, Splash preload, ChatInfoScreen logic) be added to the existing spec? → A: Yes — add all 6 as new user stories (US11–US16) with corresponding FRs and SCs.
- Q: Does the backend have any block user logic? → A: No. The backend at `E:\zeyad\chat-app-backend\src\modules\chat` has zero block-related endpoints, schemas, or services. Full backend implementation is required.
- Q: The `MessageType` enum has no `video` type. → A: Add `VIDEO = 'video'` to both backend and frontend `MessageType` enums.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Real-time Chat Experience (Priority: P1)

Users should experience a seamless, lag-free real-time P2P and Group chat experience without unnecessary UI stutters or rebuilds when receiving rapid socket updates.

**Why this priority**: Core functionality of the chat application relies on a responsive messaging experience.

**Independent Test**: Can be fully tested by sending multiple rapid messages in P2P and Group chats and verifying the UI remains responsive and does not needlessly rebuild non-affected widgets.

**Acceptance Scenarios**:

1. **Given** an active chat view, **When** rapid socket updates (typing status, online status) occur, **Then** only the relevant UI components update without rebuilding the entire list.
2. **Given** a high volume of incoming messages, **When** received in a Group Chat, **Then** the application processes them smoothly without performance degradation.

---

### User Story 2 - Non-Intrusive Call Integration (Priority: P1)

Users receiving or initiating Voice and Video calls should not have their text chat flow interrupted. The call state should act as an overlay or distinct state.

**Why this priority**: Essential to strictly follow the Chat and Call lifecycle without degrading the text messaging experience.

**Independent Test**: Can be fully tested by initiating a call while actively typing or reading messages, ensuring the chat UI remains accessible or gracefully manages the call UI.

**Acceptance Scenarios**:

1. **Given** a user is typing a message, **When** an incoming call occurs, **Then** the call UI appears as an overlay, and text chat state is preserved.
2. **Given** an ongoing voice call, **When** navigating the chat view, **Then** the chat messages can still be read and sent without affecting the active call.

---

### User Story 3 - Codebase Consistency (Priority: P2)

The chat feature strictly adheres to the core design system and utility classes, ensuring visual and architectural consistency.

**Why this priority**: Reduces technical debt and ensures a uniform aesthetic across the app.

**Independent Test**: Can be tested by verifying that no hardcoded strings, colors, or icons are used in the chat feature UI, and all styling comes from `lib/core/`.

**Acceptance Scenarios**:

1. **Given** the chat UI, **When** rendering components, **Then** only constants and theme data from `lib/core/` are applied.

---

### User Story 4 - Group Chat Persistence Bug Fix (Priority: P0)

When a user sends a message in a Group Chat, exits the room, and re-enters, the UI must correctly identify the room as a Group Chat (not P2P). The `ChatRoomType` must be correctly persisted in SQLite and passed through `ChatCubit` → `ChatRoomScreen` navigation.

**Why this priority**: P0 — This is a data integrity bug that breaks the fundamental Group Chat experience.

**Independent Test**: Send a message in a Group Chat, navigate back to the chat list, re-enter the same Group Chat, and verify the AppBar shows group metadata (participant count, group avatar icon) instead of P2P metadata (online status, phone number).

**Acceptance Scenarios**:

1. **Given** a Group Chat room persisted in SQLite, **When** the user re-opens it from the chat list, **Then** `ChatSession.type` is `ChatRoomType.GROUP` and the UI renders group-specific elements.
2. **Given** a P2P Chat room, **When** the user re-opens it, **Then** `ChatSession.type` is `ChatRoomType.PRIVATE` and the UI renders P2P-specific elements.

---

### User Story 5 - Group Info Logic Integration (Priority: P1)

The existing Group Info UI (`GroupInfoPage`) must be connected to real business logic — fetching and displaying real-time group members, group description, and admin status from the local SQLite database and/or socket service.

**Why this priority**: The UI exists but is disconnected from data, making the feature non-functional.

**Independent Test**: Open a Group Chat, tap the AppBar to navigate to Group Info, and verify participant names, admin badges, and group description are sourced from the database (not hardcoded).

**Acceptance Scenarios**:

1. **Given** a Group Chat with 5 participants, **When** the user opens Group Info, **Then** all 5 participants are listed with correct names and admin status.
2. **Given** a group admin updates the group description, **When** the UI refreshes, **Then** the new description is displayed.

---

### User Story 6 - Message Rendering Fix (Priority: P0)

Certain messages (specifically system/admin event messages such as "created the group" or "removed member") are not rendering inside the chat screen. The `MessageMapper` and `ListView` logic must handle all message types, including system messages.

**Why this priority**: P0 — Missing messages silently break the chat history and mislead users about conversation state.

**Independent Test**: Open a Group Chat that contains a system message (e.g., group creation event). Verify the message appears in the chat screen.

**Acceptance Scenarios**:

1. **Given** a message with `messageType: 'system'` and sentinel `senderId` (`000000000000000000000000`), **When** the chat room renders, **Then** the message appears as a centered, styled system event bubble (not a sender-aligned chat bubble).
2. **Given** any valid message from the backend, **When** mapped by `MessageMapper`/`Message.fromMap`, **Then** no message is silently dropped.

---

### User Story 7 - Chat Attachment Actions (Priority: P1)

Implement the frontend and backend logic for the attachment actions shown in the bottom sheet: **Camera**, **Gallery**, **Document**, **Location**, **Contact**, **Audio**, **Poll** (group chat only), and **Event**. Explicitly **excluded** from this scope: Invoice, Chip-in, and AI Images.

**Why this priority**: Core multimedia communication features expected by users.

**Independent Test**: Open the attachment sheet, tap each implemented action, complete the flow (pick/capture/record), and verify the message is sent via socket and rendered in the chat.

**Acceptance Scenarios**:

1. **Given** a user taps "Camera", **When** they capture a photo, **Then** the image is uploaded and sent as an `image` message type.
2. **Given** a user taps "Location", **When** they select a location via the `google_maps_flutter` interactive map picker, **Then** a location message is sent with `metadata: { latitude, longitude, address }` and rendered with a static map thumbnail. Tapping the bubble opens the native maps app.
3. **Given** a user taps "Audio", **When** they pick an audio file, **Then** an audio message is sent and rendered with a playback widget.
4. **Given** a user is in a **Group Chat** and taps "Poll", **When** they create a poll with a question and options, **Then** a poll message is sent and rendered with votable options.
5. **Given** a user is in a **P2P Chat**, **Then** the "Poll" option is hidden or disabled in the attachment sheet.
6. **Given** a user taps "Event", **When** they fill in event details (title, date/time), **Then** an event message is sent and rendered with event info.

---

### User Story 8 - Voice Notes Stability (Priority: P1)

The Voice Note feature (recording, sending via sockets, and local playback) must work correctly without state leaks, audio overlaps, or controller disposal errors.

**Why this priority**: Voice notes are a core communication feature; instability degrades trust.

**Independent Test**: Record and send 3 consecutive voice notes, play them back in order, and verify no audio overlaps, no controller exceptions in logs, and correct waveform rendering.

**Acceptance Scenarios**:

1. **Given** a user records a voice note, **When** they release the mic button, **Then** the recording stops cleanly and is sent without `PlatformException`.
2. **Given** two voice notes in a chat, **When** the user plays the second while the first is still playing, **Then** the first stops automatically before the second starts.

---

### User Story 9 - Static/Mock Data Cleanup (Priority: P2)

Conduct a full sweep of the Chat feature and remove all static/mock data. All data displayed in the UI must flow from repositories (SQLite/Backend API). No hardcoded message lists, user names, or participant counts.

**Why this priority**: Mock data masks real bugs and prevents proper testing.

**Independent Test**: Grep the `lib/features/chat/` directory for any hardcoded data arrays, static message lists, or mock `ChatSession`/`Message` objects. Verify zero results.

**Acceptance Scenarios**:

1. **Given** the chat feature codebase, **When** scanned for static/mock data, **Then** zero instances are found — all data comes from `ChatLocalDataSource`, `ChatRemoteDataSource`, or `SocketService`.

---

### User Story 10 - Codebase Audit (Priority: P2)

Scan the codebase and current feature files to identify and complete any pending tasks that were previously started but not finished (TODO markers, commented-out code, incomplete handlers).

**Why this priority**: Prevents technical debt accumulation and ensures all started work reaches completion.

**Independent Test**: Search for `TODO`, `FIXME`, `HACK`, `XXX`, and commented-out function bodies in `lib/features/chat/`. Verify all are resolved or have documented deferral reasons.

**Acceptance Scenarios**:

1. **Given** the chat feature codebase, **When** scanned for TODO/FIXME markers, **Then** each is either resolved or has a documented deferral in the spec.

---

### User Story 11 - Audio Waveform Local Persistence (Priority: P1)

When a voice note message is displayed, the waveform visualization data must be cached locally so the audio waveform is not re-extracted each time the widget is built or the user re-enters the chat.

**Why this priority**: Re-extracting waveform data on every widget rebuild wastes CPU cycles, delays rendering, and triggers redundant native `MediaCodec` allocations.

**Independent Test**: Send a voice note, exit the chat, re-enter. Verify the waveform renders instantly from cache without calling `preparePlayer(shouldExtractWaveform: true)` again.

**Acceptance Scenarios**:

1. **Given** a voice note whose waveform was previously extracted, **When** the user re-enters the chat room, **Then** the waveform renders from cached data without re-extracting from the audio file.
2. **Given** a newly received voice note, **When** the waveform is first extracted, **Then** the extracted samples are persisted to local storage for future use.

---

### User Story 12 - Video Message Support (Priority: P1)

Users must be able to send and receive video messages in both P2P and Group chats. The video attachment follows a WhatsApp-style UX: users can pick a video from their gallery, the video is uploaded and rendered as a thumbnail with a play button in the chat bubble. Multiple media messages (images + videos) should be viewable in a horizontal swipe gallery.

**Why this priority**: Video messaging is a core expectation for any modern chat application.

**Independent Test**: Open the attachment sheet, select a video from gallery, send it. Verify the video uploads, renders as a thumbnail bubble with play icon, and tapping it opens a full-screen player.

**Acceptance Scenarios**:

1. **Given** a user taps "Gallery" or a new "Video" attachment option, **When** they select a video file, **Then** the video is uploaded via the upload endpoint and sent as a `video` message type with `metadata: { duration, mimeType, thumbnailUrl }`.
2. **Given** a received video message, **When** rendered in the chat, **Then** a video thumbnail with a centered play-button overlay is displayed.
3. **Given** multiple media messages (images + videos) in a chat, **When** the user taps any media bubble, **Then** a full-screen gallery opens allowing left-right swipe between all media in the conversation.

---

### User Story 13 - Resend Failed Messages (Priority: P1)

When a message fails to send (status: `error`), a resend icon button must appear alongside the message bubble so the user can tap to retry sending.

**Why this priority**: Users currently have no way to recover from message send failures, leading to lost messages and frustration.

**Independent Test**: Disable network, send a message, verify it shows error state with a resend icon. Re-enable network, tap resend, verify the message is delivered successfully.

**Acceptance Scenarios**:

1. **Given** a message with `MessageStatus.error`, **When** the message bubble renders, **Then** a resend icon (circular arrow) is displayed adjacent to the bubble.
2. **Given** a user taps the resend icon, **When** the network is available, **Then** the message is re-sent with its original `clientMessageId` and the status transitions from `error` → `pending` → `sent`.
3. **Given** a user taps resend but network is still unavailable, **Then** the message remains in `error` state and the user sees a brief error notification.

---

### User Story 14 - Block User (Priority: P2)

Users must be able to block and unblock other users. When a user is blocked: no messages can be sent or received between the two parties, the blocked user's messages are hidden from the chat, and the block status is reflected in the Chat Info screen.

**Why this priority**: User safety and privacy feature required for any production messaging app.

**Independent Test**: Open a P2P chat, navigate to Chat Info, tap "Block user", confirm the action. Verify the user is blocked, messages stop flowing, and the block status is reflected. Unblock and verify messaging resumes.

**Acceptance Scenarios**:

1. **Given** a user views the Chat Info screen, **When** they tap "Block user" and confirm, **Then** the backend records the block, the socket stops delivering messages from the blocked user, and the UI shows "Unblock user" instead.
2. **Given** a user has blocked another user, **When** the blocked user sends a message, **Then** the message is silently dropped by the backend and never delivered to the blocking user.
3. **Given** a user unblocks a previously blocked user, **When** messaging resumes, **Then** new messages flow normally and the UI reverts to "Block user".

---

### User Story 15 - Search in Chat Room (Priority: P2)

Users must be able to search for messages within a specific chat room. The search results should highlight matching messages and allow the user to navigate to them in the chat scroll.

**Why this priority**: Improves message discoverability in long conversations.

**Independent Test**: Open a chat with many messages, tap "Search in conversation" from the menu, type a keyword. Verify matching messages are highlighted and tapping a result scrolls to that message.

**Acceptance Scenarios**:

1. **Given** a user taps "Search in conversation" from the chat room menu, **When** the search bar appears, **Then** the user can type a query and see matching messages listed.
2. **Given** search results are displayed, **When** the user taps a result, **Then** the chat scrolls to that specific message and highlights it briefly.
3. **Given** a search query with no matching messages, **Then** the user sees a "No results found" message.

---

### User Story 16 - Chat Info Screen Full Logic (Priority: P1)

The P2P Chat Info screen (`ChatInfoScreen`) must be connected to real data and all interactive elements must be functional. Quick action buttons (Search, Video call, Voice call) must trigger actual actions. Media section must show real shared media. Settings toggles must persist state.

**Why this priority**: The Chat Info screen is a primary navigation target but currently contains static data and empty handlers.

**Independent Test**: Open a P2P chat, tap the header to navigate to Chat Info. Verify: profile data comes from `ChatSession`, quick actions trigger calls/search, media section shows real shared media, and settings toggles persist.

**Acceptance Scenarios**:

1. **Given** a user opens Chat Info, **Then** the profile section displays real name, phone number, and avatar from the `ChatSession` entity (not hardcoded).
2. **Given** a user taps the "Video call" quick action, **Then** a video call is initiated via `CallCubit`.
3. **Given** a user taps the "Voice call" quick action, **Then** a voice call is initiated via `CallCubit`.
4. **Given** a user toggles "Mute notifications", **Then** the preference is persisted locally and affects notification delivery.
5. **Given** the media section, **When** displayed, **Then** it shows actual shared media from the chat room (images, videos, documents).

---

### User Story 17 - Splash Screen Chat Preload (Priority: P2)

The chat list data should be preloaded during the splash screen to reduce perceived loading time when the user lands on the home screen.

**Why this priority**: Improves perceived app startup performance.

**Independent Test**: Launch the app, observe the splash screen, then landing on home. The chat list should be immediately visible without a loading spinner.

**Acceptance Scenarios**:

1. **Given** a user launches the app, **When** the splash screen is displayed and authentication is verified, **Then** the chat list data is fetched in the background before navigating to the home screen.
2. **Given** the chat list was preloaded, **When** the home screen appears, **Then** the chat list renders immediately without a loading indicator.

---

### Edge Cases

- What happens when a socket reconnects during an active call?
- How does system handle incoming calls when the user is already in a call?
- How are missed events handled if the socket drops briefly during high message throughput?
- What happens when SQLite returns a `ChatSession` with a `null` or missing `type` column (schema migration edge case)?
- How does the system handle a voice note recording if the app is backgrounded mid-recording? (Behavior: The recording should be stopped and sent immediately).
- What happens if the backend returns a message type not recognized by `messageTypeFromString` (e.g., `system`, `event`)?
- How does the Location attachment behave when the user denies location permission?
- What happens when a video file exceeds the maximum upload size?
- How does the block user feature handle existing unread messages from the now-blocked user?
- What happens when a user searches for a term that appears in a message that was deleted?
- How does resend handle a message whose room was deleted or the user was removed from the group?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST process real-time socket updates via `ChatCubit` without causing full-page UI rebuilds.
- **FR-002**: System MUST manage Voice and Video call states as a separate layer or distinct state in `SocketService` and `ChatCubit` to prevent disruption of text chat.
- **FR-003**: System MUST align the frontend implementation with the Chat, Voice, and Video call Lifecycle defined in `AGENT_CHAT_LIFECYCLE.md`.
- **FR-004**: System MUST strictly use constants, theme data, and utilities from `lib/core/` for all chat-related UI components.
- **FR-005**: System MUST preserve the P2P message flow integrity when call triggers (initiate, answer, end) are received via the socket.
- **FR-006**: System MUST correctly persist and restore `ChatRoomType` (PRIVATE/GROUP) across SQLite round-trips and navigation flows.
- **FR-007**: System MUST render all backend message types without silently dropping any messages. This includes `MessageType.SYSTEM` (value `'system'`) which uses a sentinel `senderId` of `ObjectId('000000000000000000000000')` and carries event text in the `content` field.
- **FR-008**: System MUST implement Camera, Gallery, Document, Location, Contact, Audio, Poll, and Event attachment actions with end-to-end send/render flow. Backend `MessageType` enum must be extended with `LOCATION = 'location'`, `AUDIO = 'audio'`, `POLL = 'poll'`, and `EVENT = 'event'` in `message.schema.ts`. Location uses `google_maps_flutter` for the picker and Google Maps Static API for the chat bubble thumbnail. The `GOOGLE_MAPS_API_KEY` must be stored in a `.env` file at the project root (not hardcoded). Poll attachment is only available in Group Chat rooms.
- **FR-009**: System MUST ensure voice note recording, sending, and playback are free of state leaks, audio overlaps, and controller disposal errors.
- **FR-010**: System MUST NOT contain any static/mock data in the Chat feature — all data flows from repositories.
- **FR-011**: `GroupInfoPage` MUST display real-time group members, admin status, and description from the local database.
- **FR-012**: System MUST support sending and receiving video messages. The `MessageType` enum must be extended with `VIDEO = 'video'` on both backend and frontend. Video messages render as a thumbnail with a play-button overlay. A full-screen media gallery must support horizontal swiping between all images and videos in a conversation.
- **FR-013**: System MUST display a resend icon button adjacent to any message bubble with `MessageStatus.error`. Tapping the icon must re-send the message using the original `clientMessageId` for idempotency.
- **FR-014**: System MUST implement a block/unblock user feature with full backend support (schema, REST endpoints, socket guard) and frontend integration (ChatInfoScreen UI, ChatCubit method, confirmation dialog). Blocked users cannot exchange messages.
- **FR-015**: System MUST provide in-chat search functionality. Users can search messages within a specific chat room by keyword, view results, and navigate to the matching message in the scroll view.
- **FR-016**: `ChatInfoScreen` MUST display real data from `ChatSession`, wire quick-action buttons to `CallCubit` and search, show real shared media, and use `AppColors`/`AppConstants` exclusively (no hardcoded values).
- **FR-017**: System MUST preload chat list data during the splash screen so the home screen renders immediately without a loading indicator.

### Key Entities

- **ChatCubit State**: Represents the current UI state of the chat, optimized for targeted rebuilds.
- **SocketService State**: Represents the real-time connection and event handling logic, separating messaging and calling events.
- **Call Overlay/State**: The representation of an active or incoming Voice/Video call.
- **ChatSession**: Room entity with `ChatRoomType` (PRIVATE/GROUP), persisted in SQLite with `type`, `participants`, and `admins` columns.
- **Message**: Chat message entity with `MessageType` enum — must add `system`, `location`, `audio`, `poll`, `event`, and `video` variants to match backend. System messages use sentinel `senderId` `000000000000000000000000`. Location messages carry `metadata: { latitude, longitude, address }`. Audio messages carry `metadata: { duration, mimeType }`. Poll messages carry `metadata: { question, options, votes }`. Event messages carry `metadata: { title, dateTime, description }`. Video messages carry `metadata: { duration, mimeType, thumbnailUrl }`.
- **AttachmentSheetWidget**: Bottom sheet presenting attachment actions; handlers must be wired to `ChatCubit` methods.
- **BlockedUser**: Represents a block relationship between two users. Stored on the backend User schema as a `blockedUsers` array of user IDs.
- **LocationService**: Centralized service in `lib/core/services/` that handles location permission, GPS availability, position fetching, and reverse geocoding.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: UI rebuilds during real-time typing or status updates are reduced to only affected widgets (measured via Flutter DevTools).
- **SC-002**: 100% of hardcoded strings, colors, and icons in the chat feature are replaced with `lib/core/` equivalents.
- **SC-003**: Initiating or receiving a call during an active text chat preserves the typed text and scroll position.
- **SC-004**: Socket event handling accurately implements the states outlined in `AGENT_CHAT_LIFECYCLE.md` (Connecting, Connected, Reconnecting, etc.).
- **SC-005**: Group Chat rooms persist their `ChatRoomType.GROUP` across exit/re-entry — verified by SQLite query and UI assertion.
- **SC-006**: Zero messages are silently dropped when rendering a chat room (verified by comparing SQLite message count vs. rendered `ListView` itemCount).
- **SC-007**: All 8 attachment actions (Camera, Gallery, Document, Location, Contact, Audio, Poll, Event) complete an end-to-end send-and-render cycle. Poll is only available in Group Chat.
- **SC-008**: Voice note recording + playback has zero `PlatformException` errors in debug console across 10 consecutive test cycles.
- **SC-009**: `grep -r` for mock/static data arrays in `lib/features/chat/` returns zero results.
- **SC-010**: All TODO/FIXME markers in `lib/features/chat/` are resolved or documented.
- **SC-011**: Waveform data is loaded from local cache on second render — `preparePlayer(shouldExtractWaveform: true)` is NOT called when cached data exists.
- **SC-012**: Video messages complete an end-to-end send-and-render cycle. The media gallery supports horizontal swipe between all media (images + videos) in the conversation.
- **SC-013**: 100% of messages with `MessageStatus.error` display a visible resend icon. Tapping resend recovers the message when network is available.
- **SC-014**: Blocking a user prevents all message exchange between the two parties. Unblocking restores normal messaging.
- **SC-015**: In-chat search returns results within 1 second for conversations with up to 10,000 messages.
- **SC-016**: `ChatInfoScreen` has zero hardcoded values and all interactive elements trigger real actions.
- **SC-017**: Chat list is visible on the home screen within 500ms of navigation from splash — no loading spinner shown.

## Assumptions

- The existing `ChatCubit` and `SocketService` provide a foundation that can be refactored into without a complete rewrite.
- `AGENT_CHAT_LIFECYCLE.md` is the absolute source of truth for the socket and call lifecycle.
- UI overlay mechanisms (like Flutter's `Overlay` or state-driven dialogs/bottom sheets) are acceptable for non-intrusive call handling.
- The backend already supports the `POST /chat/upload` endpoint for multimedia file uploads.
- System/event messages from the backend (e.g., "created the group", "removed member") use `messageType: 'system'` with a sentinel `senderId` of `ObjectId('000000000000000000000000')`. The Flutter `MessageType` enum and `messageTypeFromString()` must be extended to handle this.
- The backend codebase at `E:\zeyad\chat-app-backend` is fully editable. Schema and service changes are authorized for this feature.
- A `.env` file at the Flutter project root will store `GOOGLE_MAPS_API_KEY` for the location picker and static map thumbnails. This key must be loaded via `flutter_dotenv` or `--dart-define` and never hardcoded.
- The block user feature will store blocked user IDs on the User schema in MongoDB. The backend will implement REST endpoints for block/unblock and a socket-level guard to prevent message delivery.
- Video upload uses the same `POST /chat/upload` endpoint as images and files. Maximum video file size follows the same limits as other uploads.
- Waveform cache data will be stored as JSON in the message's `metadata` column in SQLite, alongside existing metadata fields.
- The splash screen preload will leverage the existing `ChatCubit.hydrateRooms()` method, called after authentication is verified but before navigation to the home screen.
