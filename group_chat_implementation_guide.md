# Group Chat Implementation Guide (Flutter)

This document provides all the necessary information for the Flutter developer to implement the **Group Chat** feature, based on the current NestJS backend implementation.

## 1. Data Models & Types

### Chat Room Model Updates
The existing `ChatRoom` model returned by the backend has been expanded to support groups. You should update your Flutter `ChatRoom` entity to include these new fields:

```dart
enum ChatRoomType {
  PRIVATE,
  GROUP,
}

class ChatRoom {
  final String id;
  final List<String> participants; // List of User ObjectIds
  final ChatRoomType type; // 'PRIVATE' or 'GROUP'
  final String? lastMessage;
  
  // --- New Group Fields ---
  final String? name; // Human-readable name (Mandatory for GROUP)
  final String? avatarUrl; // Optional group avatar
  final List<String> admins; // Phone numbers of admin participants
  
  // ... constructor and fromJson methods
}
```

## 2. REST API Endpoints

All endpoints require the standard `Bearer <JWT>` authentication header. The base path is `/chat`.

### A. Create a Group
**Endpoint:** `POST /chat/group/create`
**Description:** Creates a new group. The user who creates the group is automatically added as the first participant and assigned as an `admin`.
**Request Body:**
```json
{
  "name": "Flutter Devs", // Required
  "participants": ["+1234567890", "+0987654321"], // Required: Array of phone numbers (minimum 1 other participant)
  "avatarUrl": "https://example.com/avatar.jpg" // Optional
}
```
**Response:** `201 Created` with the newly created `ChatRoom` object.

### B. Add Participants
**Endpoint:** `POST /chat/group/:roomId/add`
**Description:** Adds new members to an existing group. **Note:** The requesting user *must* be an admin in the group.
**Request Body:**
```json
{
  "phoneNumbersToAdd": ["+1112223333", "+4445556666"] // Required: Minimum 1 phone number
}
```
**Response:** `200 OK` with the updated `ChatRoom`.

### C. Remove a Participant
**Endpoint:** `POST /chat/group/:roomId/remove`
**Description:** Kicks a user from the group. **Note:** The requesting user *must* be an admin.
**Request Body:**
```json
{
  "phoneNumberToRemove": "+1112223333" // Required: Phone number of the user to remove
}
```
**Response:** `200 OK` with the updated `ChatRoom`.

### D. Leave Group
**Endpoint:** `POST /chat/group/:roomId/leave`
**Description:** Removes the currently authenticated user from the group. If the user is the *last* admin, another participant is automatically promoted to admin.
**Request Body:** None
**Response:** `200 OK`

## 3. WebSocket Integration (Socket.io)

The existing chat gateway has been built to seamlessly handle both private and group chats using standard `roomId` routing.

### Connection & Auto-Joining
- When the socket connects, the backend **automatically joins the socket to all rooms** the user is a part of (both private and group). 
- No extra action is needed on connect to receive group messages.

### Manual Join (After Creation)
When a user **creates** a new group (via the REST API), they should manually join the socket room so they can send/receive messages immediately without reconnecting:
**Event:** `joinRoom`
**Payload:**
```json
{
  "roomId": "<new_group_room_id>"
}
```

### Sending Messages
Send messages exactly the same way as private chats. The `chatRoomId` just needs to be the Group's ID.
**Event:** `sendMessage`
**Payload:**
```json
{
  "chatRoomId": "<group_room_id>",
  "clientMessageId": "<uuid>",
  "content": "Hello team!",
  "type": "text" // or image, video, etc.
}
```

### Typing Indicators
Works identically to private chats, utilizing the `roomId`.
**Emit Event:** `typing`
```json
{
  "roomId": "<group_room_id>",
  "isTyping": true
}
```
**Listen for:** `userTyping`
```json
{
  "userId": "<sender_id>",
  "phoneNumber": "<sender_phone>",
  "isTyping": true
}
```
*(In UI, you can use the `phoneNumber` or `userId` to show "User X is typing...")*

### Read / Delivered Receipts
These also work out-of-the-box using the `roomId`. Emitting `markDelivered` or `markRead` with a group `chatRoomId` will broadcast the receipt to everyone else in the group.
**Events to Emit:** `markDelivered`, `markRead`
**Listen for:** `messageDelivered`, `messageRead`

## 4. Suggested Implementation Steps (Frontend)

1. **Update Data Sources:** Add the new API calls to your `ChatRemoteDataSource`.
2. **Update Repositories:** Expose group operations through your `ChatRepository`.
3. **UI / State Management (Cubit/Bloc):**
   - Add a UI flow to select multiple contacts and create a group.
   - On group creation success: 
     - Emit `joinRoom` over the WebSocket.
     - Add the new room to the local SQLite database / state.
     - Navigate to the newly created Group Chat Screen.
   - Add a Group Info screen where users can see the participant list.
   - If `room.admins.contains(currentUser.phoneNumber)`, show UI buttons to "Add Participant" and "Remove" next to other members.
4. **Chat UI Differentiation:**
   - In the chat list, display the `room.name` and `room.avatarUrl` for groups.
   - Inside a group chat, display the sender's name/number next to their messages (since there are multiple people).
