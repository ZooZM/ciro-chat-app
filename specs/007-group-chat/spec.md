# Feature Specification: Group Chat

**Feature Branch**: `007-group-chat`  
**Created**: 2026-05-14  
**Status**: Draft  
**Input**: User description: "Implement group chat feature"

## Clarifications

### Session 2026-05-14

- Q: Are group voice/video calls in scope for v1? → A: Both group voice AND video calls are in scope for v1.
- Q: What is the maximum number of participants per group call? → A: 32+ participants (requires deploying an SFU media server).
- Q: When a member is removed (or leaves), what happens to their locally-cached group message history? → A: Keep as read-only — the device retains messages received while a member, but the group becomes non-interactive.
- Q: Is group call recording in scope for v1? → A: Local-only recording — recorder's device captures the call locally; no server-side recording; consent indicator shown to all participants during recording.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a Group (Priority: P1)

A user wants to start a conversation with multiple people at once. They tap a "New Group" action, give the group a name, optionally set a group photo, and select at least one other contact to add. Once created, the group appears in their conversations list and all selected members receive it immediately.

**Why this priority**: Without group creation, no other group chat feature is accessible. This is the entry point for the entire feature.

**Independent Test**: Can be fully tested by creating a group with a name and 2 members — the group appears in all members' conversation lists and displays correctly.

**Acceptance Scenarios**:

1. **Given** a user is on the conversations list, **When** they initiate "New Group", select 2 contacts, enter a group name, and confirm, **Then** a group conversation is created and immediately visible for all selected members including the creator.
2. **Given** a user attempts to create a group, **When** they do not enter a group name, **Then** creation is blocked and a clear error message is shown.
3. **Given** a user attempts to create a group, **When** they select no other members (only themselves), **Then** creation is blocked with an appropriate message.
4. **Given** a user creates a group, **When** a group photo is not uploaded, **Then** the group is created successfully with a default placeholder image.
5. **Given** a user uploads a group photo during creation, **When** the group is created, **Then** the photo is visible as the group avatar in the conversations list and group chat screen.

---

### User Story 2 - Send and Receive Messages in a Group (Priority: P1)

A group member opens a group conversation and exchanges messages with all other members in real time. Each message shows the sender's name above the message bubble so members can identify who wrote what. All existing message types (text, image, video, voice) work the same as in 1-to-1 chats.

**Why this priority**: Core messaging functionality is the primary reason groups exist. Equal priority to creation because neither delivers value alone.

**Independent Test**: Two members can open the same group and send text messages that appear in both sessions with correct sender names displayed.

**Acceptance Scenarios**:

1. **Given** a user is in a group chat, **When** they send a text message, **Then** all other online group members see the message appear in real time with the sender's name above it.
2. **Given** a group member receives a message, **When** they view it, **Then** the sender's name is shown above the message bubble (not shown on the user's own messages).
3. **Given** a user is in a group chat, **When** they send a photo or video, **Then** it is delivered to all members the same way as in 1-to-1 chat.
4. **Given** a user is in a group chat, **When** another member is typing, **Then** a typing indicator appears showing that member's name.
5. **Given** a user sends a message while offline, **When** they reconnect, **Then** the message is delivered to all group members and the status updates from pending to sent.

---

### User Story 3 - Message Delivery and Read Status in Groups (Priority: P2)

A message sender wants to know whether their group message has been delivered and read. Delivery and read receipts work in group context — the sender sees tick indicators that reflect the delivery/read state across all members.

**Why this priority**: Status receipts are important for sender confidence but the chat is usable without them.

**Independent Test**: Send a message in a group and observe that tick indicators update correctly as other members receive and open the message.

**Acceptance Scenarios**:

1. **Given** a sender sends a group message, **When** the server confirms receipt, **Then** the message shows a single-tick (sent) indicator.
2. **Given** a group message has been sent, **When** all members' devices have received it, **Then** the message shows a double-grey-tick (delivered) indicator.
3. **Given** a group message has been delivered, **When** all current group members have read the message, **Then** the message shows a double-blue-tick (read) indicator.
4. **Given** a user receives a group message while the group chat is open, **Then** the message is immediately marked as read and the sender's ticks update accordingly.

