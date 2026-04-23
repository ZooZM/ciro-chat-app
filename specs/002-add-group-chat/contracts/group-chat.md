# Interface Contract: Group Chat API

## REST Endpoints
Base URL: `/chat`
Authentication: `Bearer <JWT>`

### 1. Create a Group
- **Method**: POST
- **Path**: `/group/create`
- **Body**:
  ```json
  {
    "name": "string",
    "participants": ["string"], // Array of phone numbers
    "avatarUrl": "string?" // Optional
  }
  ```
- **Response (201 Created)**: Returns the newly created `ChatRoom` JSON object.

### 2. Add Participants
- **Method**: POST
- **Path**: `/group/:roomId/add`
- **Body**:
  ```json
  {
    "phoneNumbersToAdd": ["string"]
  }
  ```
- **Response (200 OK)**: Returns the updated `ChatRoom` JSON object.

### 3. Remove a Participant
- **Method**: POST
- **Path**: `/group/:roomId/remove`
- **Body**:
  ```json
  {
    "phoneNumberToRemove": "string"
  }
  ```
- **Response (200 OK)**: Returns the updated `ChatRoom` JSON object.

### 4. Leave Group
- **Method**: POST
- **Path**: `/group/:roomId/leave`
- **Body**: Empty
- **Response (200 OK)**: Acknowledges the user has left.

## WebSocket Integration (Socket.io)
The existing `SocketService` will handle group real-time events.

### Manual Join (Action Required by Client)
Must be emitted immediately after creating a new group.
- **Event**: `joinRoom`
- **Payload**:
  ```json
  {
    "roomId": "string" // The newly created group ID
  }
  ```

### Shared Events (No changes needed, reuse existing logic with Group IDs)
- **Send Message**: `sendMessage` (Payload includes `chatRoomId`)
- **Typing Indicator**: Emit `typing` -> Listen `userTyping` (Payload includes `roomId`, `phoneNumber`)
- **Receipts**: Emit `markDelivered` / `markRead` -> Listen `messageDelivered` / `messageRead`
