# Research: Group Chat Implementation

## Findings

### 1. Integration Strategy
The provided `group_chat_implementation_guide.md` clearly outlines that the group chat feature should build upon the existing `ChatRoom` and Socket.io infrastructure. 

**Decision**: We will extend the existing `lib/features/chat` module rather than creating a new feature module.
**Rationale**: Both private and group chats share the `Message` entity, socket events (`sendMessage`, `typing`, `markRead`), and UI components (chat lists, message bubbles). Creating a separate module would lead to massive code duplication and violate DRY principles.

### 2. Offline-First Approach (SQLite)
The Constitution mandates `sqflite` for relational data. Group chat requires updating the local schema.

**Decision**: The local SQLite database schema for `ChatRoom` needs to be migrated to support new columns: `type` (TEXT), `name` (TEXT nullable), `avatarUrl` (TEXT nullable), and `admins` (TEXT JSON-encoded array of phone numbers).
**Rationale**: Adherence to Constitution Principle III (Data Storage). The app must display groups and their last messages while offline.

### 3. Socket Lifecycle Management
The guide states: "When the socket connects, the backend automatically joins the socket to all rooms". However, for group creation, manual joining is required.

**Decision**: The `ChatCubit` must manually emit the `joinRoom` event to the `SocketService` immediately after a successful REST call to `/chat/group/create`.
**Rationale**: This ensures the user can send and receive messages in the newly created group without needing to restart the app or reconnect the socket.

### 4. UI Differentiation
Messages in a group chat need to show who sent them, whereas private chats implicitly belong to the other person.

**Decision**: The `MessageBubble` widget will be updated to accept a `senderName` or `senderPhone` property, which will only be displayed if `ChatRoom.type == ChatRoomType.GROUP` and the message is not from the current user.

## Alternatives Considered
- **Separate `group_chat` feature directory**: Rejected due to excessive duplication of data sources, socket handlers, and UI components. Extending the existing `ChatRoom` entity is cleaner.
- **Handling Admin state locally only**: Rejected. Admin status must be dictated by the backend and stored in the local SQLite DB to prevent spoofing and ensure offline UI consistency.
