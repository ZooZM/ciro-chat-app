# Socket Contract: Group Chat + Group Calls + Recording

**Phase 1 output** | Generated: 2026-05-14

All handlers MUST use the Constitution §IV-A safe-cast pattern:
```dart
if (data == null || data is! Map) return;
final map = Map<String, dynamic>.from(data);
```

---

## 1. Messaging — Existing Events (no transport change)

### Client → Server

| Event | Payload | Change |
|-------|---------|--------|
| `sendMessage` | `{chatRoomId, clientMessageId, content, type, fileUrl?, metadata?}` | None |
| `typing` | `{roomId, isTyping}` | None |
| `markDelivered` | `{chatRoomId, clientMessageIds[]}` | None |
| `markRead` | `{chatRoomId, clientMessageIds[]}` | None |
| `joinRoom` | `{roomId}` | None |

### Server → Client

| Event | Payload | Change |
|-------|---------|--------|
| `receiveMessage` / `newMessage` | `{clientMessageId, chatRoomId, senderId, senderPhone, content, type, createdAt, ...}` | None — `senderPhone` already used by Flutter to display sender name in groups |
| `messageSent` | `{clientMessageId, createdAt}` | None |
| `messageDelivered` | `{clientMessageIds[]}` | None |
| `messageRead` | `{clientMessageIds[], readByCount?, participantCount?}` | **Two new optional fields** added when room is GROUP (backwards-compatible) |
| `userTyping` | `{chatRoomId, userId, phoneNumber, isTyping}` | None |
| `userStatus` | `{userId, isOnline}` | None |

### `messageRead` payload (group-aware)

**Backwards-compatible change**:

```jsonc
{
  "clientMessageIds": ["uuid-1"],
  "readByCount": 3,          // NEW — present only for GROUP rooms
  "participantCount": 4      // NEW — present only for GROUP rooms (excludes sender)
}
```

Flutter `ChatCubit.handleMessageStatusUpdate`:
- If `readByCount` is absent → promote to `read` immediately (existing private-chat behavior).
- If `readByCount` is present → promote only when `readByCount >= participantCount`.

---

## 2. Group Calls — New Events

### Client → Server

#### `requestGroupCall`
Caller initiates a group call. Backend fans out `incomingGroupCall` to all participants in the room except the caller.

```jsonc
{
  "chatRoomId": "664f...",
  "isVideo": true
}
```

**Server response**:
- Success: silently broadcasts `incomingGroupCall` to all online room participants (offline members are skipped — call signaling currently does NOT push).
- Failure: `callError { reason: 'not-a-participant' | 'room-not-found' | 'already-in-call' }` to caller.

---

#### `acceptGroupCall`
Invited member accepts the call. Backend issues a LiveKit token and broadcasts `groupCallParticipantJoined` to others.

```jsonc
{
  "chatRoomId": "664f..."
}
```

**Server response** (to joining client only):
```jsonc
{
  "livekitUrl": "wss://ciro-chat-qc2pe2cz.livekit.cloud",
  "livekitToken": "<jwt>",
  "currentParticipants": [
    { "userId": "...", "phoneNumber": "+201...", "displayName": "Ali", "isVideo": true },
    ...
  ]
}
```
Delivered via the existing `callAccepted` event name (extended schema for groups — distinguishable by `currentParticipants` array presence).

**Server response** (to others on the call):
```jsonc
{
  "chatRoomId": "664f...",
  "participant": { "userId": "...", "phoneNumber": "+201...", "displayName": "Ali" }
}
```
Delivered via new event `groupCallParticipantJoined`.

**Errors**:
- `callError { reason: 'call-full' }` — 32-participant cap reached.
- `callError { reason: 'not-a-participant' }` — caller not in room's `participants`.

---

#### `declineGroupCall`
Member ignores or declines the invitation. Does NOT end the call for others.

```jsonc
{
  "chatRoomId": "664f..."
}
```

**Server response**: no broadcast. Optional `callDeclinedAck` to the declining client.

---

#### `leaveGroupCall`
Participant leaves an active group call. Other participants get `groupCallParticipantLeft`. If only one participant remains, backend ends the call.

```jsonc
{
  "chatRoomId": "664f..."
}
```

**Server response** (to others):
```jsonc
{
  "chatRoomId": "664f...",
  "participantUserId": "..."
}
```
Delivered via new event `groupCallParticipantLeft`.

**Auto-end condition** (FR-026): when `activeGroupCalls[chatRoomId].size == 1`, backend emits `callEnded { reason: 'last-participant' }` to the final participant, then deletes the entry.

---

### Server → Client (additional)

#### `incomingGroupCall`
Sent to each online member of the group except the caller when a `requestGroupCall` is received.

```jsonc
{
  "chatRoomId": "664f...",
  "callerId": "<userId>",
  "callerName": "Ali",
  "callerPhone": "+20...",
  "isVideo": true,
  "currentParticipantCount": 1,     // includes caller
  "groupName": "Weekend Crew",
  "groupAvatarUrl": "/uploads/abc.jpg"
}
```

Used by Flutter's `CallCubit` to transition into `CallIncoming` with `isGroupCall: true`, which `CallOverlay` routes to the new `IncomingGroupCallScreen`.

---

#### `groupCallParticipantJoined`
Broadcast to existing participants when someone new joins.

```jsonc
{
  "chatRoomId": "664f...",
  "participant": {
    "userId": "...",
    "phoneNumber": "+201...",
    "displayName": "Sara",
    "avatarUrl": "/uploads/sara.jpg",
    "joinedAt": "2026-05-14T10:00:00Z"
  }
}
```

---

#### `groupCallParticipantLeft`
Broadcast to remaining participants when someone leaves.

```jsonc
{
  "chatRoomId": "664f...",
  "participantUserId": "..."
}
```

---

#### `groupCallRecordingStateChanged`
Broadcast to all participants when any participant starts or stops local recording.

```jsonc
{
  "chatRoomId": "664f...",
  "recorderUserId": "...",
  "recorderName": "Ali",
  "isRecording": true            // true=started, false=stopped
}
```

Flutter handles this by updating `CallActive.recordingState` and showing/hiding the universal REC indicator banner (FR-033/034). The event carries no media — recording media never leaves the recorder's device (INV-6).

---

## 3. Event Catalogue Summary (new additions only)

| Direction | Event Name | Purpose |
|-----------|------------|---------|
| Client → Server | `requestGroupCall` | Start a group call |
| Client → Server | `acceptGroupCall` | Join an active group call |
| Client → Server | `declineGroupCall` | Decline invitation (no broadcast) |
| Client → Server | `leaveGroupCall` | Leave an active group call |
| Client → Server | `groupCallRecordingStateChanged` | Notify others that this client started/stopped local recording |
| Server → Client | `incomingGroupCall` | Group call invitation fanned out |
| Server → Client | `groupCallParticipantJoined` | Someone joined an active call |
| Server → Client | `groupCallParticipantLeft` | Someone left an active call |
| Server → Client | `groupCallRecordingStateChanged` | Echoed to all participants when any client toggles recording |

All event-name strings MUST be declared as constants in `lib/core/network/socket_events.dart` — no scattered literals.
