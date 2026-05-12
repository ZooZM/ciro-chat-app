# Plan 006 — Chat Lifecycle Hardening · P0 Batch

**Spec**: [spec.md](spec.md)  
**Constitution**: [specs/.specify/constitution.md](../.specify/constitution.md)  
**Clarify decisions**: see STEP 3 answers in conversation history  
**Milestones**: M0 (ship today) · M1 (this week) · M2 (1–2 weeks)

---

## P0-A · SQLite Indexes (BN-01)   — M0

### Current state
`chat_local_data_source.dart:218–220` opens DB at **version 11**, path
`'ciro_chat.db_v1'`. `onCreate` (line 221) creates 4 tables with **zero**
secondary indexes. `onUpgrade` at line 227 has guards for `< 8`, `< 9`,
`< 10`, `< 11` but none add indexes.

Every `getRoomMessages` (line 572) runs a full scan on `messages` with
`WHERE room_id = ?` and no index. Every `saveMessage` dedup check (line 293)
scans with `WHERE client_message_id = ?` and no index.

### Changes

**File**: `lib/features/chat/data/datasources/chat_local_data_source.dart`

1. **Bump version** `11 → 12` at line 220:
   ```dart
   version: 12,
   ```

2. **Add index constants** after `_statusesSchema` (after line 208):
   ```dart
   static const _indexStatements = [
     'CREATE INDEX IF NOT EXISTS idx_msg_room_ts   ON messages(room_id, timestamp DESC)',
     'CREATE INDEX IF NOT EXISTS idx_msg_client_id ON messages(client_message_id)',
     'CREATE INDEX IF NOT EXISTS idx_msg_status    ON messages(status)',
     'CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phoneNumber)',
   ];
   ```

3. **Apply indexes in `onCreate`** (after line 225, run each statement):
   ```dart
   for (final stmt in _indexStatements) { await db.execute(stmt); }
   ```

4. **Apply indexes in `onUpgrade`** — add a new guard after the `< 11` block
   (after line 273):
   ```dart
   if (oldVersion < 12) {
     for (final stmt in _indexStatements) {
       try { await db.execute(stmt); }
       catch (e) { debugPrint('Migration v12 index error: $e'); }
     }
   }
   ```

### Verification
- Flutter integration test: seed 10,000 messages into a room, call
  `getRoomMessages(roomId)`, assert wall time < 100 ms.
- Query `SELECT name FROM sqlite_master WHERE type='index'` and assert all 4
  indexes present.
- Run existing tests to confirm no regression.

---

## P0-C · Pagination State Corruption Fix (BN-03)   — M0

### Current state
`_dispatchUpdateForRoom(roomId)` at line 607 always calls
`getRoomMessages(roomId)` with the **default `limit=30, offset=0`**. After
`loadMoreMessages()` merges older pages into `ChatRoomActive.messages`, the
next incoming message or status update triggers `_dispatchUpdateForRoom` →
queries only newest 30 → overwrites state → older messages vanish from UI.

`ChatCubit` fields at lines 67–69: `_pageSize = 30`, `_messageOffset = 0`.
`loadMoreMessages()` at line 385 increments `_messageOffset += _pageSize` but
never communicates the expanded window to the data source.

### Changes

#### File: `lib/features/chat/data/datasources/chat_local_data_source.dart`

1. **Add `_roomDisplayLimits` map** after `_recentChatsController` declaration
   (after line 149):
   ```dart
   final Map<String, int> _roomDisplayLimits = {};
   ```

2. **New public method** `setRoomDisplayLimit` (add after the `watchRoomMessages`
   method, after line 605):
   ```dart
   void setRoomDisplayLimit(String roomId, int limit) {
     _roomDisplayLimits[roomId] = limit;
   }
   ```

3. **Update `_dispatchUpdateForRoom`** (line 607) to use the stored limit:
   ```dart
   Future<void> _dispatchUpdateForRoom(String roomId) async {
     if (_roomStreamControllers.containsKey(roomId)) {
       final limit = _roomDisplayLimits[roomId] ?? 30;
       final messages = await getRoomMessages(roomId, limit: limit);
       _roomStreamControllers[roomId]!.add(messages);
     }
   }
   ```

4. **Reset limit in `closeRoomStream`** (locate the `closeRoomStream` method and
   add):
   ```dart
   _roomDisplayLimits.remove(roomId);
   ```

