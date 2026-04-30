# Contract: Atomic Room Resolve API

**Date**: April 30, 2026
**FR**: FR-021

## Backend Endpoint

### `POST /chat/private/resolve` (Updated)

**Request Body**:
```json
{
  "targetUserId": "string (required)",
  "firstMessage": {
    "content": "string",
    "clientMessageId": "string (UUID)",
    "type": "text | image | file | voiceNote | video | location | contact | audio",
    "fileUrl": "string? (optional, for media messages)",
    "metadata": "object? (optional, e.g., {duration, waveformSamples, localPath})"
  }
}
```

**Note**: `firstMessage` is **optional**. When omitted, the endpoint behaves exactly as before (resolve/create room only).

**Response (200 OK)**:
```json
{
  "roomId": "string (MongoDB ObjectId)",
  "room": {
    "_id": "string",
    "type": "private",
    "participants": ["userId1", "userId2"],
    "createdAt": "ISO 8601"
  },
  "message": {
    "_id": "string (MongoDB ObjectId, server-assigned)",
    "clientMessageId": "string (echoed back)",
    "chatRoomId": "string",
    "senderId": "string",
    "content": "string",
    "type": "string",
    "fileUrl": "string?",
    "metadata": "object?",
    "status": "sent",
    "createdAt": "ISO 8601 (server timestamp)"
  }
}
```

**Note**: `message` field is only present when `firstMessage` was included in the request.

**Server-side behavior when `firstMessage` is present**:
1. Resolve or create the private room (existing logic)
2. Join the caller's socket to the room channel: `socket.join(roomId)`
3. Persist the message via `ChatService.createMessage()`
4. Emit `newMessage` event to the room (reaches recipient if online)
5. Return both room and message in the response

**Error cases**:
| Code | Condition |
|------|-----------|
| 400 | Missing `targetUserId` or invalid `firstMessage` format |
| 404 | `targetUserId` not found |
| 403 | Caller is blocked by target user |

## Frontend Integration

### `ChatRemoteDataSource.createPrivateChatRoom()`

```dart
Future<({String roomId, Message? firstMessage})> createPrivateChatRoom(
  String targetUserId, {
  Message? firstMessage,
});
```

### `ChatCubit._ensureRoom()` Changes

```dart
// BEFORE (buggy):
await _remoteDataSource.createPrivateChatRoom(targetUserId);
await Future.delayed(const Duration(milliseconds: 300)); // ← REMOVE
_socketService.joinRoom(roomId); // ← REMOVE (server does this)

// AFTER (atomic):
final result = await _remoteDataSource.createPrivateChatRoom(
  targetUserId,
  firstMessage: pendingMessage, // optional
);
_currentRoomId = result.roomId;
if (result.firstMessage != null) {
  await _localDataSource.updateMessageStatus(
    result.firstMessage!.clientMessageId,
    MessageStatus.sent,
    createdAt: result.firstMessage!.createdAt,
  );
}
```
