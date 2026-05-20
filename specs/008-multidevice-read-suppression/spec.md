# Feature Specification: Multi-Device Read Suppression

**Feature Branch**: `008-multidevice-read-suppression`
**Created**: 2026-05-19
**Status**: Draft
**Input**: User description: "in chatRoom if i stay open chatRoom on 2 devices if i sent a message from 1 message don't mark a read until exist to home page and open chat again"

## Clarifications

### Session 2026-05-19

- Q: How long does a single "deliberate open" remain active on a device? → A: Until EITHER the user navigates away from the chat screen OR the app is backgrounded/locked. Resuming from background with the chat still on top does NOT auto-read newly arrived messages; a fresh deliberate-open (leave and return) is required.
- Q: Where does the deliberate-open gating live? → A: On the device. The client gates the emission of its own read acknowledgement on the local deliberate-open flag. The backend's read-tracking semantics are unchanged: it continues to count reads per user (any one of a user's devices satisfying the rule is enough).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read state is gated by an intentional re-open (Priority: P1)

A user is signed in to the same account on two devices (e.g., phone and tablet). The user has the same conversation screen visible on both devices simultaneously. The user sends a message from Device A. The message MUST NOT be marked as "read" on Device B simply because the conversation screen is on display there — the user has not actively returned to the conversation. Only after the user navigates away from the conversation on Device B (back to the conversations list / home) and then re-opens that conversation does Device B contribute its "read" acknowledgement to the sender's read receipts.

**Why this priority**: Sender read receipts today incorrectly turn blue the moment the second device emits a read event, even though the user did not actively view the message on that device. This misrepresents whether the recipient actually saw the message and is the entire motivation for the feature. Without this fix the read-receipt signal becomes unreliable for any user with multiple active devices, which is increasingly common.

**Independent Test**: Sign the same user into two devices, open the same chat on both, send a message from the first device. Verify on the sender's UI that the message status remains "delivered" (not "read") until the user manually navigates away on the second device and re-enters the chat.

**Acceptance Scenarios**:

1. **Given** User U is signed in on Device A and Device B and has Chat C open on both, **When** U sends a message from Device A, **Then** the message status seen by U on Device A advances to "delivered" but does NOT advance to "read" because of Device B's continued visibility of Chat C alone.
2. **Given** the same state as scenario 1 after the send, **When** U navigates from Chat C to the conversations list on Device B and then re-opens Chat C, **Then** Device B emits a "read" acknowledgement for that message and the sender's UI on Device A advances the status to "read" within 2 seconds.
3. **Given** U is signed in on Device A only and has Chat C open, **When** another user sends a message to Chat C, **Then** the message is marked "read" on Device A immediately (single-device behavior is unchanged).
4. **Given** U is signed in on Device A and Device B with Chat C closed on both, **When** another user sends a message to Chat C, **Then** the message is NOT auto-marked "read" on either device until U deliberately opens Chat C (single-device or multi-device, behavior is consistent).
5. **Given** a group chat where U participates with two devices, **When** another member sends a message and U's Chat C is open on both U's devices, **Then** U is counted as "read" only after the deliberate-open requirement is satisfied by U on at least one of U's devices; group-level "all-read" gating is unchanged otherwise.

---

### User Story 2 - Deliberate-open detection survives backgrounding (Priority: P2)

The "deliberate open" requirement must not be defeated by app backgrounding, screen lock, or transient navigation events that the user did not initiate as a return to the conversation. A device that had the chat screen open, was backgrounded for an arbitrary period, and then resumed with the same chat screen still on top, has NOT had a deliberate re-open and MUST NOT auto-mark messages as read on resume.

**Why this priority**: Without this rule, users would observe the bug reappear whenever they lock the phone with the chat open and unlock it later; the system would treat resume-from-background as a fresh open and mark everything read. That undermines the whole feature.

**Independent Test**: With the chat open on Device B, lock the device for 30 seconds, unlock it. Confirm Device B did NOT emit a "read" acknowledgement for any messages received while locked.

**Acceptance Scenarios**:

1. **Given** Chat C is open on Device B and one new message arrives while the device is locked, **When** the user unlocks the device and the chat screen is restored, **Then** Device B does NOT auto-mark the new message as read; the message remains in the unread state on the sender's UI.
2. **Given** Chat C is open on Device B, **When** the user switches to another app and then returns to Ciro with Chat C still visible, **Then** the same suppression applies — no auto-read on resume.
3. **Given** Chat C is open on Device B and the user explicitly navigates to the conversations list and back into Chat C, **Then** auto-read IS triggered for any unread messages.

---

### Edge Cases