#### File: `lib/features/chat/presentation/bloc/chat_cubit.dart`

5. **In `loadMoreMessages()`** (line 385), after `_messageOffset += _pageSize`
   and after the `emit(merged ...)` call, update the data source limit:
   ```dart
   final newTotal = (_messageOffset + _pageSize);
   _localDataSource.setRoomDisplayLimit(roomId, newTotal);
   ```

6. **In `closeRoom()`** (line 411), after
   `_localDataSource.closeRoomStream(_activeRoomId!)`, the `closeRoomStream`
   already removes the limit (step 4 above) — no extra call needed.

7. **Reset `_messageOffset`** on `openRoom` to ensure a fresh offset when
   re-entering a room (verify this already happens — if not, add
   `_messageOffset = 0;` at the start of `openRoom`).

### Verification
- Widget test: open a room, load 2 extra pages (60 messages total), send a new
  message, assert `ChatRoomActive.messages.length >= 60`.
- Widget test: open a room with default load (30 messages), receive a new message,
  assert `messages.length == 31` (no regression).

---

## P0-D · Offline Message Recovery (BN-06)   — M1

### Current state
`onReconnected` at line 155 calls only `syncStatusesFromRest()` and
`syncPendingMessages()`. It does **not** fetch new messages sent while offline.

`fetchRooms()` at `chat_remote_data_source.dart:359` already returns
`ChatSession` objects with `timestamp` = `lastMessage.createdAt` (parsed at
`chat_session.dart:189–192`). Backend `GET /chat/rooms` populates `lastMessage`
with the full document including `createdAt`.

`fetchRoomMessages(roomId)` at `chat_remote_data_source.dart:397` fetches the
50 newest messages with no params — sufficient for recovery (backend default
limit=50, sorted newest-first).

### Changes

#### File: `lib/features/chat/data/datasources/chat_local_data_source.dart`

1. **New method** `getLastMessageTimestamp(String roomId) → Future<DateTime?>`:
   ```dart
   Future<DateTime?> getLastMessageTimestamp(String roomId) async {
     final db = _db;
     if (db == null) return null;
     final rows = await db.rawQuery(
       'SELECT MAX(timestamp) as ts FROM messages WHERE room_id = ?',
       [roomId],
     );
     final ts = rows.first['ts'] as int?;
     return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
   }
   ```

2. **Add `getLastMessageTimestamp` to `ChatLocalDataSource` interface** in
   `lib/features/chat/domain/repositories/chat_repository.dart` (or the
   abstract datasource class — wherever the interface is defined).

#### File: `lib/features/chat/presentation/bloc/chat_cubit.dart`

3. **New private method** `_syncMissedMessages()` — add near `syncStatusesFromRest`
   (around line 1179):
   ```dart
   Future<void> _syncMissedMessages() async {
     final roomsResult = await _chatRepository.fetchRooms();
     if (roomsResult.isLeft()) return;
     final serverRooms = roomsResult.getOrElse(() => []);

     await Future.wait(
       serverRooms.map((serverRoom) async {
         final localTip = await _localDataSource
             .getLastMessageTimestamp(serverRoom.id);
         // If server lastMessage is newer than local tip, fetch missing messages.
         if (localTip == null ||
             serverRoom.timestamp.isAfter(localTip.add(const Duration(seconds: 1)))) {
           final msgsResult = await _chatRepository
               .fetchRoomMessages(serverRoom.id);
           if (msgsResult.isLeft()) return;
           final messages = msgsResult.getOrElse(() => []);
           for (final msg in messages) {
             // saveMessage is idempotent — dedup guard at
             // chat_local_data_source.dart:292 prevents duplicates.
             await _localDataSource.saveMessage(msg);
           }
         }
       }),
     );
   }
   ```

4. **Wire into `onReconnected`** at line 159 — add call after existing syncs:
   ```dart
   _socketService.onReconnected = () {
     syncStatusesFromRest().ignore();
     syncPendingMessages().ignore();
     _syncMissedMessages().ignore();   // ← ADD
   };
   ```

### Rollout note
`fetchRooms` returns ≤20 rooms per the backend default. For users with >20
rooms, missed messages in older rooms won't be recovered (capped by the inbox
limit). This is acceptable for M1; fix for inbox pagination is P2-F.

