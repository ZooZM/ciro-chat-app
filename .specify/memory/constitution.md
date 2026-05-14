<!--
Sync Impact Report:
- Version change: 1.1.0 → 1.2.0
- Modified principles:
  - III. Data Storage: corrected storage engine for credentials/tokens (Hive → FlutterSecureStorage)
  - IV. Real-Time Communication: added Socket.IO Map type-safety rule, presence system, token-refresh lifecycle
  - V. Memory Leak Prevention: expanded logout teardown to cover PushNotificationService and socket refresh redirect
- Added sections:
  - VIII. Media Handling & URL Resolution (new principle)
  - IX. Message Status Flow (new principle)
- Templates requiring updates:
  - ✅ updated: .specify/memory/constitution.md
  - ✅ updated: .specify/templates/plan-template.md (Constitution Check items corrected)
  - ⚠ pending: .specify/templates/spec-template.md (no structural change needed)
  - ⚠ pending: .specify/templates/tasks-template.md (no structural change needed)
- Deferred TODOs:
  - RATIFICATION_DATE for v1.0.0 preserved as 2026-04-23 (original)
-->

# Ciro Chat App Constitution

This document is the absolute source of truth for architectural, structural, and
behavioral patterns within the Ciro Chat App codebase. All AI assistants and human
developers MUST adhere strictly to these rules. Where this document conflicts with any
other file (README, comments, PR description), this document wins.

The `speckit-constitution.md` at the repository root is a complementary runtime quick-
reference (auth flows, socket event catalogue, URL rules). This document governs
structure and process; that file governs implementation invariants. Both MUST stay
consistent.

## Core Principles

### I. Strict Clean Architecture

The project enforces Clean Architecture to ensure separation of concerns, testability,
and independence from UI frameworks. Each feature MUST be encapsulated in its own
directory, strictly divided into three layers:

- **Presentation** (`presentation/`): UI pages/widgets + BLoC (Cubit). Widgets MUST NOT
  contain business logic.
- **Domain** (`domain/`): Entities and abstract repositories. MUST NOT depend on Flutter,
  external packages (except `equatable`), or other layers.
- **Data** (`data/`): Models (DTOs), datasources (local/remote), repository
  implementations.

#### Feature Folder Structure

```text
lib/
  core/
    di/
    error/
    network/
    routing/
    services/
    theme/
    utils/
  features/
    [feature_name]/
      data/
        datasources/
        models/
        repositories/
      domain/
        entities/
        repositories/
      presentation/
        bloc/
        pages/
        widgets/
```

### II. State Management: flutter_bloc (Cubit)

- **Cubit over Bloc**: Use `Cubit` unless complex stream transformations require `Bloc`.
- **State Classes**: MUST extend `Equatable`. Equality is used by `BlocBuilder` to
  suppress redundant rebuilds.
- **Single Responsibility**: Each Cubit manages one feature or logical UI unit.
- **Dependency Injection**: Dependencies MUST arrive via constructor injection (`get_it` +
  `injectable`). Cubits MUST NOT call `getIt<>()` internally except for cross-cutting
  singletons explicitly listed in `core/di/`.
- **State Promotion Rule**: Status fields (e.g. `MessageStatus`) MUST only move
  forward — never regress. Compare weights before emitting.

### III. Data Storage: Offline-First

The app MUST function without a network connection. SQLite is the UI's data source;
network data flows into SQLite first, and streams deliver it to the UI.

| Storage Engine | Approved Use |
|---|---|
| **sqflite** | Relational, heavily-queried data: Messages, Rooms, Contacts |
| **FlutterSecureStorage** | Sensitive credentials: access token, refresh token, userId, phone |
| **SharedPreferences** | Lightweight boolean flags and user preferences (mute/lock per room) |

> **Hive is NOT used in this project.** Do NOT introduce it.

**Offline Queue**: Write operations performed offline MUST be saved locally with
`pending` status and replayed via `syncPendingMessages` on reconnect.

**Deduplication**: `saveMessage` uses `INSERT OR REPLACE` with `ConflictAlgorithm.ignore`
on `clientMessageId`. The `onNewMessage` handler MUST also check in-memory state for
duplicates before saving.

**Optimistic Writes**: Every send method saves an optimistic `pending` bubble to SQLite
BEFORE any network call. On success, patch via `updateMessageMedia`. On failure, update
status to `error` and surface a retry option.

### IV. Real-Time Communication: Socket.IO

- **Singleton**: One `SocketService` instance, managed by `get_it`.
- **Transport**: WebSocket only (`setTransports(['websocket'])`). SSE/polling MUST NOT
  be enabled.
