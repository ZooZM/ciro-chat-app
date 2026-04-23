# Data Model: Group Chat Extension

## 1. ChatRoom Entity Update
The core `ChatRoom` entity in `lib/features/chat/domain/entities/chat_room.dart` will be extended based on the provided implementation guide.

```dart
enum ChatRoomType {
  PRIVATE,
  GROUP,
}

class ChatRoom extends Equatable {
  final String id;
  final List<String> participants; // Phone numbers
  final ChatRoomType type;
  final String? lastMessage;
  
  // --- New Fields ---
  final String? name; // Mandatory if GROUP, otherwise null
  final String? avatarUrl; // Optional group avatar
  final List<String> admins; // Phone numbers of admins

  const ChatRoom({
    required this.id,
    required this.participants,
    required this.type,
    this.lastMessage,
    this.name,
    this.avatarUrl,
    this.admins = const [],
  });

  @override
  List<Object?> get props => [id, participants, type, lastMessage, name, avatarUrl, admins];
}
```

## 2. Local Database Schema Migration (sqflite)
The local SQLite database initialized in `ChatLocalDataSource` must be migrated.

**Old Schema:**
```sql
CREATE TABLE chat_rooms (
  id TEXT PRIMARY KEY,
  participants TEXT, -- JSON Array
  lastMessage TEXT
);
```

**New Schema (Migration Required):**
```sql
ALTER TABLE chat_rooms ADD COLUMN type TEXT DEFAULT 'PRIVATE';
ALTER TABLE chat_rooms ADD COLUMN name TEXT;
ALTER TABLE chat_rooms ADD COLUMN avatarUrl TEXT;
ALTER TABLE chat_rooms ADD COLUMN admins TEXT; -- JSON Array
```

## 3. UI State Models
The `ChatState` within `ChatCubit` may need new sub-states or extended properties if handling specific group creation forms (e.g., `GroupCreationLoading`, `GroupCreationSuccess`, `GroupCreationFailure`). Alternatively, a separate `GroupCreationCubit` can handle the complex form state of selecting participants and uploading avatars before passing the final data to the main `ChatRepository`.