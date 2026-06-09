# Spec 006 — Chat Lifecycle Hardening · P0 Batch

**Status**: Draft  
**Constitution**: [specs/.specify/constitution.md](../.specify/constitution.md)  
**Audit source**: [docs/chat-lifecycle-audit.md](../../docs/chat-lifecycle-audit.md)  
**Branch**: `006-chat-lifecycle-hardening-p0`  
**Scope**: Exactly P0-A, P0-B, P0-C, P0-D, P0-E. Nothing else.

---

## FR-001 · SQLite Indexes (P0-A · BN-01)

### User Story

As a user with a long message history, I want the chat list and message thread
to load instantly even after months of use, so that the app feels as fast on
day 300 as it did on day 1.

### Acceptance Criteria

**Given** the SQLite `messages` table contains 10,000 rows across multiple rooms  
**When** I open any chat room  
**Then** the first 30 messages render within 100 ms of the screen push (measured from `openRoom` call to first `ChatRoomActive` state emission).

**Given** a new message arrives in a room I am not currently viewing  
**When** the `onNewMessage` handler saves it to SQLite  
**Then** the dedup SELECT (`WHERE client_message_id = ?`) completes in < 5 ms at 10,000 rows (no full-table scan).

**Given** the app is installed for the first time (fresh DB)  
**When** the database is initialised  
**Then** all required indexes are present in `sqlite_master`.

**Given** the app upgrades from DB version 1 to version 2  
**When** `onUpgrade` runs  
**Then** all indexes are created without data loss and the app opens normally.

### Success Metric

Tied to **C-01**: message list first-render p99 < 100 ms at 10 k rows (verified
by integration test with seeded DB).

### Non-Goals

The following BN items are explicitly out of scope for this feature:

- BN-07 (status update waterfall) — deferred to P1-A
- BN-14 (presence update SQLite round-trips) — deferred to P1-E
- Any ORM migration or schema redesign

---

## FR-002 · Push Notifications (P0-B · BN-05)

### User Story

As a user who is not actively looking at the app, I want to receive a push
notification when someone sends me a message, so that I never miss a
conversation because I happened to put my phone down.

### Acceptance Criteria

**Given** my device is registered and the app is in the background  
**When** another user sends me a message  
**Then** a push notification appears on my device within 2 seconds of the
message being sent (C-01 offline budget).

**Given** I tap the notification  
**When** the app opens  
**Then** I am taken directly to the correct chat room with the new message
already visible.

**Given** I receive 5 notifications while my phone is in Do Not Disturb  
**When** I unlock my device  
**Then** notifications are collapsed per conversation (one badge per room, not
one per message).

**Given** the app is completely terminated (not background)  
**When** a push arrives  
**Then** tapping it launches the app and navigates to the correct room.

**Given** my FCM token changes (OS-level rotation)  
**When** the app next launches or foregrounds  
**Then** the new token is sent to the backend and the old one is invalidated
within 24 hours.

### Success Metric

Tied to **C-01**: push notification appears on device within 2 s of `sendMessage`
socket emit, measured on a physical device on a 4G network (manual test protocol
in the tasks file).

### Non-Goals

- APNs (iOS production push) — FCM only at launch. APNs deferred to a follow-on spec.
- Rich media push previews (image thumbnails in notification) — deferred.
- BN-15 (multi-device) — deferred to P2-D.
- BN-16 (E2EE) — deferred to P2-C.

---

## FR-003 · Pagination State Corruption Fix (P0-C · BN-03)

### User Story

As a user reading an old conversation, I want to scroll up to load older
messages and have them stay visible, so that a new incoming message does not
silently erase the history I just loaded.

### Acceptance Criteria

**Given** I have scrolled up and loaded at least 30 older messages (offset ≥ 30)  
**When** a new message arrives in the same room  
**Then** the new message appears at the bottom of the list AND all previously
loaded older messages remain visible — nothing is removed from the list.

**Given** I have scrolled up and loaded 60 older messages (offset = 60)  
**When** a status update arrives (e.g., `messageDelivered`) for any message in the room  
**Then** the status tick updates correctly AND the message count in the list does not drop below 60.

**Given** I open a room for the first time (offset = 0)  
**When** a new message arrives  
**Then** behaviour is identical to today — only the newest 30 messages are shown
(no regression on the default case).

### Success Metric

Zero messages disappear from the visible list during a 5-minute soak test where
a bot sends one message every 10 seconds into a room where the tester has
scrolled back 60 messages.

