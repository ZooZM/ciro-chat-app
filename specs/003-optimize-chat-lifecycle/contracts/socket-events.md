# Socket Events Contract: Chat Lifecycle

**Branch**: `003-optimize-chat-lifecycle` | **Date**: 2026-04-25

## Client → Server Events

### `sendMessage`
```json
{
  "chatRoomId": "mongo_room_id",
  "content": "Hello!",
  "clientMessageId": "uuid-v4",
  "type": "text|image|file|voice_note|contact|location|audio|poll|event",
  "fileUrl": "/uploads/uuid.ext",
  "metadata": {
    // Varies by type — see data-model.md
  }
}
```

### `typing`
```json
{
  "roomId": "mongo_room_id",
  "isTyping": true
}
```

### `markDelivered`
```json
{
  "chatRoomId": "mongo_room_id",
  "clientMessageIds": ["uuid1", "uuid2"]
}
```

### `markRead`
```json
{
  "chatRoomId": "mongo_room_id",
  "clientMessageIds": ["uuid1", "uuid2"]
}
```

### `joinRoom`
```json
{
  "roomId": "mongo_room_id"
}
```

### `requestCall`
```json
{
  "targetUserId": "phone_number",
  "isVideo": false
}
```

### `acceptCall`
```json
{
  "callerId": "phone_number"
}
```

### `rejectCall`
```json
{
  "callerId": "phone_number"
}
```

### `endCall`
```json
{}
```

### `deleteForEveryone` (NEW — FR-022)
```json
{
  "chatRoomId": "mongo_room_id",
  "clientMessageId": "uuid-v4"
}
```
**Server behavior**: Validates sender owns the message AND `createdAt` < 1 hour ago. Sets `isDeleted: true` on message doc. Broadcasts `messageDeleted` to all room participants.

---

## Server → Client Events

### `connected`
```json
{
  "userId": "mongo_user_id",
  "joinedRooms": ["room_id_1", "room_id_2"]
}
```

### `messageSent` (ACK)
```json
{
  "clientMessageId": "uuid-v4",
  "createdAt": "2026-04-25T01:00:00.000Z"
}
```

### `newMessage`
Full MongoDB Message document (populated).

### `userTyping`
```json
{
  "chatRoomId": "mongo_room_id",
  "userId": "mongo_user_id",
  "phoneNumber": "+20XXXXXXXXXX",
  "isTyping": true
}
```

### `messageDelivered`
```json
{
  "chatRoomId": "mongo_room_id",
  "clientMessageIds": ["uuid1"],
  "deliveredTo": "mongo_user_id"
}
```

### `messageRead`
```json
{
  "chatRoomId": "mongo_room_id",
  "clientMessageIds": ["uuid1"],
  "readBy": "mongo_user_id"
}
```

### `messageDeleted` (NEW — FR-022)
```json
{
  "chatRoomId": "mongo_room_id",
  "clientMessageId": "uuid-v4",
  "deletedBy": "mongo_user_id"
}
```
**Client behavior**: Find message by `clientMessageId` in local SQLite. Set `is_deleted = 1`. Update in-memory state. Bubble renders "🚫 This message was deleted".

### `incomingCall`
```json
{
  "callerId": "phone_number",
  "callerName": "User Name",
  "callerAvatar": "",
  "isVideo": false
}
```

### `callAccepted`
```json
{
  "receiverId|callerId": "id",
  "roomName": "call_id1_id2",
  "livekitUrl": "wss://...",
  "livekitToken": "jwt"
}
```

### `callRejected`
```json
{
  "receiverId": "mongo_user_id"
}
```

### `callEnded`
```json
{
  "reason": "user_ended|peer_disconnected"
}
```

---

## REST Endpoints

### `POST /chat/upload`
**Request**: `multipart/form-data` with `file` field (max 20MB)
**Response**:
```json
{
  "fileUrl": "/uploads/uuid.ext",
  "fileName": "photo.jpg",
  "fileSize": 1234567,
  "mimeType": "image/jpeg"
}
```

### `GET /chat/rooms`
**Query**: `?limit=20&cursor=<room_id>`
**Response**: Array of populated ChatRoom documents

### `GET /chat/rooms/:roomId/messages`
**Query**: `?limit=50&cursor=<message_id>`
**Response**: Array of populated Message documents

### `POST /chat/private/resolve` (UPDATED — FR-021)
**Body**: `{ "userId": "mongo_user_id", "firstMessage": { "content": "...", "clientMessageId": "uuid", "type": "text", "fileUrl?": "...", "metadata?": {} } }`
**Response**: `{ "roomId": "...", "room": {...}, "message?": { "_id": "...", "clientMessageId": "...", "status": "sent", "createdAt": "..." } }`
**Note**: `firstMessage` and response `message` are optional. See `contracts/atomic-resolve-api.md` for full details.

### `POST /chat/messages/sync-statuses`
**Body**: `{ "clientMessageIds": ["uuid1", "uuid2"] }`
**Response**: Array of `{ clientMessageId, status }`

### `POST /chat/group/create`
**Body**: `{ "name": "Group Name", "participants": ["+20XXX"], "avatarUrl": "..." }`

### `POST /chat/group/:roomId/add`
**Body**: `{ "phoneNumbersToAdd": ["+20XXX"] }`

### `POST /chat/group/:roomId/remove`
**Body**: `{ "phoneNumberToRemove": "+20XXX" }`

### `POST /chat/group/:roomId/leave`
No body required.
