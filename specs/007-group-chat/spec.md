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
7. **Given** any group member opens the group info screen, **When** the screen renders, **Then** a "Shared Media" section is visible — matching the layout and behavior of the equivalent section on the 1-to-1 chat info screen — showing the photos, videos, voice notes, and call-recording media that have been exchanged in the group's message history.
8. **Given** a member is viewing the Shared Media section, **When** they tap a media thumbnail, **Then** the corresponding full-size viewer (image viewer, video player, voice-note player) opens with the same interactions as opening that media from the chat thread.
9. **Given** a group has received many shared media items, **When** the member scrolls within the Shared Media section, **Then** items load lazily without blocking other group info content (member list, name, photo) from being interactive.
10. **Given** a sender retracts a message via "Delete for Everyone" (US7), **When** the deletion propagates, **Then** that media item MUST disappear from the Shared Media section on every current member's group info screen within the same propagation window as the chat-thread placeholder (FR-040).

---

### User Story 5 - Admin Succession and Group Exit (Priority: P3)

A group member (admin or not) wants to leave the group. Non-admin members can leave freely. When the admin leaves, the system automatically promotes the member with the earliest join date (longest-standing member) to Admin before completing the departure — no manual selection is required. After leaving, the member MUST be fully cut off from all group activity: no new messages received, no new messages sent, no calls initiated, no group info changes seen.

**Why this priority**: Edge-case lifecycle management; group chat is fully functional without this.

**Independent Test**: A non-admin member taps "Leave Group" and is removed; they no longer see the group in their list, cannot send messages to it, and stop receiving new messages from it.

**Acceptance Scenarios**:

1. **Given** a non-admin member views group info, **When** they choose "Leave Group" and confirm, **Then** they are removed from the group immediately and the group disappears from their conversations list.
2. **Given** the group admin views group info, **When** they choose "Leave Group" and confirm, **Then** the system automatically promotes the longest-standing member (earliest join date) to Admin, and the original admin is removed from the group.
3. **Given** a member has left a group, **When** they try to access the old group link, **Then** they are informed they are no longer a member.
4. **Given** a member just left a group, **When** they attempt to send a message to that group (through any client-side path that may still hold a stale reference), **Then** the backend MUST reject the send with an explicit "no longer a participant" error and the client surfaces a clear user-facing message; the message MUST NOT appear for the remaining group members.
5. **Given** a member just left a group, **When** any other member subsequently sends a message to that group, **Then** the leaver's device MUST NOT receive that message via socket, push notification, or REST sync; the leaver's local copy of the group remains frozen at the moment of departure.
6. **Given** a member has been forcibly removed from the group by the admin, **When** the removal completes, **Then** the same cut-off guarantees in scenarios 4 and 5 apply identically to the removed member.

---

### User Story 6 - Group Voice and Video Calls (Priority: P2)

A group member wants to start a voice or video call with all other members of the group. They tap a call action in the group header, choose voice or video, and the call initiates — all other group members receive an incoming-call invitation and can join. Multiple members can be on the call simultaneously. A "Join Call" banner is visible in the group chat screen only while a call is in progress so members can join at any time.

**Why this priority**: Group calls extend the group experience to real-time conversation but are independent of core messaging. Messaging must work first.

**Independent Test**: Initiate a group video call from a 3-member group; two other members can accept and the three can see/hear each other in the same session. Open the group chat screen while the call is ongoing and confirm the "Join Call" button is visible in the header.

**Acceptance Scenarios**:

1. **Given** a group member is in the group chat screen, **When** they tap "Start Voice Call" or "Start Video Call", **Then** all other group members receive an incoming-call invitation that identifies the caller and the group.
2. **Given** an incoming group call invitation is displayed, **When** a member taps "Accept", **Then** they join the active call and can hear/see other participants who have already joined.
3. **Given** an incoming group call invitation is displayed, **When** a member taps "Decline" or ignores it, **Then** they do not join the call and the caller's UI reflects the decision (declined or no response after timeout).
4. **Given** members are in an active group call, **When** a new member joins, **Then** the existing participants see/hear the new member without dropping the call.
5. **Given** members are in an active group call, **When** any member leaves the call, **Then** other members remain connected; when only one remains, the call ends.
6. **Given** a group has more than the supported maximum call participants, **When** an additional member tries to join, **Then** they receive a clear "Call is full" message and are not added.
7. **Given** a group call is actively in progress, **When** a group member opens the group chat screen, **Then** a prominent "Join Call" button is visible in the screen header; **When** no call is in progress, the button is not visible.
8. **Given** a participant starts recording during a voice call, **When** the recording completes, **Then** the saved file is in audio-only format (M4A/AAC) and is sent as a media message in the group chat that all group members can access and download.
9. **Given** a participant starts recording during a video call, **When** the recording completes, **Then** the saved file is in video format (MP4/MOV) and is sent as a media message in the group chat that all group members can access and download.
10. **Given** a recording is shared to the group chat, **When** the recorder's device saves the file, **Then** the file is also stored in the device gallery (for video recordings) or Downloads folder (for voice recordings) on the recorder's device for direct access outside the app.

---

### User Story 7 - Delete-for-Everyone Propagation in Groups (Priority: P2)

The sender of a group message wants to retract it so it disappears for every current group member, not just on the sender's own device. When the sender chooses "Delete for Everyone" on a message they sent, within a short window every current member's device replaces the original message (text, image, video, voice) with a "This message was deleted" placeholder, and the original content is erased from each member's local store and media cache. Existing 1-to-1 delete-for-everyone retraction-window conventions apply unchanged.

**Why this priority**: Users expect "Delete for Everyone" in groups to work symmetrically to 1-to-1. A retracted group message that still appears on other members' devices is a trust failure: the sender believes they deleted it but it remains visible. This bug was reported as the primary reason senders distrust group messaging.

**Independent Test**: 3-member group. Member A sends a text message; Members B and C see it. A long-presses the message and selects "Delete for Everyone". Within 3 s, B and C see "This message was deleted" placeholder in place of the original text. The original text MUST NOT be retrievable on B or C's devices afterwards.

**Acceptance Scenarios**:

1. **Given** Member A sent a text message to a 3-member group and both other members received it, **When** A chooses "Delete for Everyone" on that message, **Then** within 3 s Members B and C see the message replaced by the deletion placeholder, and the original text is erased from their local message stores.
2. **Given** Member B was offline when A deleted for everyone, **When** B's device next reconnects and syncs, **Then** B's device replaces the original message with the deletion placeholder BEFORE displaying the message to B; B MUST NOT see the original text on reconnect.
3. **Given** A sent an image (or video, or voice) message and then chooses "Delete for Everyone", **When** the deletion propagates, **Then** the original media file MUST be removed from each remaining member's local media cache; the cached media file MUST NOT be retrievable via the chat list, the conversation media gallery, search, or any other in-app surface.
4. **Given** the retraction window for a given message has expired (default: 1 hour after the original send time), **When** A long-presses the message, **Then** the "Delete for Everyone" option MUST NOT be offered or MUST be disabled; only "Delete for me" is available.
5. **Given** a member of the group left or was removed BEFORE A deleted the message, **When** A deletes for everyone, **Then** the leaver/removed member's local read-only copy is unaffected (per FR-031 they no longer receive new events). This is acceptable and not a leak — the message stayed exclusively with people who were members at the time it was sent.
6. **Given** a deletion-for-everyone event reaches a member who has already viewed the message, **When** the device processes the event, **Then** any in-progress playback or display of the original content stops promptly and the placeholder replaces it; no further access to the original is possible from any in-app surface.

---

### Edge Cases

