# Feature Specification: Status Feature Backend & Logic Integration

**Feature Branch**: `014-status-feature-integration`
**Created**: June 10, 2026
**Status**: Draft
**Input**: User description: "i need you analyze status feature and i need you create status feature in back end and logic only in front"

## Clarifications

### Session 2026-06-10

- Q: The original draft included a "Generate an AI Image for a Status" user story and related requirements, but no AI image generation service exists anywhere in the backend today. Should building that integration be in scope for this feature? → A: Out of scope - remove AI image generation from this spec; it becomes its own future feature, and the "AI Image" creation option remains unavailable until that exists.
- Q: The existing chat module serves uploaded media as unauthenticated static files (`/uploads/<uuid>.<ext>`), relying only on an unguessable filename. Should "Private" status media follow that same pattern, or be stricter? → A: Stricter - status media (images, video, voice) MUST be served via access-controlled (e.g., signed/expiring or authenticated) URLs so only users permitted to view the status can retrieve the media, even if the URL becomes known.
- Q: When a viewer sends a text reply to a status, should it become a real message in the existing 1:1 chat conversation with the author (requiring the chat message model to support a status reference), or a separate status-only notification outside chat history? → A: Real chat message - status replies are appended to the author/viewer's existing 1:1 conversation, tagged with a reference back to the source status.
- Q: How should the system prevent duplicate status posts when an offline-queued status is retried after connectivity is restored? → A: Reuse the existing chat message pattern - each status carries a client-generated unique ID at creation time, and the server deduplicates retried submissions by that ID (mirroring `clientMessageId` for chat messages).
- Q: Should a "Private" status audience be selected fresh every time, or should the system remember a default audience between posts? → A: Persisted default - the system stores the user's most recently selected "Private" audience and pre-selects it for new Private statuses, while still allowing per-post edits.
- Q: What does "Public" visibility mean - all of the author's contacts, or something narrower? → A: Mutual contacts only (WhatsApp-style): a "Public" status is visible only to users who have the author's number saved AND whose number the author also has saved. It is never visible to one-directional contacts or unrelated platform users. This requires the system to persist each user's synced contact list so mutuality can be evaluated.

## User Scenarios & Testing *(mandatory)*

<!--
  Context: The Status (ephemeral "stories") screens, editors, and viewers already
  exist on the client (specs 004-status-updates and 005-status-creation-flow) but
  are backed by local storage and mocked network calls only. This feature adds the
  missing server-side capability and connects the existing client screens to it
  via the underlying data/business logic. No new screens or visual changes are in
  scope - only the logic that makes the existing screens functional end-to-end.
-->

### User Story 1 - Post a Status That Contacts Can See (Priority: P1)

A user creates a status (text, photo, video, or voice) using the existing creation screens. Once they tap "Done"/send, the status is saved by the system and becomes visible to the appropriate contacts, not just on the author's own device.

**Why this priority**: Without server-side persistence and delivery, a posted status only exists on the author's device and nobody else can see it - the entire feature is non-functional without this.

**Independent Test**: Post a text status as User A, then sign in as User B (a mutual contact of User A - each has the other's number saved) and verify the status appears in User B's Updates feed.

**Acceptance Scenarios**:

1. **Given** User A composes a text, image, video, or voice status and confirms posting, **When** the system processes the post, **Then** the status is stored centrally with its content, author, creation time, and a 24-hour expiration time.
2. **Given** User A's status has "Public" privacy, **When** the post completes, **Then** every user who is a mutual contact of User A (User A has their number saved AND they have User A's number saved) can retrieve and view the status, and no one else can.
3. **Given** User A has no network connection when posting, **When** connectivity is restored, **Then** the status is automatically submitted without the user needing to repost it, and without creating duplicates.

---

### User Story 2 - View Contacts' Statuses in Real Time (Priority: P1)

A user opens the Updates screen and sees recent statuses posted by their contacts, including ones posted moments ago, without needing to manually refresh.

**Why this priority**: Consuming contacts' statuses is the core value of the feature; it must reflect the real, shared state rather than only what happens to be cached locally.

**Independent Test**: While User B has the Updates screen open, User A posts a new status; verify it appears in User B's "Recent status" section within seconds without User B restarting the app.

**Acceptance Scenarios**:

1. **Given** User B opens the Updates screen, **When** the screen loads, **Then** it shows the current, non-expired statuses from User B's contacts that User B has not yet viewed, merged correctly with anything already cached on the device.
2. **Given** User B is viewing the Updates screen, **When** a contact posts a new status that User B is permitted to see, **Then** it appears in User B's "Recent status" section without requiring a manual refresh.
3. **Given** User B has previously viewed a status, **When** User B reopens the Updates screen, **Then** that status appears in "Status that were presented" rather than "Recent status", consistent with the server-recorded view.

