# Data Model: Refactoring & Bug Fix Batch

**Date**: 2026-05-05  
**Feature**: `005-refactor-bugfix-batch`

> This feature is primarily a refactoring/bug-fix batch. No new database entities are introduced. The following documents the **new constant classes** and **modified entities** involved.

## New Constants Classes

### SocketEvents

A centralized constants class for all socket event name strings.

| Constant Name           | Value                | Direction | Used By              |
|------------------------|----------------------|-----------|----------------------|
| `messageSent`          | `'messageSent'`      | Listen    | SocketService        |
| `messageDelivered`     | `'messageDelivered'`  | Listen    | SocketService        |
| `messageRead`          | `'messageRead'`      | Listen    | SocketService        |
| `receiveMessage`       | `'receiveMessage'`    | Listen    | SocketService        |
| `newMessage`           | `'newMessage'`        | Listen    | SocketService        |
| `userTyping`           | `'userTyping'`        | Listen    | SocketService        |
| `incomingCall`         | `'incomingCall'`      | Listen    | SocketService        |
| `callAccepted`         | `'callAccepted'`      | Listen    | SocketService        |
| `callRejected`         | `'callRejected'`      | Listen    | SocketService        |
| `userStatus`           | `'userStatus'`        | Listen    | SocketService        |
| `statusReceived`       | `'statusReceived'`    | Listen    | SocketService        |
| `messageDeleted`       | `'messageDeleted'`    | Listen    | SocketService        |
| `joinRoom`             | `'joinRoom'`          | Emit      | SocketService        |
| `typing`               | `'typing'`            | Emit      | SocketService        |
| `sendMessage`          | `'sendMessage'`       | Emit      | SocketService        |
| `markDelivered`        | `'markDelivered'`     | Emit      | SocketService        |
| `markRead`             | `'markRead'`          | Emit      | SocketService        |
| `requestCall`          | `'requestCall'`       | Emit      | SocketService        |
| `acceptCall`           | `'acceptCall'`        | Emit      | SocketService        |
| `rejectCall`           | `'rejectCall'`        | Emit      | SocketService        |
| `endCall`              | `'endCall'`           | Emit      | SocketService        |
| `uploadStatus`         | `'uploadStatus'`      | Emit      | SocketService        |
| `statusViewed`         | `'statusViewed'`      | Emit      | SocketService        |
| `deleteForEveryone`    | `'deleteForEveryone'`  | Emit      | SocketService        |

### AppRouterName (existing — no new constants needed)

Already defined in `lib/core/routing/app_router.dart`. All route constants already present. The fix is purely replacing hardcoded strings elsewhere.

## Modified Entities

### GlobalNavigatorKey

New top-level variable in `lib/core/routing/app_router.dart`:

```
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();
```

Injected into `GoRouter(navigatorKey: globalNavigatorKey, ...)`.

## Removed Methods (Dead Code)

### ChatRemoteDataSource (abstract)

- `Future<void> connect()`
- `Future<void> disconnect()`
- `void sendMessage(String text)`

### ChatRemoteDataSourceImpl

- `connect()` — empty body
- `disconnect()` — empty body  
- `sendMessage(String text)` — empty body

### ChatRepository (abstract)

- `Future<void> connect()`
- `Future<void> disconnect()`
- `Future<void> sendMessage(String text)`

### ChatRepositoryImpl

- `connect()` — delegates to empty datasource method
- `disconnect()` — delegates to empty datasource method
- `sendMessage(String text)` — delegates to empty datasource method

## URL Resolution Utility

New helper (or inline logic) to resolve media URLs:

```
String resolveMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConstants.apiBaseUrl}$url';
}
```

Requires adding `apiBaseUrl` to `AppConstants` or reading from `DioClient`.