### Verification
- Manual test: User A sends 3 messages to User B while User B's device is in
  airplane mode. Restore network. Within 3 s, all 3 messages must appear in
  User B's room. Zero duplicates observed after repeated reconnect.

---

## P0-E · deleteForEveryone Backend Handler (BN-20)   — M1

### Current state (Flutter — already done)
- `socket_service.dart:56–57` — `onMessageDeleted` callback defined.
- `socket_service.dart:199–207` — listens for `messageDeleted` event.
- `socket_service.dart:308–310` — `deleteMessageForEveryone(clientMessageId)` emitter.
- `chat_cubit.dart:163–166` — `onMessageDeleted` wired to `_handleDeletedMessage`.

The client is **fully wired**. Only the backend is missing.

### Current state (Backend — missing)
`chat.gateway.ts` has no `@SubscribeMessage('deleteForEveryone')` handler.
`messages.repository.ts` has no `softDelete` method.
`message.schema.ts` has `isDeleted` field (line ~88) but it is never written.

### Changes

#### File: `messages.repository.ts` (63 lines)

Add `softDelete` method after `markRead` (after line 46):
```typescript
async softDelete(
  clientMessageId: string,
  requesterId: string,
  windowMinutes: number,
): Promise<MessageDocument | null> {
  const cutoff = new Date(Date.now() - windowMinutes * 60_000);
  return this.messageModel.findOneAndUpdate(
    {
      clientMessageId,
      senderId: new Types.ObjectId(requesterId),   // permission check
      createdAt: { $gte: cutoff },                 // time-window check
      isDeleted: false,
    },
    { $set: { isDeleted: true, content: '' } },
    { new: true },
  ).exec();
}
```

#### New file: `chat.config.ts` (alongside `chat.module.ts`)
```typescript
export const CHAT_CONFIG = {
  DELETE_WINDOW_MINUTES: 60,   // configurable constant — change without code deploy via env
} as const;
```

#### File: `chat.gateway.ts` (385 lines)

Add after `handleMarkRead` handler (after line 241):
```typescript
@SubscribeMessage('deleteForEveryone')
async handleDeleteForEveryone(
  client: AuthenticatedSocket,
  payload: { clientMessageId: string },
): Promise<void> {
  const msg = await this.messagesRepository.softDelete(
    payload.clientMessageId,
    client.data.userId,
    CHAT_CONFIG.DELETE_WINDOW_MINUTES,
  );
  if (!msg) return; // not found, not owner, or outside window — silent fail

  const roomId = msg.chatRoomId.toString();
  // Notify all room participants including sender
  this.server.to(roomId).emit('messageDeleted', {
    clientMessageId: payload.clientMessageId,
  });
}
```

### Verification
- Integration test: Send message → wait < 60 min → emit `deleteForEveryone` →
  assert `messageDeleted` received by connected recipient socket.
- Assert `isDeleted: true` and `content: ''` in MongoDB after delete.
- Assert: emit `deleteForEveryone` from a DIFFERENT user's socket → assert no
  `messageDeleted` event emitted (permission check).
- Assert: emit `deleteForEveryone` with a >60 min old message → assert silent
  no-op.

---

## P0-B · Push Notifications (BN-05)   — M2

### Decision summary (from /clarify)
- Platforms: **FCM + APNs day one** (via `firebase_messaging` which handles both)
- Payload: **Full** — `{ roomId, senderName, content, messageType, clientMessageId }`
- Token registration: on every login + `onTokenRefresh` callback
- Backend: **new standalone `NotificationsModule`** with `PushService` injected
  into `ChatGateway`

### Flutter changes

#### `pubspec.yaml`
Add under `dependencies`:
```yaml
firebase_messaging: ^15.x.x
flutter_local_notifications: ^18.x.x
```

#### New file: `lib/core/services/push_notification_service.dart`
Responsibilities:
- `init()` — call `FirebaseMessaging.instance.requestPermission()`, get token,
  call `_registerToken(token)`, listen to `onTokenRefresh`
- `_registerToken(token)` — POST `/auth/device-token` via DioClient
- `handleForegroundMessage(RemoteMessage)` — show local notification via
  `flutter_local_notifications`
- `handleNotificationTap(RemoteMessage)` — extract `roomId` from payload,
  push `ChatRoomScreen` via `GoRouter`