- What happens if the group photo upload fails? → Group is still created with a placeholder; the photo can be set later from group info.
- What if a member being added to a group blocks the creator? → Assumption: blocked contacts cannot be added to groups; the creator sees an error.
- What if the internet drops while sending a group message? → Same offline queue behavior as 1-to-1 chat; message retries on reconnect.
- What if a user is added to a group while offline? → They receive the group and its full message history when they come back online.
- What if all members leave a group? → The group is automatically dissolved and removed for any remaining member.
- Minimum group size: a group with only 1 member (after others leave) should be dissolved or the last member should be allowed to leave.
- What if recording upload to group chat fails after the call? → The file is still saved to the device gallery/Downloads. The system MUST retry the group-chat send; if all retries fail, the user is notified and can manually share the file from their gallery/recordings list.
- What if the device runs out of storage during recording? → Recording MUST stop automatically with a clear notification; the partial file (if valid) is saved and shared; if the partial file is too short (< 3 s), it is discarded and the user is notified.
- What if a participant's call type (video vs voice) differs from the recording format? → Recording format is determined by the local call stream — if the device is in a voice-only call, the recording is audio even if other participants have video enabled.
- What if the "Join Call" state is stale (call ended while user had the chat screen open)? → The Join Call button MUST disappear within 5 seconds of the call ending (driven by a socket event); tapping a stale button before the update shows a "Call has ended" toast.
- What if a sender deletes a message for everyone but a recipient's device is offline for many days? → On next sync, the deletion is applied BEFORE the original content is shown to that recipient. If the recipient happened to view the message via a partial pre-sync cache, the local store is purged on sync and the placeholder appears.
- What if a recipient is in mid-playback of a video or voice message when "Delete for Everyone" arrives? → Active playback is allowed to complete the current frame/segment but no further reads of the cached file are permitted; once playback ends or the user navigates away, the file is purged and the placeholder appears.
- What if a left/removed member's device emits a queued action (e.g., a pending send) after the leave/removal completes? → The backend MUST reject the action with an explicit "no longer a participant" error; the client surfaces an in-app toast and drops the queued action.
- What if the network is briefly available and the backend forwards an event to a recently-left member before the membership index updates? → The member's device MUST recognize the stale event and discard it locally (defense-in-depth against backend-side race conditions).

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
- **FR-018a**: The group info screen MUST include a "Shared Media" section that displays all media items (images, videos, voice notes, and call-recording media messages) that have been shared in the group's message history. The section MUST be visible to every group member regardless of role; admin status is irrelevant for viewing.
- **FR-018b**: The Shared Media section MUST match the visual layout and interactions of the equivalent section on the existing 1-to-1 chat info screen — same grouping (e.g., by media type and/or date), same thumbnail size, same tap-to-open behavior, same scroll affordance. Differences between 1-to-1 and group MUST be limited to the data set being rendered.
- **FR-018c**: Tapping a media thumbnail in the Shared Media section MUST open the same full-size viewer that opens when the same media is tapped from inside the chat thread (image viewer, video player, voice-note player, call-recording player as applicable).
- **FR-018d**: The Shared Media section MUST exclude any message that has been retracted via "Delete for Everyone" (US7). When a retraction event arrives, any corresponding media item already rendered in the Shared Media section MUST be removed within the same propagation window defined by FR-040.
- **FR-018e**: The Shared Media section MUST NOT block the rest of the group info screen from being interactive while it loads. Member list, group name, group photo, and admin actions MUST be operable immediately when the screen opens, even before the media grid finishes populating.
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

**Group Call Recording**

