# Ciro Chat App — Architecture Constitution

> Ground truth for every feature touching auth, sockets, presence, media, message delivery, notifications, and URL resolution. Before adding or changing behaviour in any of these systems, read the relevant section. Rules marked **DO NOT** are hard invariants — breaking them will introduce regressions.

---

## 1. Auth & Token Flow

### Storage
- **Access token** and **refresh token** are stored exclusively in `FlutterSecureStorage` via `AuthLocalDataSource`.
- Keys: `accessToken`, `refreshToken`, `userPhone`, `userId`, `isLoggedIn`.
- **DO NOT** store tokens in SharedPreferences, in-memory only, or any unencrypted store.

### Lifecycle
1. On app start, `AuthCubit.verifyAuthStatus()` calls `_repository.checkAuthStatus()` — this is **local-only** (reads secure storage; makes no network call).
2. If authenticated, reads the stored access token and calls `SocketService.connect(token)`.
3. On successful OTP verification (`verifyOtp`), tokens are extracted from the server response and stored via `saveTokens`. Socket is then connected.
4. On logout (`AuthCubit.logOut`): `ChatCubit.reset()` → `CallCubit.reset()` → `SocketService.disconnect()` → `PushNotificationService.dispose()` → `ChatLocalDataSource.clearAllData()` → `_repository.logout()`. This order is mandatory.

### HTTP Token Refresh
- `DioClient` attaches `Bearer <accessToken>` to every request via `onRequest` interceptor.
- On HTTP 401: a secondary isolated `Dio` instance (no interceptors) calls `POST /auth/refresh` with the refresh token.
- On success: saves new tokens, reconnects socket with new access token, retries the original request.
- On failure: calls `deleteTokens()` then `globalOnUnauthorizedRedirect()` to navigate to auth screen.
- **DO NOT** use the main `DioClient.dio` instance for token refresh (infinite loop risk).

### Socket Token Refresh
- `SocketService._handleTokenRefresh()` is called on `onConnectError` or `onDisconnect` when the reason contains "jwt expired", "unauthorized", or "401".
- Uses its own isolated `Dio` instance (`refreshDio`) for the refresh call.
- On failure: calls `deleteTokens()` AND `globalOnUnauthorizedRedirect()`.
- **DO NOT** let socket token refresh fail silently without redirecting to auth.

### Proactive Refresh
- On `verifyAuthStatus`, decode the stored JWT and check the `exp` field.
- If expiry is within 5 minutes, attempt proactive refresh before connecting the socket.
- This prevents the "brief jwt-expired socket error on app open" scenario.

---

## 2. Socket Events

### Connection
- Socket uses `websocket` transport only (`setTransports(['websocket'])`).
- Authentication is via `setAuth({'token': token})`, **not** Authorization header.
- `disableAutoConnect()` is used; manual `.connect()` is called after setup.
- On `connect`: set `isConnectedNotifier.value = true`, call `onReconnected` callback.
- On `onConnectError` / `onDisconnect`: set `isConnectedNotifier.value = false`, handle token refresh if JWT-related.

### Events the Flutter client LISTENS to (server → client)
| Event | Payload | Handler |
|---|---|---|
| `messageSent` | `{clientMessageId, createdAt}` | Promote sender's message: `pending → sent` |
| `messageDelivered` | `{clientMessageIds[]}` | Promote sender's messages: `sent → delivered` |
| `messageRead` | `{clientMessageIds[]}` | Promote sender's messages: `delivered → read` |
| `receiveMessage` / `newMessage` | Full message object | Save incoming, emit markDelivered, markRead if active room |
| `userTyping` | `{chatRoomId, userId, phoneNumber, isTyping}` | Update typing indicators |
| `userStatus` | `{userId, isOnline}` | Update contact online status in SQLite |
| `incomingCall` | `{callerId, callerName, isVideo, ...}` | Show incoming call overlay |
| `callAccepted` | `{livekitToken, roomName, ...}` | Join LiveKit room |
| `callRejected` | `{receiverId}` | Dismiss call UI |
| `statusReceived` | `{statusId, ...}` | Show status notification |
| `messageDeleted` | `{clientMessageId}` | Soft-delete message locally |
| `connected` | `{userId, joinedRooms[]}` | Confirmation from server (informational only) |

