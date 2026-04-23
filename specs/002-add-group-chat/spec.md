# Feature Specification: Add Group Chat

**Feature Branch**: `002-add-group-chat`  
**Created**: 2026-04-23  
**Status**: Draft  
**Input**: User description: "now we need add a group chat i just implement a group_chat_implemntation_guide.md in root of project"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a Group Chat (Priority: P1)

As a user, I want to select multiple contacts and create a new group chat so that I can communicate with a team simultaneously.

**Why this priority**: Creating groups is the foundational step for all group chat functionality.

**Independent Test**: Can be fully tested by selecting at least one contact, providing a group name, tapping "Create", and verifying the app navigates to the new group chat screen.

**Acceptance Scenarios**:

1. **Given** I am on the contacts list, **When** I select multiple contacts, provide a group name, and submit, **Then** a new group is created via the API and I am navigated to the group chat screen.
2. **Given** a new group is successfully created, **When** the API responds, **Then** the app automatically sends a `joinRoom` socket event so I can receive messages immediately.

---

### User Story 2 - Real-Time Group Messaging (Priority: P1)

As a group member, I want to send and receive text, typing indicators, and read receipts in real-time within the group chat.

**Why this priority**: Core messaging is the primary purpose of the application.

**Independent Test**: Can be tested by opening an existing group chat, sending a message, and observing real-time updates and indicators.

**Acceptance Scenarios**:

1. **Given** I am in a group chat, **When** I send a message, **Then** it appears in the chat history for all participants.
2. **Given** multiple participants are in a group, **When** another participant sends a message, **Then** their name/number is displayed next to their message bubble.
3. **Given** another user is typing, **When** the `userTyping` socket event is received, **Then** a "User X is typing..." indicator is shown in the UI.

---

### User Story 3 - Group Administration (Priority: P2)

As a group admin (creator or promoted), I want to add new participants to the group or remove existing ones to manage the conversation space.

**Why this priority**: Group lifecycle management is essential for long-term usability.

**Independent Test**: Can be tested by opening the Group Info screen as an admin and verifying the "Add" and "Remove" options function correctly.

**Acceptance Scenarios**:

1. **Given** I am a group admin, **When** I open the Group Info screen, **Then** I see options to "Add Participant" and "Remove" next to non-admin members.
2. **Given** I select a contact to add, **When** I confirm, **Then** the user is added to the group via the API and the participant list updates.
3. **Given** I select a member to remove, **When** I confirm, **Then** the user is kicked from the group via the API.

---

### User Story 4 - Leave Group (Priority: P3)

As a group member, I want to leave a group I no longer wish to participate in.

**Why this priority**: Users must have control over their participation.

**Independent Test**: Can be tested by selecting "Leave Group" in the Group Info screen and verifying the group disappears from the chat list.

**Acceptance Scenarios**:

1. **Given** I am in a group, **When** I select "Leave Group", **Then** I am removed from the group and redirected to the main chat list.
2. **Given** I am the last admin in a group, **When** I leave, **Then** the backend automatically promotes another participant to admin.

### Edge Cases

- **Offline Creation**: What happens if a user tries to create a group while offline? (Should queue the request or show an immediate network error based on the offline-first strategy).
- **Socket Reconnection**: When the app resumes from the background, does it properly receive missed group messages?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST update the `ChatRoom` entity to include `type` (PRIVATE/GROUP), `name`, `avatarUrl`, and `admins` list.
- **FR-002**: System MUST implement REST endpoints for creating groups (`/chat/group/create`), adding members (`/chat/group/:roomId/add`), removing members (`/chat/group/:roomId/remove`), and leaving (`/chat/group/:roomId/leave`).
- **FR-003**: System MUST provide a UI to select multiple contacts for group creation.
- **FR-004**: System MUST emit a `joinRoom` socket event immediately after successfully creating a new group.
- **FR-005**: System MUST display the group `name` and `avatarUrl` in the main chat list for group rooms.
- **FR-006**: System MUST display the sender's identifier (name/number) next to message bubbles within a group chat UI.
- **FR-007**: System MUST display "User X is typing..." when `userTyping` events are received with a group `roomId`.
- **FR-008**: System MUST conditionally show "Add" and "Remove" UI elements in the Group Info screen only if the current user's phone number is in the `admins` list.

### Key Entities *(include if feature involves data)*

- **ChatRoom**: Expanded to handle `ChatRoomType.GROUP`, a list of `admins` (phone numbers), a `name`, and an `avatarUrl`.
- **Message**: Remains standard but displayed differently in the UI (showing sender details in groups).
- **User**: Contacts selected to become participants in a group.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully create a group with 1 or more selected contacts and send the first message within 10 seconds of creation.
- **SC-002**: Group chat messages are delivered and read receipts are broadcasted to all participants seamlessly via existing socket logic.
- **SC-003**: Admins can successfully add or remove participants, with the UI reflecting the changes instantly.
- **SC-004**: The group chat list visually differentiates private vs. group chats (via name and avatar).

## Assumptions

- **Existing Socket Service**: The backend is already configured to handle group `roomId` routing for `sendMessage`, `typing`, `markDelivered`, and `markRead`.
- **Admin Promotion**: The backend automatically handles promoting a new admin if the last admin leaves the group.
- **Authentication**: All new REST API requests require a standard Bearer token.