- **Auth**: Token passed via `setAuth({'token': token})`, NOT the Authorization header.
- **Lifecycle**: Connect immediately after auth verification; disconnect on
  `AppLifecycleState.paused` / `detached` / logout. Reconnect on `resumed` if not
  connected.
- **Event Delegation**: `SocketService` exposes typed callbacks (e.g. `onNewMessage`).
  MUST NOT contain UI or business logic.
- **Idempotency**: The frontend MUST handle duplicate events gracefully (dedup on
  `clientMessageId`).

#### IV-A. Socket.IO Map Type-Safety Rule (Critical)

> This rule was established after two confirmed production incidents where silent
> `_CastError` exceptions caused `messageSent` and `userTyping` events to be silently
> dropped.

Socket.IO-client Dart delivers event payloads as **`Map<dynamic, dynamic>`**, NOT
`Map<String, dynamic>`. The following patterns MUST NOT appear in any socket event
handler:

```dart
// ❌ FORBIDDEN — both throw silent _CastError at runtime
data as Map<String, dynamic>
data is Map<String, dynamic>
```

The correct pattern for every `_socket?.on(...)` handler:

```dart
// ✅ REQUIRED
if (data == null || data is! Map) return;
final map = Map<String, dynamic>.from(data);
final value = map['key']?.toString();
```

#### IV-B. Presence System

- The backend marks a user **online** in `handleConnection` and **offline** in
  `handleDisconnect`.
- On connect, the backend MUST broadcast `userStatus { userId, isOnline: true }` to all
  of the user's room members. On disconnect, broadcast `userStatus { userId, isOnline: false }`.
- The Flutter `onUserStatusChanged` callback updates `chat_sessions` in SQLite.
- Do NOT add a mutable `isOnline` field to any Flutter singleton — the backend is the
  single source of truth.

#### IV-C. Token Refresh Lifecycle

| Trigger | Actor | Behaviour |
|---|---|---|
| HTTP 401 response | `DioClient` interceptor | Uses isolated `refreshDio` to call `POST /auth/refresh`; retries original request |
| Socket connect error / disconnect with JWT reason | `SocketService._handleTokenRefresh` | Same isolated refresh flow; reconnects socket on success |
| App start (token near expiry, < 5 min) | `AuthCubit._proactiveTokenRefreshIfNeeded` | Decodes JWT `exp`, refreshes before socket connect |
| Any refresh failure | Both actors | MUST call `deleteTokens()` then `globalOnUnauthorizedRedirect?.call()` |

`globalOnUnauthorizedRedirect` is declared in `dio_client.dart`. Import it with
`show globalOnUnauthorizedRedirect` to avoid the full DioClient dependency.

### V. Memory Leak Prevention & Logout Teardown

- **StreamSubscription**: ALL subscriptions MUST be `.cancel()`ed in `close()` /
  `dispose()`.
- **Controllers**: All `TextEditingController`, `ScrollController`, etc. MUST be
  disposed in `dispose()`.
- **Async Gap Safety**: Check `if (!mounted) return;` before calling `setState` or
  using `BuildContext` after any `await`.
- **Typing Timers**: `ChatCubit` MUST cancel all `_typingTimer` and
  `_incomingTypingTimers` entries in `close()`.

#### V-A. Global Logout Sequence (Mandatory Order)

```
1. ChatCubit.reset()
2. CallCubit.reset()
3. SocketService.disconnect()
4. PushNotificationService.dispose()   ← cancels subscriptions + unregisters FCM token
5. ChatLocalDataSource.clearAllData()
6. AuthLocalDataSource.deleteTokens()
```

Deviating from this order risks race conditions (e.g. push arriving after token cleared).

#### V-B. Push Notification Teardown

`PushNotificationService.dispose()` MUST:
1. Cancel `_tokenRefreshSub`, `_foregroundSub`, `_notificationTapSub`.
2. Call `DELETE /auth/device-token` to unregister the FCM token server-side.
3. Call `FirebaseMessaging.instance.deleteToken()` to invalidate at Firebase.
4. Call `_localNotifications.cancelAll()` to clear pending banners.

### VI. Code Formatting & Dart Lints

- **Strict Linting**: `flutter_lints` is the baseline; all warnings are treated as
  errors in CI.
- **Immutability**: Prefer `const` constructors and `final` variables.
- **Naming**: `PascalCase` for classes, `camelCase` for methods/variables,
  `snake_case` for files and folders.
- **Comments**: Default to no comments. Add one only when the WHY is non-obvious (a
  hidden constraint, workaround for a specific bug, subtle invariant). Never describe
  WHAT the code does.