### Events the Flutter client EMITS (client → server)
| Event | When |
|---|---|
| `joinRoom` | After JIT room creation (newly created rooms only; existing rooms auto-joined on connect) |
| `sendMessage` | After optimistic local save, and on `syncPendingMessages` replay |
| `markDelivered` | Immediately when `receiveMessage` arrives (recipient side) |
| `markRead` | When recipient is in the active room and receives/opens a message |
| `typing` | Debounced; 3-second auto-reset timer |
| `requestCall`, `acceptCall`, `rejectCall`, `endCall` | Call signaling |
| `uploadStatus`, `statusViewed` | Status feature |
| `deleteForEveryone` | FR-022 message deletion |

### Type Safety Rule
- Socket.IO delivers Map data as `Map<dynamic, dynamic>`, **not** `Map<String, dynamic>`.
- **DO NOT** use `data is Map<String, dynamic>` for socket event guards — it returns `false` even for valid payloads.
- **USE** `data is! Map` as the null/type guard, then access fields via `data['key']?.toString()`.

---

## 3. Presence System

### How it works
- The backend (`ChatGateway`) marks a user **online** in `handleConnection` and **offline** in `handleDisconnect`.
- On connect, the backend broadcasts `userStatus { userId, isOnline: true }` to all of the user's room members.
- On disconnect, the backend broadcasts `userStatus { userId, isOnline: false }` to all of the user's room members.
- Flutter's `onUserStatusChanged` callback updates `chat_sessions` table via `updateUserOnlineStatus`.

### App lifecycle
- `MainApp` (StatefulWidget with `WidgetsBindingObserver`) handles lifecycle:
  - `paused` / `detached`: `SocketService.disconnect()` → backend fires `handleDisconnect` → user marked offline
  - `resumed` (when not connected): reads access token and calls `SocketService.connect(token)` → backend fires `handleConnection` → user marked online
- **DO NOT** add mutable "isOnline" state to the Flutter app — backend is the single source of truth.

### Observing presence in UI
- `ChatTileWidget` reads `chat.isOnline` from `ChatSession` entity (sourced from SQLite).
- `ChatRoomScreen` header reads the same.
- Updates arrive via the `userStatus` socket event → `_localDataSource.updateUserOnlineStatus` → stream refresh.

---

## 4. Media Handling

### Upload flow
1. Pick file (image / video / audio / document via `ImagePicker` or `FilePicker`).
2. Save an **optimistic** `pending` message locally with `localPath` in metadata.
3. Call `_chatRepository.uploadFile(File(path))` → returns `Either<Failure, Map>`.
4. On success: `updateMessageMedia(msgId, fileUrl, meta)` patches the bubble, then emit `sendMessage` via socket.
5. On failure: `updateMessageStatus(msgId, MessageStatus.error)` + show `SnackBar`.
6. **DO NOT** emit the socket `sendMessage` before `updateMessageMedia` completes.

### Download & caching
- All remote images: use `CachedNetworkImage` — never `Image.network`.
- All remote videos: use `DefaultCacheManager().getSingleFile(url)` → `VideoPlayerController.file(fileInfo)`.
  - **DO NOT** use `VideoPlayerController.networkUrl` — it re-downloads every open.
- Voice notes: `flutter_cache_manager` caches the file; `just_audio` plays from cache.

### URL resolution
- **ALWAYS** resolve relative file URLs through `UrlUtils.resolveMediaUrl(url)`.
- If the URL is already absolute (starts with `http`), it is returned as-is.
- If relative, it is prepended with `AppConstants.apiBaseUrl`.
- **DO NOT** concatenate `apiBaseUrl + fileUrl` manually — use `resolveMediaUrl`.
- `Message.resolvedFileUrl` getter calls `UrlUtils.resolveMediaUrl(fileUrl ?? '')`.
- Use `msg.resolvedFileUrl` in widgets, **not** `msg.fileUrl`.

### Pending message replay
- `syncPendingMessages` replays all `pending` messages on socket reconnect.
- It **skips** media messages where `fileUrl` is null/empty (still uploading).
- After upload completes, `updateMessageMedia` sets `fileUrl`, making them eligible for replay.

---

## 5. Message Status Flow

### Status enum (ordered)
`pending (0) → sent (1) → delivered (2) → read (3) → error (-1)`

Status can only **increase** (never regress). `handleMessageStatusUpdate` enforces this via weight comparison.

