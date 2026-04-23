# Quickstart: Group Chat Development

## Overview
This feature extends the existing `ChatRoom` and `Message` infrastructure to support group messaging. The work is primarily contained within the `lib/features/chat/` directory.

## Testing Setup
Since this feature interacts heavily with the local SQLite database and Socket.io, ensure you have mocked dependencies ready for unit testing.

1. **Database Migration Check**:
   Before running the app, ensure the SQLite schema migration runs correctly on app startup to avoid crashes when querying the expanded `ChatRoom` table.

2. **Socket Mocking**:
   When testing the `ChatCubit` for group creation, ensure your mock `SocketService` verifies that `.emit('joinRoom', {'roomId': '...'})` is called exactly once upon successful creation.

## Recommended Implementation Order
1. **Data Layer**: 
   - Update `ChatRoomModel` (`fromJson`/`toJson`).
   - Implement SQLite migrations in `ChatLocalDataSource`.
   - Add the 4 new REST API calls to `ChatRemoteDataSource`.
   - Integrate them into `ChatRepositoryImpl`.
2. **Domain Layer**: 
   - Update `ChatRoom` entity.
   - Update `ChatRepository` abstract class.
3. **Presentation Layer**: 
   - Update `ChatCubit` to handle the new repository methods and manual socket joins.
   - Build UI: `CreateGroupPage`, `GroupInfoPage`.
   - Update UI: `ChatListPage` (show avatars/names), `ChatBubble` (show sender names in groups).
