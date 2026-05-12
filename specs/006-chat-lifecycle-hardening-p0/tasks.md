# Tasks 006 — Chat Lifecycle Hardening · P0 Batch

**Spec**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md)  
**Constitution**: [specs/.specify/constitution.md](../.specify/constitution.md)  
**Total tasks**: 28 · **Milestones**: M0 (4+6) · M1 (4+3) · M2 (5+6)

---

## Dependency Graph

```
US1 (indexes)     ──┐
                    ├── M0 (ship today) ── M1 ── M2
US2 (pagination)  ──┘

US3 (offline)     ──┐
                    ├── M1 (this week)
US4 (delete BE)   ──┘

US5 (push)        ── M2 (1–2 weeks)
```

US1 and US2 are independent (different files). Can be implemented in parallel.  
US3 and US4 are independent. Can be implemented in parallel.  
US5 depends on nothing in M0/M1 but must ship after M1 is reviewed.

---

## M0 — Ship Today

### Phase 3 · US1 — SQLite Indexes (FR-001 · BN-01)

**Story goal**: All 4 secondary indexes present after fresh install and upgrade.  
**Independent test**: `SELECT name FROM sqlite_master WHERE type='index'` returns 4 rows.

- [x] T001 [US1] Bump `openDatabase` version `11 → 12` in `lib/features/chat/data/datasources/chat_local_data_source.dart:220` · BN-01 · Effort S · depends_on: —

- [x] T002 [US1] Add `static const _indexStatements = [...]` constant with 4 `CREATE INDEX IF NOT EXISTS` statements after `_statusesSchema` declaration in `lib/features/chat/data/datasources/chat_local_data_source.dart:208` · BN-01 · Effort S · depends_on: —

- [x] T003 [US1] Apply `_indexStatements` in `onCreate` callback by adding a `for` loop after the 4 `db.execute` table-creation calls in `lib/features/chat/data/datasources/chat_local_data_source.dart:221–226` · BN-01 · Effort S · depends_on: T002

- [x] T004 [US1] Add `if (oldVersion < 12)` guard in `onUpgrade` with try/catch `CREATE INDEX` loop after the `< 11` block in `lib/features/chat/data/datasources/chat_local_data_source.dart:265–273` · BN-01 · Effort S · depends_on: T002

---

### Phase 4 · US2 — Pagination State Corruption Fix (FR-003 · BN-03)

**Story goal**: Messages loaded via `loadMoreMessages` remain visible after any new incoming message or status update.  
**Independent test**: After loading 60 messages and receiving a new message, `ChatRoomActive.messages.length >= 60`.

- [x] T005 [US2] Add `final Map<String, int> _roomDisplayLimits = {}` field to `ChatLocalDataSourceImpl` after `_contactsController` declaration in `lib/features/chat/data/datasources/chat_local_data_source.dart:149` · BN-03 · Effort S · depends_on: —

- [x] T006 [US2] Add public `void setRoomDisplayLimit(String roomId, int limit)` method that writes to `_roomDisplayLimits` after the `watchRoomMessages` method in `lib/features/chat/data/datasources/chat_local_data_source.dart:605` · BN-03 · Effort S · depends_on: T005

- [x] T007 [US2] Update `_dispatchUpdateForRoom(String roomId)` at `lib/features/chat/data/datasources/chat_local_data_source.dart:607` to read `_roomDisplayLimits[roomId] ?? 30` as the limit argument to `getRoomMessages` instead of relying on the default · BN-03 · Effort S · depends_on: T005

- [x] T008 [US2] Locate `closeRoomStream` method in `lib/features/chat/data/datasources/chat_local_data_source.dart` and add `_roomDisplayLimits.remove(roomId)` so the HWM is cleared when a room is closed · BN-03 · Effort S · depends_on: T005

- [x] T009 [US2] In `ChatCubit.loadMoreMessages()` at `lib/features/chat/presentation/bloc/chat_cubit.dart:385–408`, after the merged-state `emit`, call `_localDataSource.setRoomDisplayLimit(roomId, _messageOffset + _pageSize)` to record the new high-water-mark · BN-03 · Effort S · depends_on: T006

- [x] T010 [US2] Verify `_messageOffset` is reset to `0` at the start of `openRoom` in `lib/features/chat/presentation/bloc/chat_cubit.dart`; add `_messageOffset = 0;` if missing, to prevent stale offset from a previous visit to the same room · BN-03 · Effort S · depends_on: —

---

## M1 — This Week

### Phase 5 · US3 — Offline Message Recovery (FR-004 · BN-06)