### Non-Goals

- Cursor-based REST pagination (BN-11 / P1-D) — deferred.
- Inbox LIMIT 20 cap (BN-12 / P2-F) — deferred.

---

## FR-004 · Offline Message Recovery on Reconnect (P0-D · BN-06)

### User Story

As a user who loses network for a period of time, I want the app to automatically
fetch any messages I missed while offline when my connection returns, so that
conversations are complete and in order without me needing to manually refresh.

### Acceptance Criteria

**Given** User A sends 5 messages to User B while User B is offline  
**When** User B's device reconnects to the internet  
**Then** within 3 seconds of reconnection, all 5 messages appear in User B's
chat room in the correct order.

**Given** User B was offline for 2 hours and multiple senders sent messages  
**When** User B reconnects  
**Then** every room that received messages during the offline period shows the
correct unread count and the latest message preview in the chat list.

**Given** User B reconnects and the recovery fetch is in progress  
**When** a new real-time message arrives via WebSocket simultaneously  
**Then** no message is duplicated (idempotency preserved — C-02).

**Given** the recovery fetch fails (server unreachable)  
**When** the network becomes available  
**Then** the fetch retries automatically without user action.

### Success Metric

100% of messages sent during a 5-minute simulated offline window appear in the
correct room within 3 s of reconnection (manual protocol in tasks file). Zero
duplicates observed.

### Non-Goals

- Server-side message replay on socket reconnect — not in scope; client pulls via REST.
- Syncing messages from rooms the user was not a participant of — not applicable.
- BN-07 (batch status updates on reconnect) — deferred to P1-A.

---

## FR-005 · Delete-For-Everyone Backend Handler (P0-E · BN-20)

### User Story

As a sender who sent a message by mistake, I want to delete it for everyone in
the conversation, so that the incorrect message disappears from all recipients'
screens and is not stored in anyone's chat history.

### Acceptance Criteria

**Given** I sent a message less than [configurable window] ago  
**When** I trigger "Delete for everyone"  
**Then** the message is replaced by a tombstone ("This message was deleted") on
my screen immediately (optimistic, C-03).

**Given** the delete request reaches the server  
**When** the server processes it  
**Then** (a) the message's `isDeleted` field is set to `true` in MongoDB,
(b) the message content is cleared, and (c) a `messageDeleted` event is emitted
to all room participants including the sender.

**Given** a recipient is online when the delete is processed  
**When** `messageDeleted` arrives  
**Then** the message bubble is replaced by the tombstone within 500 ms (C-01).

**Given** a recipient is offline when the delete is processed  
**When** the recipient reconnects and loads the room  
**Then** the message renders as a tombstone (server returns `isDeleted: true`).

**Given** someone who is not the original sender sends a `deleteForEveryone`  
**When** the server receives the event  
**Then** the server rejects it (permission check) and the message is unchanged.

### Success Metric

End-to-end delete round-trip (sender tap → recipient tombstone visible) < 500 ms
online (C-01). `isDeleted: true` persisted in MongoDB confirmed by direct DB
check in integration test.

### Non-Goals

- "Delete for me only" (local soft-delete) — deferred.
- Delete time-window enforcement (e.g., 2-hour WhatsApp rule) — the window
  value is configurable via a constant; the business decision on its value
  is deferred to product.
- BN-16 (E2EE, which would require deleting encryption keys too) — deferred to P2-C.
- Push notification for the delete event — deferred.

---

## Deferred BN Items (explicitly out of scope for this spec)

| BN | Title | Deferred to |
|----|-------|------------|
| BN-02 | O(N) writes on room open | P1-A |
| BN-04 | Media upload blocks send | P1-B |
| BN-07 | Status update waterfall | P1-A |
| BN-08 | Video thumbnail on main thread | P1-C |
| BN-09 | JSON over WebSocket | P2-A |
| BN-10 | Message ordering by client clock | P3-B |
| BN-11 | fetchRoomMessages no pagination | P1-D |
| BN-12 | Inbox capped at 20 rooms | P2-F |
| BN-13 | Duplicate typing timers | P2-G |
| BN-14 | Presence SQLite round-trips | P1-E |
| BN-15 | No multi-device support | P2-D |
| BN-16 | No encryption | P2-C |
| BN-18 | receiveMessage dead code | P2 cleanup |
| BN-19 | userStatus never broadcast | P1-F |

---

*No implementation details in this file. Tech choices belong in plan.md.*