---

### User Story 4 - Group Info and Settings (Priority: P2)

A group member can open a group info screen to see the full member list, the group name, and the group photo. The group admin (creator) can additionally edit the group name, change the group photo, and remove members.

**Why this priority**: Group management enriches the experience but users can still chat without it.

**Independent Test**: Open group info for a group, verify the member list is complete and the admin can tap a member to remove them.

**Acceptance Scenarios**:

1. **Given** any group member taps the group info action, **When** the group info screen opens, **Then** they see the group name, group photo, and a list of all current members with their names and phone numbers.
2. **Given** the group admin is on the group info screen, **When** they edit the group name and save, **Then** the new name is immediately reflected in the conversations list and all members' group chat screens.
3. **Given** the group admin is on the group info screen, **When** they change the group photo, **Then** the new photo appears everywhere the group avatar is shown.
4. **Given** the group admin taps a member's name in the group info screen, **When** they choose "Remove from group", **Then** that member is immediately removed and can no longer send or receive messages in the group.
5. **Given** a non-admin member is on the group info screen, **When** they view a member's entry, **Then** the "Remove" option is not visible or is disabled.
6. **Given** a member has been removed from a group, **When** they open the app, **Then** they can no longer see or access that group conversation.

---

### User Story 5 - Admin Succession and Group Exit (Priority: P3)

A group member (admin or not) wants to leave the group. Non-admin members can leave freely. The admin must either designate a new admin before leaving or accept that [NEEDS CLARIFICATION: admin succession policy — "system auto-promotes the longest-standing member" vs "admin must manually pick a replacement before leaving"].

**Why this priority**: Edge-case lifecycle management; group chat is fully functional without this.

**Independent Test**: A non-admin member taps "Leave Group" and is removed; they no longer see the group in their list.

**Acceptance Scenarios**:

1. **Given** a non-admin member views group info, **When** they choose "Leave Group" and confirm, **Then** they are removed from the group immediately and the group disappears from their conversations list.
2. **Given** the group admin views group info, **When** they choose "Leave Group" and confirm, **Then** the system automatically promotes the longest-standing member (earliest join date) to Admin, and the original admin is removed from the group.
3. **Given** a member has left a group, **When** they try to access the old group link, **Then** they are informed they are no longer a member.

---

### User Story 6 - Group Voice and Video Calls (Priority: P2)

A group member wants to start a voice or video call with all other members of the group. They tap a call action in the group header, choose voice or video, and the call initiates — all other group members receive an incoming-call invitation and can join. Multiple members can be on the call simultaneously.

**Why this priority**: Group calls extend the group experience to real-time conversation but are independent of core messaging. Messaging must work first.

**Independent Test**: Initiate a group video call from a 3-member group; two other members can accept and the three can see/hear each other in the same session.

**Acceptance Scenarios**:

1. **Given** a group member is in the group chat screen, **When** they tap "Start Voice Call" or "Start Video Call", **Then** all other group members receive an incoming-call invitation that identifies the caller and the group.
2. **Given** an incoming group call invitation is displayed, **When** a member taps "Accept", **Then** they join the active call and can hear/see other participants who have already joined.
3. **Given** an incoming group call invitation is displayed, **When** a member taps "Decline" or ignores it, **Then** they do not join the call and the caller's UI reflects the decision (declined or no response after timeout).
4. **Given** members are in an active group call, **When** a new member joins, **Then** the existing participants see/hear the new member without dropping the call.
5. **Given** members are in an active group call, **When** any member leaves the call, **Then** other members remain connected; when only one remains, the call ends.
6. **Given** a group has more than the supported maximum call participants, **When** an additional member tries to join, **Then** they receive a clear "Call is full" message and are not added.

---

### Edge Cases