**Story goal**: All messages sent while the user was offline appear within 3 s of reconnection.  
**Independent test**: Manual — User A sends 3 messages to offline User B; User B reconnects; all 3 messages appear in ≤ 3 s; zero duplicates.

- [ ] T011 [US3] Add abstract method `Future<DateTime?> getLastMessageTimestamp(String roomId)` to the `ChatLocalDataSource` interface (wherever the abstract class / interface is declared) · BN-06 · Effort S · depends_on: —

- [ ] T012 [US3] Implement `getLastMessageTimestamp(String roomId)` in `ChatLocalDataSourceImpl` using `rawQuery('SELECT MAX(timestamp) as ts FROM messages WHERE room_id = ?', [roomId])` in `lib/features/chat/data/datasources/chat_local_data_source.dart` (add after `getStuckMessages` around line 641) · BN-06 · Effort S · depends_on: T011

- [ ] T013 [P] [US3] Add private `Future<void> _syncMissedMessages()` method to `ChatCubit` in `lib/features/chat/presentation/bloc/chat_cubit.dart` (near `syncStatusesFromRest` around line 1179): fetch server rooms via `_chatRepository.fetchRooms()`, compare each room's `timestamp` (server `lastMessage.createdAt`) against `getLastMessageTimestamp`, and for rooms where server is newer call `_chatRepository.fetchRoomMessages(roomId)` then `_localDataSource.saveMessage(msg)` for each result · BN-06 · Effort M · depends_on: T012

- [ ] T014 [US3] Wire `_syncMissedMessages().ignore()` into the `onReconnected` lambda in `lib/features/chat/presentation/bloc/chat_cubit.dart:155–161` alongside the existing `syncStatusesFromRest` and `syncPendingMessages` calls · BN-06 · Effort S · depends_on: T013

---

### Phase 6 · US4 — deleteForEveryone Backend Handler (FR-005 · BN-20)

**Story goal**: A sender can delete their own message for all participants; non-senders and expired messages are rejected silently.  
**Independent test**: Emit `deleteForEveryone` → assert `messageDeleted` received by recipient socket AND `isDeleted: true` in MongoDB.

- [ ] T015 [P] [US4] Create new file `chat.config.ts` alongside `chat.module.ts` in the NestJS chat module directory, exporting `CHAT_CONFIG = { DELETE_WINDOW_MINUTES: 60 }` · BN-20 · Effort S · depends_on: —

- [ ] T016 [P] [US4] Add `async softDelete(clientMessageId: string, requesterId: string, windowMinutes: number): Promise<MessageDocument | null>` method to `MessagesRepository` in `messages.repository.ts` after the `markRead` method (after line 46): use `findOneAndUpdate` with conditions `{ clientMessageId, senderId: ObjectId(requesterId), createdAt: { $gte: cutoff }, isDeleted: false }` and update `{ $set: { isDeleted: true, content: '' } }` · BN-20 · Effort S · depends_on: —

- [ ] T017 [US4] Add `@SubscribeMessage('deleteForEveryone')` handler `handleDeleteForEveryone(client, payload: { clientMessageId: string })` to `ChatGateway` in `chat.gateway.ts` after the `handleMarkRead` handler (after line 241): call `messagesRepository.softDelete(payload.clientMessageId, client.data.userId, CHAT_CONFIG.DELETE_WINDOW_MINUTES)`, then emit `this.server.to(roomId).emit('messageDeleted', { clientMessageId })` if result is non-null · BN-20 · Effort S · depends_on: T015, T016

---

## M2 — 1–2 Weeks

### Phase 7 · US5 — Push Notifications (FR-002 · BN-05)

**Story goal**: Offline users receive a FCM/APNs push notification within 2 s of a message being sent; tapping it navigates to the correct room.  
**Independent test**: Manual on physical device — kill app, have partner send message, notification appears ≤ 2 s; tap → correct room.

#### Flutter tasks

- [ ] T018 [US5] Add `firebase_messaging: ^15.0.0` and `flutter_local_notifications: ^18.0.0` under `dependencies` in `pubspec.yaml` and run `flutter pub get` · BN-05 · Effort S · depends_on: —

- [ ] T019 [US5] Create `lib/core/services/push_notification_service.dart` with: `init()` (request permission, get token, call `_registerToken`, subscribe to `onTokenRefresh`), `_registerToken(token)` (POST to `/auth/device-token` via DioClient), `handleForegroundMessage(RemoteMessage)` (show local notification via `flutter_local_notifications`), `handleNotificationTap(RemoteMessage)` (extract `roomId`, navigate via GoRouter) · BN-05 · Effort M · depends_on: T018

- [ ] T020 [P] [US5] Add top-level `@pragma('vm:entry-point') Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message)` function in `lib/main.dart` and register it via `FirebaseMessaging.onBackgroundMessage` before `runApp` · BN-05 · Effort S · depends_on: T019