### Sender-side flow
| Trigger | Transition |
|---|---|
| `_localDataSource.saveMessage` | → `pending` |
| `messageSent` socket event (server ACK) | `pending → sent` |
| `messageDelivered` socket event (recipient's device ACK) | `sent → delivered` |
| `messageRead` socket event (recipient opened the message) | `delivered → read` |
| Upload failure | → `error` |

### Recipient-side flow
1. `receiveMessage` / `newMessage` arrives → message saved as `delivered`.
2. `markDelivered` emitted immediately (always, regardless of room).
3. If `incoming.roomId == _activeRoomId`: `markRead` emitted + local status updated to `read`.
4. If NOT active room: status stays `delivered`; marked `read` when user opens the room via `markRoomMessagesRead`.

### `markRoomMessagesRead` (called on room open)
- Fetches all room messages from SQLite.
- Marks as `read` any message where `senderId != currentUserId` AND `status ∈ {sent, delivered}`.
- Emits `markRead` socket event for all such messages.
- **DO NOT** skip `sent` status — REST-synced messages arrive as `sent` and must be marked read.

### UI tick icons
- `pending`: clock icon
- `sent`: single check (grey)
- `delivered`: double check (grey)
- `read`: double check (blue)

---

## 6. Notification Lifecycle

### Initialization
- `PushNotificationService.init()` is called in `AuthCubit` after successful auth (both `verifyAuthStatus` and `submitOtp`).
- Requests permission, gets FCM token, registers token with backend (`POST /auth/device-token`).
- Sets up three stream subscriptions: `onTokenRefresh`, `onMessage` (foreground), `onMessageOpenedApp` (tap).

### Foreground notifications
- `handleForegroundMessage` uses `FlutterLocalNotificationsPlugin` to show a local notification.
- The `roomId` from `message.data['roomId']` is used as `groupKey` and notification payload.
- Tapping navigates to the chat room via `appRouter.push`.

### Background handler
- `firebaseMessagingBackgroundHandler` runs in an isolate — **DO NOT** do any UI work here.
- Backend shows the notification natively; no manual display needed in background.

### Logout cleanup (mandatory)
`PushNotificationService.dispose()` must be called on logout. It:
1. Cancels all three stream subscriptions.
2. `DELETE /auth/device-token` (unregisters FCM token from backend).
3. `FirebaseMessaging.instance.deleteToken()` (invalidates the token at Firebase).
4. `_localNotifications.cancelAll()` (clears pending notifications).

**DO NOT** leave FCM subscriptions active after logout — the user would receive notifications for another user's session.

---

## 7. Base URL

### Single source of truth
```dart
AppConstants.apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: '...')
```

- All HTTP clients (`DioClient`, `SocketService`, isolated `refreshDio`) **must** read from `AppConstants.apiBaseUrl`.
- **DO NOT** hardcode any base URL string anywhere else.
- The default value (ngrok URL) is for local development only; production sets `API_URL` at build time.

### ngrok header
All Dio instances must include `'ngrok-skip-browser-warning': 'true'` in headers to bypass ngrok's interception screen, which causes CORS errors.

---

## 8. Local-First Architecture

### SQLite is the UI's data source
- UI reads exclusively from SQLite streams (`watchRoomMessages`, `watchRecentChats`).
- Network data is always written to SQLite first, then the stream delivers it to the UI.
- **DO NOT** emit BLoC state directly from network responses — save to SQLite and let the stream update state.

### Optimistic messaging
- Every send method saves an optimistic `pending` message to SQLite **before** the network call.
- On network success: patch the bubble via `updateMessageMedia` or let `messageSent` promote the status.
- On network failure: update status to `error` and show a retry option.
- **DO NOT** wait for network confirmation before showing the message in the UI.

### Deduplication
- `saveMessage` uses `INSERT OR REPLACE` with `ConflictAlgorithm.ignore` on `client_message_id`.
- `onNewMessage` checks in-memory state for duplicate `clientMessageId` before saving.
- These two layers prevent duplicate bubbles on reconnect.

---

## 9. Dependency Injection Rules

- All services are `@lazySingleton` via `injectable` + `get_it`.
- Use `getIt<T>()` only from outside the DI tree (e.g., global callbacks, `main.dart`).
- Inside DI-constructed classes, use constructor injection.
- **DO NOT** call `getIt<AuthCubit>()` from within `ChatCubit` or vice versa — use callbacks/events to decouple.
- After any new `@lazySingleton` or `@injectable` annotation, run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `injection.config.dart`.