- **FR-032**: Any participant in an active group call MUST be able to start a recording from their own device.
- **FR-032a**: The recording format MUST automatically match the call type — a video call produces a video recording (MP4 or MOV); a voice-only call produces an audio-only recording (M4A or AAC). The participant MUST NOT need to manually select a format.
- **FR-033**: When a participant starts recording, a clear, persistent visual indicator (e.g., a red "REC" badge or banner) MUST be displayed to **all** participants on the call so everyone is aware recording is in progress.
- **FR-034**: When a participant stops recording (or the call ends), the visual indicator MUST disappear immediately for all participants.
- **FR-035**: When a recording is stopped (or the call ends while recording), the recorder's device MUST automatically: (a) save the file to the device gallery (Photos app on iOS, Gallery on Android) for video recordings, or to the Downloads / Files folder for voice recordings; AND (b) send the recording as a media message in the group's chat thread so that all current group members can access and download it. The system MUST NOT require the recorder to manually share the file.
- **FR-036**: All current group members MUST be able to access recordings shared via group chat messages — they can view, download, and save recordings from within the chat. The recorder MUST additionally be able to manage (play back, rename, delete) their own recordings from a dedicated recordings list within the app.
- **FR-037**: Recording start/stop events MUST be logged locally on the recorder's device for the recorder's own reference, but MUST NOT be persisted in the group's chat history as system messages. (The recording file itself sent as a media message per FR-035 is not a "recording event".)
- **FR-038**: A "Join Call" action MUST be displayed in the group chat screen header (AppBar) if and only if a group call is actively in progress for that group at the time the screen is viewed. When no call is active, the action MUST NOT be visible. Tapping it joins the ongoing call.

**Delete for Everyone (Group Propagation)**

- **FR-039**: The sender of a group message MUST be able to choose "Delete for Everyone" on any message they sent within the retraction window. The default retraction window is **1 hour** from the original send timestamp. Beyond that window, only "Delete for me" is available.
- **FR-040**: When "Delete for Everyone" is initiated for a group message, every current group member's device MUST replace the original message content (text and/or media reference) with a deletion placeholder ("This message was deleted") within **3 seconds** for online members, and on next sync before display for offline members.
- **FR-041**: When "Delete for Everyone" succeeds, every current member's local copy MUST be purged of the original content — including the original text, the cached media file (image/video/voice), and any thumbnails or transcripts derived from the original. The original content MUST NOT be retrievable on any current member's device via the conversation list, the message search, the media gallery, or any other in-app surface.
- **FR-041a**: Delete-for-Everyone events MUST also clear the message from any push-notification preview, lock-screen surface, or notification-center entry that was generated by the original message, on every receiving device where such a notification is still visible.
- **FR-041b**: A Delete-for-Everyone event MUST be idempotent on receivers: if the same delete event is delivered more than once (e.g., via socket and via REST sync), the second and subsequent applications MUST be no-ops, and MUST NOT regress the placeholder to the original content.

**Post-Leave / Removal Enforcement**

- **FR-042**: When a member leaves the group voluntarily (FR-019) or is removed by the admin (FR-017), the backend MUST atomically update the group's participant index BEFORE returning success to the leave/remove request. Subsequent message sends, message receives, call initiations, group info reads, and group info edits by the leaver/removed member MUST be rejected by the backend with an explicit "no longer a participant" error.
- **FR-043**: After a member leaves or is removed, the backend MUST NOT forward any further socket events (`newMessage`, `messageDelivered`, `messageRead`, `userTyping`, group-call events, recording events, etc.) for that group to that user, and MUST NOT include the group's data in any subsequent REST responses to that user.
- **FR-044**: The leaver/removed member's device MUST reject any stale socket events or push notifications for that group received after the local leave/removal state has been applied. Defense-in-depth: even if backend race conditions allow one stray event through, the client discards it.
- **FR-045**: The leaver/removed member's local conversations list MUST display the group in read-only mode (per FR-029, FR-030) — historical messages are visible, but the message input, call buttons, and group info edit affordances MUST be completely absent or disabled. Any tap on a disabled affordance MUST surface a clear "You are no longer a participant" notice.

### Key Entities