- The user has three or more devices: each device independently must satisfy the deliberate-open rule before its read contribution counts. There is no "any device counts" shortcut.
- The user kills the app on a device while Chat C is open and re-launches the app directly into Chat C (deep link or last-screen restoration): launching the chat from a cold start counts as a deliberate open and DOES auto-mark unread messages.
- The user receives a push notification and taps it to open Chat C: this counts as a deliberate open and DOES auto-mark.
- Network failure while emitting the read acknowledgement: the device retries when reconnected, same as the existing read-receipt retry behavior; the deliberate-open intent is preserved across reconnects.
- A device that has been continuously showing Chat C for hours never auto-reads anything in that window. The user must explicitly leave and return.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST distinguish "the chat is visible on a device" from "the user deliberately opened the chat on that device". Only the second condition triggers an auto-mark-as-read on that device.
- **FR-002**: A "deliberate open" event MUST be defined as one of: (a) navigating into the chat screen from the conversations list, (b) opening the app from a cold start directly into the chat, (c) tapping a push notification that lands on the chat, or (d) returning to the chat via deep link from outside the app. Resuming the app from background with the chat already visible does NOT count.
- **FR-003**: When the user sends a message from one of their devices, none of the user's other devices that happen to have the chat open MUST contribute a "read" acknowledgement for that message based solely on visibility.
- **FR-004**: Each of a user's devices MUST independently satisfy the deliberate-open requirement before contributing its read acknowledgement; there is no global "user has read on any device" shortcut.
- **FR-005**: The behavior described in FR-001 to FR-004 MUST apply to both 1-to-1 chats and group chats.
- **FR-006**: For group chats, the existing rule that a message turns fully "read" only when every other member is counted as having read MUST be preserved. A given member is counted as having read once any one of that member's devices has emitted a read acknowledgement (under the deliberate-open rule).
- **FR-007**: The "delivered" status MUST be unaffected by this feature. A message reaches "delivered" the moment any of the recipient user's devices receives it, regardless of visibility or deliberate open.
- **FR-008**: When a device that previously suppressed an auto-read later satisfies a deliberate open, it MUST emit a "read" acknowledgement for ALL messages that were received during the suppression window for the conversation, in one batched update — the sender MUST see those messages turn blue together.
- **FR-009**: Read acknowledgements MUST continue to be delivered to the sender in real time (target latency unchanged from existing 1-to-1 / group read behavior).
- **FR-010**: This change MUST NOT affect single-device users in any observable way: if a user has only one active device, every existing read-receipt behavior continues unchanged.
- **FR-011**: Cold-start app launches that land in a chat (last-screen restoration, deep link, push tap) MUST count as a deliberate open.
- **FR-012**: A device's "deliberate-open" flag for a conversation MUST be cleared on EITHER of the following events: (a) the user navigates away from the chat screen (back to conversations list, opening a different chat, opening any other top-level screen), OR (b) the app is backgrounded or the device is locked. After clearance, the flag MUST only be re-established by a new deliberate-open action as defined in FR-002 (foreground navigation into the chat, cold start landing in the chat, push tap, or deep link). Resuming the app from background or unlocking the device with the chat screen still mounted MUST NOT, on its own, re-establish the flag.
- **FR-013**: The deliberate-open gating MUST be enforced on the user's own device, at the point where a read acknowledgement would otherwise be emitted to the rest of the system. The system's broader read-tracking semantics (per-user counting, sender-visible status progression, group all-members-read aggregation) MUST remain unchanged; only the trigger for a device to emit its own read acknowledgement is gated by this feature.

### Key Entities *(include if feature involves data)*

- **Device Session**: Represents one device's active sign-in to the user's account. Each device session independently tracks whether the user currently has any chat "deliberately open" on this device and, if so, which conversation.
- **Read Acknowledgement**: An event sent from a device session to the backend stating that a specific message (or batch) has been read by the user on that device. Read acknowledgements are gated by FR-001 to FR-004.
- **Conversation Open State** (per device): Boolean state per (device, conversation) — true when the user is currently in that conversation AND arrived via a deliberate open. False when the conversation is not visible, or visible-but-not-deliberately-opened (e.g., visible because the app resumed from background while the screen was still on it).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When a user is signed in on two devices with the same chat open on both, a message sent from device A is observed in "delivered" (not "read") state on the sender's UI for at least as long as device B has not been deliberately re-opened.
- **SC-002**: After a deliberate re-open on device B, the sender's UI advances the message from "delivered" to "read" within 2 seconds (matching today's read-receipt latency target).
- **SC-003**: 100% of single-device users see identical read-receipt timing as before this feature; no regression.
- **SC-004**: Across a 7-day pilot, sender-visible read-receipt accuracy (the message is marked read only when the recipient has actually deliberately viewed it) is at least 95%, measured by a user survey or telemetry sampling.
- **SC-005**: Backgrounding the app and unlocking does not trigger any auto-read emission on the resuming device in 100% of cases, verified by an automated UI test.

## Assumptions

- Multi-device sessions exist today: a user can sign in on multiple devices simultaneously and each device maintains its own socket connection and local message store.
- The backend's existing read-tracking model is per-user (not per-device). This feature does NOT introduce per-device read state on the backend; the gating happens at the source (each user's device) before any read acknowledgement is emitted.
- "Deliberate open" is an app-level concept; the operating system does not provide a direct API for it. The app must derive it from navigation events and lifecycle transitions.
- The existing 1-to-1 read-receipt protocol and the group read-receipt protocol (member-count gating) are unchanged — only the trigger for emitting a read acknowledgement changes.
- This feature has no impact on read receipts that are explicitly toggled off by a user preference, if such a preference exists or is introduced later.
- Telemetry to verify SC-004 may need to be added; if so, it is collected anonymously and used only for product validation.
