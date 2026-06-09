# Contract: Pagination API

**Date**: April 30, 2026
**FR**: FR-018

## SQLite Query Contract

### `getRoomMessages(roomId, {limit, offset})`

```sql
SELECT * FROM messages
WHERE room_id = :roomId
ORDER BY timestamp DESC
LIMIT :limit OFFSET :offset;
```

**Parameters**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| roomId | String | required | Room identifier |
| limit | int | 30 | Number of messages per page |
| offset | int | 0 | Number of messages to skip |

**Returns**: `List<Message>` ordered newest-first.

**Behavior**:
- If result count < limit → no more messages exist (set `_hasMoreMessages = false`)
- If offset = 0 → initial load (fresh room entry)
- Concurrent calls blocked by `_isLoadingMore` flag

### `watchRoomMessages(roomId, {limit})`

Stream-based variant. Initial emission uses `LIMIT :limit`. Subsequent triggers from `saveMessage()` or `updateMessageStatus()` re-query with the current `_messageOffset + limit` to include all loaded messages.

## Cubit API Contract

### `ChatCubit.loadMoreMessages()`

```dart
Future<void> loadMoreMessages() async {
  if (!_hasMoreMessages || _isLoadingMore) return;
  _isLoadingMore = true;
  
  final older = await _localDataSource.getRoomMessages(
    _currentRoomId,
    limit: 30,
    offset: _messageOffset,
  );
  
  if (older.length < 30) _hasMoreMessages = false;
  _messageOffset += older.length;
  
  // Prepend to existing messages (older messages go at the top)
  final updated = [...older.reversed, ...state.messages];
  emit(state.copyWith(messages: updated));
  
  _isLoadingMore = false;
}
```

## UI Scroll Contract

### `ChatRoomScreen` ScrollController

```dart
_scrollController.addListener(() {
  if (_scrollController.position.extentAfter < 200) {
    context.read<ChatCubit>().loadMoreMessages();
  }
});
```

**Loading indicator**: Show `CupertinoActivityIndicator` at the top of the message list when `_isLoadingMore == true`.