- [ ] T021 [P] [US5] Call `await getIt<PushNotificationService>().init()` in `lib/features/auth/presentation/bloc/auth_cubit.dart` after successful `checkAuthStatus()` and `verifyOtp()` login paths · BN-05 · Effort S · depends_on: T019

- [ ] T022 [P] [US5] Add notification deep-link handler in `lib/core/routing/app_router.dart`: on app launch from terminated state via `FirebaseMessaging.instance.getInitialMessage()`, extract `roomId` from notification payload and navigate to `ChatRoomScreen` · BN-05 · Effort S · depends_on: T019

#### Backend tasks

- [ ] T023 [P] [US5] Create `src/modules/notifications/device-token.schema.ts` defining a Mongoose schema `{ userId: ObjectId, token: String, platform: 'fcm'|'apns', updatedAt: Date }` with a compound unique index on `{ userId, token }` · BN-05 · Effort S · depends_on: —

- [ ] T024 [P] [US5] Create `src/modules/notifications/device-tokens.repository.ts` with `upsertToken(userId, token, platform)` (findOneAndUpdate with upsert) and `getTokens(userId)` methods · BN-05 · Effort S · depends_on: T023

- [ ] T025 [P] [US5] Create `src/modules/notifications/push.service.ts` with `onModuleInit()` (initialise `firebase-admin` from `FIREBASE_SERVICE_ACCOUNT` env JSON), `sendPush(deviceToken, payload)` (calls `admin.messaging().send()`), `notifyOfflineUser(userId, message)` (looks up tokens via `DeviceTokensRepository`, calls `sendPush` for each) · BN-05 · Effort M · depends_on: T024

- [ ] T026 [US5] Create `src/modules/notifications/notifications.module.ts` importing `MongooseModule` for `DeviceToken`, providing `PushService` and `DeviceTokensRepository`, exporting `PushService` · BN-05 · Effort S · depends_on: T023, T024, T025

- [ ] T027 [P] [US5] Add `POST /auth/device-token` endpoint to `src/modules/auth/auth.controller.ts` (or wherever auth routes live): `@UseGuards(JwtAuthGuard)` protected, calls `deviceTokensRepository.upsertToken(req.user.userId, dto.token, dto.platform)` · BN-05 · Effort S · depends_on: T024

- [ ] T028 [US5] Inject `PushService` into `ChatGateway` (`chat.gateway.ts`) and in `handleSendMessage` after broadcasting `newMessage`, iterate over room participant IDs; for each participant not in `activeSockets` call `pushService.notifyOfflineUser(participantId, savedMessage)` · BN-05 · Effort M · depends_on: T025, T026

---

## Parallel Execution Map

### M0 (can run simultaneously)
```
Thread A: T001 → T002 → T003 → T004   (US1 — indexes, one file)
Thread B: T010 → T005 → T006 → T007   (US2 — pagination data source)
Thread C: T009                          (US2 — pagination cubit, after T006)
```
T008 (closeRoomStream reset) can be done in parallel with T006/T007.

### M1 (can run simultaneously)
```
Thread A: T011 → T012 → T013 → T014   (US3 — offline recovery)
Thread B: T015, T016 → T017            (US4 — deleteForEveryone backend)
```
T015 and T016 have no mutual dependency — write both files in parallel.

### M2 (can run simultaneously)
```
Flutter:
  T018 → T019 → T020, T021, T022 (parallel after T019)

Backend:
  T023 → T024 → T025 → T026
  T027 (parallel with T025, depends only on T024)
  T028 (after T025 + T026)
```

---

## Implementation Strategy

**MVP = M0 only** — indexes + pagination fix. Both are Flutter-only, no backend
coordination needed, lowest risk, highest read-path impact. Ship and measure.

**M1** — offline recovery (Flutter-only) + deleteForEveryone (backend). Two
independent streams; backend can be deployed while Flutter PR is in review.

**M2** — push notifications require native config (GoogleService-Info.plist,
Firebase Console) and physical-device testing. Allow 1–2 weeks for iteration.

---

## Commit Message Templates

```
# M0
fix(db): add SQLite indexes for messages and contacts (Resolves BN-01)
fix(chat): fix pagination state corruption on incoming message (Resolves BN-03)

# M1
fix(chat): sync missed messages on socket reconnect (Resolves BN-06)
fix(chat-be): implement deleteForEveryone gateway handler (Resolves BN-20)

# M2
feat(push): add FCM+APNs push notifications via NotificationsModule (Resolves BN-05)
```

Each commit must end with `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`  
per C-06 of the constitution.
