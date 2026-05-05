# Research: Refactoring & Bug Fix Batch

**Date**: 2026-05-05  
**Feature**: `005-refactor-bugfix-batch`

## R1: GoRouter Context in Overlays

**Decision**: Inject a `GlobalKey<NavigatorState>` (`globalNavigatorKey`) into the `GoRouter` configuration via the `navigatorKey` parameter. Use `globalNavigatorKey.currentContext!` for contextless navigation from `CallOverlay` and any other overlay/service.

**Rationale**: GoRouter's `navigatorKey` parameter is the officially supported mechanism for resolving router context outside the widget tree. The `CallOverlay` currently wraps `MaterialApp.router` at the top level in `main.dart`, meaning its `BlocListener` context is **above** the `Router` widget and therefore has no `GoRouter` ancestor.

**Alternatives considered**:
- `Navigator.of(context)` with `GlobalKey`: Would bypass GoRouter entirely, breaking deep-linking and redirect guards.
- Moving `CallOverlay` inside the `MaterialApp.router` builder: Would require restructuring `main.dart` and may lose call events during route transitions.

## R2: Hardcoded Route Strings

**Decision**: `AppRouterName` already exists and contains all route constants. The fix is to replace ~20 remaining hardcoded string literals with their `AppRouterName.*` equivalents.

**Rationale**: The constants class is already defined. Files still using raw strings: `splash_screen.dart`, `video_call_screen.dart`, `voice_call_screen.dart`, `outgoing_call_screen.dart`, `incoming_call_screen.dart`, `chat_room_screen.dart`, `chat_list_screen.dart`, `group_info_page.dart`, `create_group_page.dart`, `call_overlay.dart`, `app_router.dart` (redirect block), `auth_screen.dart`.

**Alternatives considered**: None — this is pure mechanical substitution.

## R3: Socket Event Constants

**Decision**: Create `SocketEvents` class in `lib/core/network/socket_events.dart` with `static const String` entries for every listener and emitter event name.

**Rationale**: The `SocketService` currently uses ~20 distinct hardcoded event strings (`'messageSent'`, `'receiveMessage'`, `'typing'`, `'joinRoom'`, etc.). A single typo in any of these silently breaks the feature.

**Alternatives considered**:
- Enum with `.name` accessor: Rejected because event names must match backend strings exactly; enum names have Dart naming constraints.

## R4: Typing Indicator Bugs

**Decision**: The current implementation has two issues:
1. **No debounce-timeout clear on receiver**: When a user stops typing without explicitly sending `isTyping: false` (e.g., navigating away), the typing indicator stays forever. Add a client-side auto-expire timer (~5s) per user per room.
2. **Chat list `isTyping` flag is correctly wired** via `StreamBuilder` on `allTypingUsersStream`, but the `_typingUsersByRoom` set is never cleaned on room close or when `openRoom` is called for a different room. Fix: clear stale entries on `closeRoom()`.

**Rationale**: The sender side (`ChatInputBar`) correctly debounces at 2s and emits `isTyping: false`. But if the socket drops or the sender navigates away without the timer firing, the receiver never gets the `false` event.

**Alternatives considered**: Server-side typing TTL — good long-term, but client-side safety net is needed regardless.

## R5: Presence Sync

**Decision**: The `onUserStatusChanged` callback in `ChatCubit._initServices()` correctly calls `_localDataSource.updateUserOnlineStatus()`. The bug is that this only updates the SQLite layer — there is no reactive stream / state emission that causes the UI (ChatRoomScreen, ChatInfoScreen) to rebuild when `isOnline` changes for the currently-viewed user.

Fix: After `updateUserOnlineStatus`, if the active room's participant matches the changed userId, emit a state update (e.g., update `ChatRoomActive` with new online status or use a `ValueNotifier`).

**Rationale**: The `ChatSession.isOnline` field is read at widget build time from the initial data, but never updated reactively.

**Alternatives considered**: Dedicated `PresenceCubit` — overkill for P2P; can revisit later if needed.

## R6: Block User Payload

**Decision**: Audit shows the block flow is already correct at the API level — `blockUser(targetUserId)` passes the user ID through the call chain. The actual bug is upstream: `chat_info_screen.dart` line 568-571 correctly resolves `targetId` from `participants` (which are user IDs). However, the `ChatInfoScreen.chatData.phoneNumber` is used for call initiation (lines 224, 234), which is a separate concern. The block payload itself already sends the ID in the URL path `/chat/block/{targetUserId}`.

After re-checking: The block API path uses `targetUserId` which resolves correctly. **If the user reports this as broken**, the bug may be in the `participants` list containing phone numbers instead of IDs for legacy rooms. Verify and fix `ChatSession.fromJson` participant parsing if needed.

**Rationale**: Defense-in-depth — ensure `participants` always contains user IDs.

## R7: Image URL Resolution

**Decision**: In `chat_info_screen.dart` line 374, `CachedNetworkImage(imageUrl: url)` uses the raw `msg.fileUrl` value. If the server returns a relative path (e.g., `/uploads/abc.jpg`) instead of a full URL, the image fails. Prepend `DioClient`'s base URL when the URL doesn't start with `http`.

The base URL is available from `DioClient._dio.options.baseUrl` or can be centralized as a static constant in `AppConstants` or extracted from the `String.fromEnvironment('API_URL')`.

**Rationale**: Simplest fix — create a URL resolver utility that conditionally prepends the base URL.

**Alternatives considered**: Always returning absolute URLs from the server — ideal but requires backend change.

## R8: Dead Code

**Decision**: Remove `connect()`, `disconnect()`, and `sendMessage(String text)` from:
1. `ChatRemoteDataSource` (abstract) — lines 16-18
2. `ChatRemoteDataSourceImpl` — lines 82-96
3. `ChatRepository` (abstract) — lines 9-11
4. `ChatRepositoryImpl` — lines 17-30

Keep `messageStream` as it's still actively used by the data source constructor.

**Rationale**: These methods are empty stubs left over from the initial architecture. `SocketService` handles all socket operations directly. Their presence violates the constitution's Clean Architecture principle by implying responsibilities the data source doesn't actually fulfill.

**Alternatives considered**: None — pure deletion.