### VII. Error Handling

- **Structured Errors**: The Data layer MUST catch exceptions and map them to domain
  `Failure` subclasses (`ServerFailure`, `CacheFailure`, `AuthFailure`).
- **Return Types**: Repository methods MUST return `Either<Failure, T>` (using
  `fpdart`).
- **User Feedback**: Presentation layer listens for error states and displays user-
  friendly `SnackBar`s or `Dialog`s. Raw exception messages MUST NOT be shown to users.
- **Silent Failures**: Fire-and-forget operations (e.g. contact sync) MUST log errors
  with `debugPrint` and NOT emit error states that disrupt the UI.

### VIII. Media Handling & URL Resolution

#### VIII-A. URL Resolution (Non-Negotiable)

All media URLs from the backend may be relative paths (e.g. `/uploads/file.mp4`).

- ALWAYS resolve via `UrlUtils.resolveMediaUrl(url)` or `Message.resolvedFileUrl`.
- NEVER concatenate `AppConstants.apiBaseUrl + fileUrl` manually.
- If the URL is already absolute (`http`/`https` prefix), `resolveMediaUrl` returns
  it unchanged.

#### VIII-B. Base URL Source

```dart
AppConstants.apiBaseUrl   // single source; reads from dotenv .env file first,
                          // then --dart-define=API_URL, then hardcoded default
```

Update the `.env` file in the project root to change the base URL for development. The
`.env` file is loaded via `flutter_dotenv` in `main()` before any other initialization.
NEVER hardcode a URL string outside `AppConstants`.

#### VIII-C. Image & Video Rendering

| Media Type | Widget | Rule |
|---|---|---|
| Remote image | `CachedNetworkImage` | NEVER `Image.network` |
| Remote video | `DefaultCacheManager().getSingleFile(url)` → `VideoPlayerController.file` | NEVER `VideoPlayerController.networkUrl` — it re-downloads on every open |
| Local image | `Image.file(File(path))` | From `metadata['localPath']` |
| Local video | `VideoPlayerController.file(File(path))` | From `metadata['localPath']` |

While a video is initializing (async `VideoPlayerController.initialize`), display the
thumbnail from `metadata['localThumbPath']` or `metadata['thumbnailUrl']` with a spinner
overlay. NEVER show a blank `CircularProgressIndicator` with no visual context.

### IX. Message Status Flow

#### IX-A. Status Enum (strictly ordered, no regression)

```
pending (0) → sent (1) → delivered (2) → read (3) | error (-1)
```

`handleMessageStatusUpdate` enforces this via weight comparison. A status update MUST be
ignored if the incoming weight ≤ the current weight.

#### IX-B. Sender-Side Transitions

| Socket Event Received | Transition |
|---|---|
| `messageSent` (server ACK) | `pending → sent` |
| `messageDelivered` (recipient device ACK) | `sent → delivered` |
| `messageRead` (recipient opened message) | `delivered → read` |
| Upload failure | `pending → error` |

#### IX-C. Recipient-Side Obligations

1. On `receiveMessage` / `newMessage`: save as `delivered`, emit `markDelivered`
   immediately.
2. If `incoming.roomId == _activeRoomId`: emit `markRead` AND call
   `updateMessageStatus(incoming.clientMessageId, MessageStatus.read)`. Use
   `clientMessageId`, NOT `id` (the MongoDB ID).
3. On room open (`markRoomMessagesRead`): mark ALL messages where
   `senderId != currentUserId` AND `status ∈ {sent, delivered}` as `read`. MUST include
   `sent` status — REST-synced messages arrive as `sent` and would otherwise never be
   acknowledged.

#### IX-D. Pending Message Replay

`syncPendingMessages` MUST skip media messages where `fileUrl` is null/empty (still
uploading). After upload completes, `updateMessageMedia` sets `fileUrl`, making the
message eligible for replay on the next reconnect cycle.

## Governance

This Constitution supersedes all other practices. Amendments require:
1. A PR updating this file and the `speckit-constitution.md` quick-reference together.
2. The Sync Impact Report (HTML comment at top of this file) updated to reflect all
   changes.
3. Any affected `.specify/templates/*.md` files updated in the same PR.
4. Version incremented per semantic versioning: MAJOR for incompatible removals,
   MINOR for additions, PATCH for clarifications.

All PRs and reviews MUST include a Constitution Check (see `plan-template.md`).

**Version**: 1.2.0 | **Ratified**: 2026-04-23 | **Last Amended**: 2026-05-14