- **Group**: Represents a multi-member conversation. Attributes: unique ID, name (required), photo (optional), list of members, designated admin, creation timestamp.
- **Group Member**: A user participating in a group. Attributes: user reference, role (Admin or Member), join timestamp.
- **Group Message**: A message within a group context. Same structure as a 1-to-1 message plus: sender identity (always visible to recipients), per-member delivery/read tracking, retraction state (active vs. deleted-for-everyone).
- **Admin Role**: A special role held by exactly one member at a time, granting permissions to edit group details and manage membership.
- **Message Retraction**: A state on a Group Message indicating it has been deleted for everyone by the sender. Carries the timestamp of the retraction; replaces the original content on every current member's device. Once set, cannot be undone.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can create a group with a name and at least one member in under 60 seconds from first tap to group appearing in conversations.
- **SC-002**: Group messages from any member appear for all other online members within 2 seconds of being sent under normal network conditions.
- **SC-003**: Sender names on group messages are visible without any additional tap or interaction — zero extra steps vs 1-to-1 UX.
- **SC-004**: Removing a member from a group takes effect immediately; the removed member loses access within 5 seconds on their device.
- **SC-005**: 100% of 1-to-1 chat scenarios that worked before this feature ships continue to pass without any regression.
- **SC-006**: Group info changes (name, photo) propagate to all active group members' screens within 3 seconds.
- **SC-006a**: The Shared Media section of the group info screen opens and shows at least the first viewport of media thumbnails within 1 second of the screen becoming visible, on mid-range devices, for groups with up to 500 historical media items.
- **SC-006b**: A media item retracted via "Delete for Everyone" disappears from the Shared Media section on every current member's group info screen within the FR-040 propagation window (3 s for online, on next sync for offline).
- **SC-007**: A completed call recording appears as a media message in the group chat and is accessible to all group members within 30 seconds of the recording being stopped.
- **SC-008**: The "Join Call" button appears in (or disappears from) the group chat screen within 5 seconds of a call starting or ending.
- **SC-009**: A "Delete for Everyone" issued by the sender results in the original message disappearing for 100% of currently-online recipients within 3 seconds, and for offline recipients on next sync before any display of the original. Measured by an automated 100-iteration regression on a 3-device group.
- **SC-010**: After a member leaves or is removed from a group, across a 100-iteration regression test: 0 messages can be sent by that member to that group, 0 new messages are received by that member from that group, and 0 stale socket events for that group are accepted by that member's device.
- **SC-011**: Push-notification entries for messages that are subsequently deleted-for-everyone are cleared from the receivers' notification surfaces within 5 seconds of the deletion arriving on the device (where the device's OS supports notification update or removal).

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
- Call recording captures the local device stream. Format is determined automatically by the call type (video → MP4/MOV, voice → M4A/AAC); no manual format selection is exposed to the user.
- Recordings are shared with all current group members via the group chat thread as a standard media message. This requires the recording file to be uploaded to the existing media infrastructure after capture. Server-side storage costs apply only for the sharing upload — the recording itself is captured on-device.
- Recording upload and sharing follow the same retry and offline-queue behavior as other media messages.
- Recording consent is satisfied by the universal in-call REC indicator (FR-033); jurisdictions requiring explicit prior consent (one-party vs. two-party consent laws) are addressed by the visible indicator — additional jurisdiction-specific consent prompts are out of scope for v1.
- The "Join Call" button state is driven by socket events that the backend broadcasts when a call starts or ends for that group room.
- The app already has a 1-to-1 "Delete for Everyone" mechanism (message-retraction event, deletion placeholder UI, local media-cache cleanup). This feature extends that mechanism to fan out across all current group members; no new retraction primitives are introduced.
- The retraction window default of 1 hour matches the existing 1-to-1 retraction window. If the existing 1-to-1 window differs, the group window MUST be set to the same value to avoid inconsistent behavior across chat types.
- Backend authority over membership is absolute. The leave/remove API call returns success only after the participant index has been atomically updated and all in-flight socket subscriptions for the leaver have been torn down. This is the foundation of FR-042 to FR-045.
- Push-notification clearing on Delete-for-Everyone is best-effort and OS-dependent. Where the OS does not allow remote notification removal, the device-side handler clears the notification once the app foregrounds.
- The existing 1-to-1 chat info screen already provides a "Shared Media" section backed by a query of the local SQLite messages store filtered by media type. The group info "Shared Media" section reuses the same widget tree and the same query, parameterised by `chatRoomId`. No new server endpoints are needed; the data is already in SQLite by virtue of normal message sync.