- What happens if the group photo upload fails? → Group is still created with a placeholder; the photo can be set later from group info.
- What if a member being added to a group blocks the creator? → Assumption: blocked contacts cannot be added to groups; the creator sees an error.
- What if the internet drops while sending a group message? → Same offline queue behavior as 1-to-1 chat; message retries on reconnect.
- What if a user is added to a group while offline? → They receive the group and its full message history when they come back online.
- What if all members leave a group? → The group is automatically dissolved and removed for any remaining member.
- Minimum group size: a group with only 1 member (after others leave) should be dissolved or the last member should be allowed to leave.

## Requirements *(mandatory)*

### Functional Requirements

**Group Creation**

- **FR-001**: A user MUST be able to initiate a new group from the conversations list.
- **FR-002**: Group creation MUST require a non-empty group name (1–50 characters).
- **FR-003**: A user MUST be able to select one or more contacts as initial group members; at least one other member is required.
- **FR-004**: A user MAY optionally set a group photo at creation time; omitting it MUST NOT block group creation.
- **FR-005**: Upon creation, all selected members MUST immediately see the group in their conversations list without requiring a refresh.
- **FR-006**: The creating user MUST automatically be assigned the Admin role.

**Group Messaging**

- **FR-007**: Group members MUST be able to send and receive text, image, video, and voice messages within a group, with identical behavior to 1-to-1 messaging.
- **FR-008**: Every received message in a group MUST display the sender's name above the message bubble; the current user's own messages MUST NOT show a sender label.
- **FR-009**: Typing indicators MUST display the typing member's name (e.g., "Ali is typing…") within the group chat screen.
- **FR-010**: Messages sent while offline MUST be queued and delivered to all group members upon reconnection.

**Message Status**

- **FR-011**: Group messages MUST progress through the same status states as 1-to-1 messages: pending → sent → delivered → read.
- **FR-012**: A message MUST be marked "delivered" once all current group members' devices have acknowledged receipt.
- **FR-013**: A message MUST be marked "read" (double-blue-tick) only after ALL current group members have read it.

**Group Info & Management**

- **FR-014**: Any group member MUST be able to open a group info screen showing the group name, photo, and full member list.
- **FR-015**: The group Admin MUST be able to edit the group name; changes MUST be visible to all members in real time.
- **FR-016**: The group Admin MUST be able to change the group photo; the new photo MUST propagate to all members' screens without a restart.
- **FR-017**: The group Admin MUST be able to remove any non-admin member; removed members MUST immediately lose access to the group.
- **FR-018**: Non-admin members MUST NOT have access to remove-member or edit-group actions.
- **FR-019**: Any member MUST be able to leave a group voluntarily; the group MUST remain active for the remaining members.
- **FR-020**: When the Admin leaves, the system MUST automatically promote the member with the earliest join date to Admin before completing the admin's departure.

**Group Calls (Voice & Video)**

- **FR-021**: Any group member MUST be able to initiate a group voice call from within the group chat screen.
- **FR-022**: Any group member MUST be able to initiate a group video call from within the group chat screen.
- **FR-023**: All other group members MUST receive a real-time incoming-call invitation that clearly identifies the caller and the group name.
- **FR-024**: Any invited member MUST be able to accept or decline the incoming call; declining MUST NOT impact the call for other members.
- **FR-025**: Members who join after the call has started MUST be able to participate without disconnecting existing participants.
- **FR-026**: When a member leaves the call (or disconnects), the call MUST continue for the remaining members until only one participant remains, at which point the call MUST end automatically.
- **FR-027**: A maximum participant cap of **32** MUST be enforced per group call; members attempting to join beyond the cap MUST receive a clear message and be denied entry.
- **FR-027a**: The system MUST use an SFU (Selective Forwarding Unit) media server topology to support 32+ concurrent participants in a single call, rather than peer-to-peer mesh.

**Backwards Compatibility**

- **FR-028**: All existing 1-to-1 chat functionality (messaging, media, typing indicators, read receipts, call overlay, status updates) MUST continue to work without modification after the group chat feature is introduced.