---

### User Story 3 - Statuses Expire After 24 Hours for Everyone (Priority: P1)

Statuses automatically stop being visible to anyone, including the author, exactly 24 hours after they were posted.

**Why this priority**: Ephemerality is a defining characteristic of the feature; without enforcement on the server, expired content would remain visible to other users even after it disappears from the author's device.

**Independent Test**: Post a status, then simulate the passage of 24 hours; verify the status no longer appears in any contact's feed and can no longer be retrieved or viewed by anyone.

**Acceptance Scenarios**:

1. **Given** a status was posted more than 24 hours ago, **When** any user requests their Updates feed, **Then** that status is not included.
2. **Given** a status reaches its 24-hour expiration, **When** the expiration occurs, **Then** the status and its associated views, reactions, and replies are no longer accessible to any user.

---

### User Story 4 - Author Sees Who Viewed Their Status (Priority: P2)

A user who posted a status can see which of their contacts have viewed it and when.

**Why this priority**: Knowing who viewed a status is a core engagement signal in status/story features, but the feature is still usable end-to-end without it (P1 stories deliver an MVP).

**Independent Test**: User B views User A's status; verify User A can subsequently see User B listed as a viewer with a view timestamp.

**Acceptance Scenarios**:

1. **Given** User B views User A's status, **When** the view is recorded, **Then** User A can retrieve a list of viewers for that status including User B and the time of the view.
2. **Given** User A is online when User B views their status, **When** the view occurs, **Then** User A is notified in real time that a new view has been recorded.

---

### User Story 5 - React To and Reply To a Status (Priority: P2)

While viewing a contact's status, a user can send a quick reaction or type a text reply, which the status author receives.

**Why this priority**: Reactions and replies add engagement on top of the core view/post flows but are not required for a minimally viable status feature.

**Independent Test**: User B sends a reaction and a text reply while viewing User A's status; verify User A receives both, with sender identity and the related status referenced.

**Acceptance Scenarios**:

1. **Given** User B is viewing User A's status, **When** User B sends a reaction, **Then** the system records the reaction and delivers it to User A in real time if User A is online.
2. **Given** User B is viewing User A's status, **When** User B types and sends a reply message, **Then** the system delivers the reply to User A as a message referencing the original status.

---

### User Story 6 - Control Who Can See a Status (Priority: P2)

When posting a status, a user chooses whether it is visible to all of their mutual contacts ("Public"), only to specific mutual contacts they select ("Private", pre-filled with their saved default audience), or shown on the map to nearby/permitted contacts ("Show on Map"), and the system enforces that choice.

**Why this priority**: Privacy controls are important for user trust, but the feature can launch with "Public" as the default behavior covered by User Stories 1-3 while this enforcement is completed.

**Independent Test**: User A posts a status with "Private" visibility limited to User B only; verify User C (also a mutual contact of User A, but not selected) cannot retrieve or view that status, while User B can. Then verify User A's next "Private" status pre-selects User B as the default audience.

**Acceptance Scenarios**:

1. **Given** User A selects "Private" and chooses a subset of mutual contacts when posting, **When** the status is published, **Then** only the author and the selected contacts can retrieve or view it, and that selection is saved as User A's default "Private" audience.
2. **Given** User A previously posted a "Private" status to a saved default audience, **When** User A starts creating a new "Private" status, **Then** that default audience is pre-selected, and User A may edit it before publishing.
3. **Given** User A selects "Show on Map" when posting, **When** the status is published, **Then** it is visible to User A's mutual contacts in the Updates feed exactly as a "Public" status would be, **and** it is additionally made available through the map-based status view to the contacts permitted to see User A's shared location.
4. **Given** a contact is not part of a "Private" status's selected audience, **When** that contact requests their Updates feed or attempts to open the status directly, **Then** the status is not returned to them.
5. **Given** User A and User C have a one-directional contact relationship (only one of them has the other's number saved), **When** User A posts a "Public" status, **Then** User C cannot retrieve or view it.

---

### Edge Cases

- What happens if a user is removed from a "Private" status's audience after they have already started viewing it (e.g., mid-viewing session)?
- What happens if a user posts a status while offline and then goes offline again before the queued post can sync - is the pending post preserved across app restarts?
- What happens if two devices belonging to the same user mark the same status as viewed at nearly the same time - is the view recorded once or twice?
- How does the system behave if a status's media upload fails partway through (e.g., large video over a poor connection)?
- What happens to a status, and its views/reactions/replies, exactly at the moment it crosses the 24-hour expiration boundary while a user has it open?
- What happens to "Public" status visibility if one party in a mutual-contact relationship deletes the other's number from their contacts (relationship becomes one-directional) while the status is still active?
- What happens if a user disables location sharing after posting a "Show on Map" status - does the status remain visible on the map for its remaining lifetime or is it hidden immediately?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow an authenticated user to create a status post of type text, image, video, or voice recording, optionally including a caption, background color, font style, and a reference to an attached music track.
- **FR-002**: System MUST persist each created status centrally with its author, content, a client-generated unique identifier, creation time, and an expiration time set to exactly 24 hours after creation. Resubmitting a status with a client-generated identifier that already exists MUST NOT create a duplicate status.
- **FR-003**: System MUST make a newly created status retrievable by, and deliver it in real time to, the contacts permitted to view it based on its privacy setting.
- **FR-004**: System MUST support three status privacy settings - "Public" (visible only to the author's **mutual contacts**, see FR-005), "Private" (visible only to an author-selected subset of mutual contacts), and "Show on Map" (visible to the author's mutual contacts in the Updates feed, identically to "Public", **and additionally** visible via the map-based status view to contacts permitted to see the author's location, per User Story 6 acceptance scenario 3).
- **FR-005**: System MUST define two users as "mutual contacts" only when each has the other's phone number saved in their own synced contact list (i.e., User A has User B's number, AND User B has User A's number). The system MUST persist each user's synced contact list (phone numbers) centrally so this mutual relationship can be evaluated at status-delivery and retrieval time. A "Public" status MUST NOT be visible to a user who is only a one-directional contact of the author or who has no contact relationship with the author at all.
- **FR-006**: System MUST enforce that a "Private" status is retrievable only by its author and the explicitly selected contacts, for both real-time delivery and any retrieval before expiration.
- **FR-007**: System MUST serve status media (images, video, voice recordings) via access-controlled URLs (e.g., signed/expiring links or an authenticated media endpoint) such that only users permitted to view the status under FR-004/FR-005/FR-006 can retrieve the underlying media file, even if the URL becomes known to others.
- **FR-008**: System MUST make a status, along with its recorded views, reactions, and replies, permanently inaccessible to all users exactly 24 hours after its creation time.
- **FR-009**: System MUST record each instance of a contact viewing a status, including the viewer's identity and the time of the view, and make this list retrievable by the status's author.
- **FR-010**: System MUST notify a status author in real time when a new view, reaction, or reply is recorded on their status, while the author is online.
- **FR-011**: System MUST allow a viewer to send a reaction to a status, recorded and delivered to the status's author with a reference to the original status.
- **FR-012**: System MUST allow a viewer to send a text reply to a status by appending a message to the existing 1:1 conversation between the viewer and the status's author, tagged with a reference to the source status so the author can identify which status was replied to.
- **FR-013**: System MUST persist, per user, a default "Private" status audience (the set of mutual contacts most recently selected for a Private status), update it whenever the user changes the selection, and make it available to pre-fill future Private statuses.
- **FR-014**: Client status-feed logic MUST combine statuses already cached on the device with statuses retrieved from or pushed by the server into a single, de-duplicated, recency-ordered feed, without requiring changes to the existing Updates screen UI.
- **FR-015**: Client logic MUST submit a "viewed" record to the server when a user views a status, and MUST move that status from "Recent status" to "Status that were presented" based on the server-confirmed view state.
- **FR-016**: Client logic MUST queue a status created while offline, assigning it a client-generated unique identifier (per FR-002) at creation time, and automatically submit it once connectivity is restored without producing duplicate posts on the server.
- **FR-017**: Client logic for the "Private (select contacts)" privacy option MUST be backed by the user's actual mutual-contact list (FR-005), MUST pre-select the user's persisted default audience (FR-013) when starting a new Private status, and MUST submit the (possibly edited) selected audience to the server with the status, updating the persisted default.
- **FR-018**: Client logic MUST submit reactions entered through the existing status viewer to the server, and MUST submit text replies via the existing chat send logic per FR-012, reflecting delivery success or failure to the user.
- **FR-019**: Client logic MUST resolve and use the access-controlled media URLs from FR-007 when displaying status media (e.g., refreshing an expiring link if needed) without requiring changes to the existing status viewer UI.
- **FR-020**: Client local storage MUST remove statuses (and their cached view state) once they pass their 24-hour expiration, consistent with the server-side removal in FR-008.

### Key Entities

- **Status**: An ephemeral post created by a user - text, image, video, or voice - with associated styling (background color, font style), optional caption and music reference, a privacy setting, a creation time, and an expiration time 24 hours later.
- **Status View**: A record that a specific contact viewed a specific status, including the viewer's identity and the time of viewing.
- **Status Reaction**: A record of a quick reaction sent by a viewer in response to a status.
- **Status Reply**: A text message sent by a viewer in response to a status, delivered as a regular message in the existing 1:1 conversation between viewer and author, carrying a reference to the original status.
- **Mutual Contact**: A relationship between two users where each has the other's phone number saved in their own synced contact list. Determines who can see a "Public" status and who is eligible to be selected for a "Private" status's audience.
- **Status Audience**: The set of mutual contacts an author has selected as permitted viewers for a "Private" status; the most recent selection is persisted as the user's default for future Private statuses.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A status posted by a user becomes visible in a permitted contact's feed within 5 seconds under normal connectivity, without the contact needing to refresh manually.
- **SC-002**: 100% of statuses become inaccessible to all users (including the author) exactly 24 hours (plus or minus 1 minute) after their creation time.
- **SC-003**: 0% of "Private" statuses - including their metadata, feed entries, and underlying media files - are retrievable or viewable by contacts who were not part of the selected audience, verified across all retrieval paths (feed, direct view, search, and direct media URL access).
- **SC-004**: A status author sees a new viewer added to their status's viewer list within 5 seconds of that viewer opening the status, while the author is online.
- **SC-005**: Reactions and replies sent by a viewer reach the status author within 5 seconds while the author is online, in 95% of cases.
- **SC-006**: Statuses created while offline are successfully delivered to the server within 30 seconds of connectivity being restored, with zero duplicate posts.
- **SC-007**: Existing Status Updates and Status Creation screens require no visual or layout changes to function with the new server-backed data.
- **SC-008**: 0% of "Public" statuses are visible to users who do not have a mutual contact relationship with the author (i.e., one-directional contacts and unrelated users see none of the author's "Public" statuses).
- **SC-009**: When creating a second or later "Private" status, a user's previously selected audience is pre-filled automatically in 100% of cases, requiring no manual re-selection unless they choose to change it.

## Assumptions

- The existing Updates screen, status creation bottom sheet/editors, and status viewer (specs 004-status-updates and 005-status-creation-flow) are functionally complete from a UI/UX standpoint; this feature only supplies the server-side capability and the underlying logic to connect them, and does not modify their visual design or layout.
- "Mutual contact" status visibility (FR-004/FR-005) requires the system to persist each user's synced contact list (the set of phone numbers from their device address book that the app already looks up). Today the application's contact sync only performs a one-time lookup and does not persist the result, so this feature includes adding that persistence as a foundation for the mutual-contact check; it does not change how contacts are synced from the device.
- Quick reactions use a single, fixed reaction type (consistent with the heart/like icon already present in the status viewer design), not a full emoji picker.
- A status reply reuses the existing chat message data model and delivery path, extended with an optional reference to the originating status; it appears in the author's regular conversation with the viewer rather than a separate inbox.
- "Show on Map" visibility is an additional channel layered on top of the author's location-sharing permissions (as established by the existing map feature), not an independent privacy mechanism with its own audience list.
- AI-generated images for statuses are out of scope for this feature; the "AI Image" option in the status creation flow remains unavailable until a future, dedicated feature adds AI image generation capability to the backend.
- Reactions, replies, and view records associated with a status are removed at the same time the status itself expires, and are not retained afterward.
- Media files (images, videos, voice recordings) attached to statuses are stored centrally and are also removed upon the status's expiration.
- Status media access control (FR-007) is a deliberately stricter mechanism than the existing chat module's unauthenticated `/uploads/<uuid>` file serving, introduced specifically because status privacy settings (Public/Private/Show on Map) require enforceable per-viewer access decisions that a static, unauthenticated URL cannot provide.
- A user's "Private" status audience (FR-013/FR-017) is selected from their mutual contacts; if a contact in the saved default audience later stops being a mutual contact, they are simply omitted from future pre-fills (no error is raised).
- If a user is removed from a "Private" status's selected audience while a viewer's session for that status is already open (Edge Cases), the change is enforced on the *next* retrieval (feed refresh, viewer list, or media request) rather than retroactively revoking an already-open view; FR-006/SC-003 are evaluated per-request against live data, not pushed to active sessions.
- If a status media upload fails partway through (e.g., a large video over a poor connection, Edge Cases), the client marks the queued status as failed (mirroring the existing chat message `pending → error` transition) and offers the user a retry, rather than silently retrying indefinitely or leaving it stuck as "pending".
- Status search (the existing search affordance on the Updates screen) operates as a client-side filter over the same permission-filtered feed described in FR-003/FR-014; it is not a separate retrieval path and is therefore covered by the same "Private"/"Public" visibility enforcement (SC-003/SC-008).