- Static: `setupBackgroundHandler()` — `FirebaseMessaging.onBackgroundMessage`
  top-level function (must be top-level, not a method)

#### `lib/features/auth/presentation/bloc/auth_cubit.dart`
After successful `checkAuthStatus()` or `verifyOtp()`, call:
```dart
await getIt<PushNotificationService>().init();
```

#### `lib/core/routing/app_router.dart`
Add deep-link handler: if app launched from terminated state via notification,
navigate to `ChatRoomScreen` with the `roomId` from the notification payload.

### Backend changes

#### New directory: `src/modules/notifications/`
- `notifications.module.ts` — imports `firebase-admin`, exports `PushService`
- `push.service.ts`:
  - `onModuleInit()` — initialise `firebase-admin` with service account JSON
    from env `FIREBASE_SERVICE_ACCOUNT`
  - `sendPush(deviceToken, payload)` — calls `admin.messaging().send()`
  - `notifyOfflineUser(userId, message)` — looks up user's device token(s) in
    DB, calls `sendPush` for each token
- `device-token.schema.ts` — MongoDB schema:
  ```typescript
  { userId: ObjectId, token: string, platform: 'fcm'|'apns', updatedAt: Date }
  ```
- `device-tokens.repository.ts` — `upsertToken(userId, token)`, `getTokens(userId)`

#### `src/modules/auth/auth.controller.ts`
Add endpoint:
```typescript
@Post('device-token')
@UseGuards(JwtAuthGuard)
async registerDeviceToken(@Request() req, @Body() dto: RegisterDeviceTokenDto) {
  return this.notificationsService.upsertToken(req.user.userId, dto.token);
}
```

#### `src/modules/chat/chat.gateway.ts`
Inject `PushService`. In `handleSendMessage`, after saving the message and
checking `activeSockets`:
```typescript
for (const participantId of roomParticipantIds) {
  if (participantId !== senderId && !this.activeSockets.has(participantId)) {
    await this.pushService.notifyOfflineUser(participantId, savedMessage);
  }
}
```

### APNs setup note
`firebase_messaging` handles APNs automatically on iOS via Firebase's APNs
relay — no separate APNs library needed. Requires:
- `GoogleService-Info.plist` in `ios/Runner/`
- APNs auth key uploaded to Firebase Console
- `aps-environment` entitlement in `ios/Runner.entitlements`

### Verification
- Physical Android device: kill app, have another user send a message, assert
  notification appears within 2 s (C-01).
- Tap notification → assert app opens to correct `ChatRoomScreen`.
- Rotate FCM token (via `FirebaseMessaging.instance.deleteToken()` + restart),
  assert new token registered with backend.
- iOS physical device: same smoke test.

---

## File change summary

| Milestone | File | Change type |
|-----------|------|------------|
| M0 | `lib/features/chat/data/datasources/chat_local_data_source.dart` | DB v11→12, 4 indexes, `_roomDisplayLimits`, `setRoomDisplayLimit`, update `_dispatchUpdateForRoom` |
| M0 | `lib/features/chat/presentation/bloc/chat_cubit.dart` | `loadMoreMessages` update HWM, verify `openRoom` resets offset |
| M1 | `lib/features/chat/data/datasources/chat_local_data_source.dart` | `getLastMessageTimestamp` |
| M1 | `lib/features/chat/presentation/bloc/chat_cubit.dart` | `_syncMissedMessages`, wire into `onReconnected` |
| M1 | `chat.gateway.ts` (backend) | `handleDeleteForEveryone` handler |
| M1 | `messages.repository.ts` (backend) | `softDelete` method |
| M1 | `chat.config.ts` (backend) | New — `DELETE_WINDOW_MINUTES = 60` |
| M2 | `pubspec.yaml` | Add `firebase_messaging`, `flutter_local_notifications` |
| M2 | `lib/core/services/push_notification_service.dart` | New file |
| M2 | `lib/features/auth/presentation/bloc/auth_cubit.dart` | Wire push init |
| M2 | `lib/core/routing/app_router.dart` | Deep-link handler |
| M2 | `src/modules/notifications/` (backend) | New module — 4 files |
| M2 | `src/modules/auth/auth.controller.ts` (backend) | `POST /auth/device-token` |
| M2 | `src/modules/chat/chat.gateway.ts` (backend) | Inject PushService, notify offline users |