**Removed/Left Member Behavior**

- **FR-029**: When a member is removed from a group or leaves voluntarily, their device MUST retain a local read-only copy of all messages they received while they were a member.
- **FR-030**: The group MUST appear in the removed/left member's conversations list with a visible indicator (e.g., "You are no longer a participant") and MUST NOT allow sending new messages, initiating calls, or receiving new messages.
- **FR-031**: A removed/left member MUST NOT receive any new socket events, push notifications, or backend message updates for that group.

**Group Call Recording (Local-Only)**

- **FR-032**: Any participant in an active group call MUST be able to start a **local** recording from their own device.
- **FR-033**: When a participant starts recording, a clear, persistent visual indicator (e.g., a red "REC" badge or banner) MUST be displayed to **all** participants on the call so everyone is aware recording is in progress.
- **FR-034**: When a participant stops recording (or the call ends), the visual indicator MUST disappear immediately for all participants.
- **FR-035**: The recorded media MUST be stored only on the recorder's device; the system MUST NOT upload, replicate, or share the recording to the backend or other participants automatically.
- **FR-036**: The recorder MUST be able to access, play back, rename, or delete their own recordings from a recordings list within the app.
- **FR-037**: Recording start/stop events MUST be logged locally on the recorder's device for the recorder's own reference, but MUST NOT be persisted in the group's chat history.

### Key Entities

- **Group**: Represents a multi-member conversation. Attributes: unique ID, name (required), photo (optional), list of members, designated admin, creation timestamp.
- **Group Member**: A user participating in a group. Attributes: user reference, role (Admin or Member), join timestamp.
- **Group Message**: A message within a group context. Same structure as a 1-to-1 message plus: sender identity (always visible to recipients), per-member delivery/read tracking.
- **Admin Role**: A special role held by exactly one member at a time, granting permissions to edit group details and manage membership.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can create a group with a name and at least one member in under 60 seconds from first tap to group appearing in conversations.
- **SC-002**: Group messages from any member appear for all other online members within 2 seconds of being sent under normal network conditions.
- **SC-003**: Sender names on group messages are visible without any additional tap or interaction — zero extra steps vs 1-to-1 UX.
- **SC-004**: Removing a member from a group takes effect immediately; the removed member loses access within 5 seconds on their device.
- **SC-005**: 100% of 1-to-1 chat scenarios that worked before this feature ships continue to pass without any regression.
- **SC-006**: Group info changes (name, photo) propagate to all active group members' screens within 3 seconds.

## Assumptions

- Users already have contacts stored in the app; group member selection draws from the existing contacts list.
- A group can have a maximum of 256 members (standard messaging app convention).
- Only one admin per group at any given time.
- Removed/left members' local message history retention is now a formal requirement (see FR-029 to FR-031).
- Group photos are stored and served through the same media infrastructure used for 1-to-1 message attachments.
- The app's existing offline-first message queue applies to group messages without modification.
- Existing 1-to-1 chat rooms and group chat rooms share the same room/conversation abstraction on the backend, distinguished by a `type` or `isGroup` flag.
- Notifications for group messages follow the same notification infrastructure as 1-to-1 messages; the group name appears as the conversation name in the notification.
- Group calls require an SFU media server (e.g., LiveKit, Janus, Mediasoup, or similar) to be deployed and operated as part of the backend infrastructure. The current 1-to-1 peer-to-peer WebRTC stack will continue to handle 1-to-1 calls; group calls go through the SFU.
- TURN server availability is assumed for NAT traversal across both 1-to-1 (existing) and group (new) call topologies.
- Local call recording uses device-side capture only (e.g., screen-capture API or audio-track tap). No recording media flows through the backend, so storage and bandwidth costs for recordings are zero on the server side.
- Local recording consent is satisfied by the universal in-call REC indicator (FR-033); jurisdictions requiring explicit prior consent (one-party vs. two-party consent laws) are addressed by the visible indicator — additional jurisdiction-specific consent prompts are out of scope for v1.
