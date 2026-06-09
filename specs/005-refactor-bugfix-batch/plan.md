# Implementation Plan: Comprehensive Refactoring & Bug Fix Batch

**Branch**: `003-optimize-chat-lifecycle` | **Date**: 2026-05-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-refactor-bugfix-batch/spec.md`

## Summary

Resolve 10 items of technical debt, crash-level bugs, performance bottlenecks, and architectural improvements across the routing, socket, data, and presentation layers. The changes span five groups: (1) routing crash fix via `GlobalKey<NavigatorState>` + hardcoded route elimination, (2) socket architecture via centralized event constants + typing/presence reliability fixes, (3) data layer polish via block payload audit, image URL resolution, and dead code purge, (4) media & waveform caching optimization to eliminate reload-on-scroll and slow media loading, (5) WhatsApp-style offline-first reactive message fetching for zero-loading-time room entry.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: `go_router`, `flutter_bloc`, `socket_io_client`, `dio`, `sqflite`, `cached_network_image`, `injectable`/`get_it`  
**Storage**: SQLite (`sqflite`) for messages/rooms/contacts, Hive for tokens  
**Testing**: Manual device testing (no unit test framework currently wired)  
**Target Platform**: Android / iOS  
**Project Type**: Mobile App (Flutter)  
**Constraints**: Offline-first, singleton socket, Clean Architecture  

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: All changes stay within correct layers. Dead code removal enforces layer purity.
- [x] **II. State Management**: Uses `flutter_bloc` (Cubit). Typing/presence state emitted via Cubit. States extend `Equatable`.
- [x] **III. Offline-First**: SQLite is the single source of truth for messages. Group 5 deepens this by making SQLite the **primary** read path (stream-first), with REST/socket sync writing into SQLite silently. Constitution fully upheld.
- [x] **IV. Socket.io**: Singleton `SocketService` preserved. New `SocketEvents` constants class centralizes event names. Idempotency maintained.
- [x] **V. Teardown**: Typing timers cleaned up on `closeRoom()`. `AutomaticKeepAliveClientMixin` ensures media widgets dispose correctly. No new subscriptions without cancel.
- [x] **Code Quality**: All new files use `snake_case`. Constants use `PascalCase` class with `camelCase` fields.
- [x] **Error Handling**: No changes to error handling patterns. Block user already uses `Either<Failure, void>`.

## Proposed Changes

### Group 1: Routing Architecture & Crash Fixes

---

#### [MODIFY] [app_router.dart](file:///e:/zeyad/ciro-chat-app/lib/core/routing/app_router.dart)
- Add `final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();` at top level.
- Inject into `GoRouter(navigatorKey: globalNavigatorKey, ...)`.
- Replace hardcoded route strings in the `redirect` block (lines 56-57, 71, 77) with `AppRouterName.*` constants.
- Remove the debug `/video` route and its hardcoded `'/video_call'` string (lines 108-117).

#### [MODIFY] [call_overlay.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/widgets/call_overlay.dart)
- Replace hardcoded `'/voice_call'` (line 86) with `AppRouterName.voiceCall`.

#### [MODIFY] [splash_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/splash/presentation/pages/splash_screen.dart)
- Replace `'/home'` → `AppRouterName.home` and `'/auth'` → `AppRouterName.auth` (lines 42, 44).

#### [MODIFY] [video_call_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/video_call/presentation/pages/video_call_screen.dart)
- Replace `'/home'` (line 210) with `AppRouterName.home`.

#### [MODIFY] [voice_call_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/video_call/presentation/pages/voice_call_screen.dart)
- Replace `'/video_call'` (line 264) with `AppRouterName.videoCall`.
- Replace `'/home'` (line 301) with `AppRouterName.home`.

#### [MODIFY] [outgoing_call_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/video_call/presentation/pages/outgoing_call_screen.dart)
- Replace `'/video_call'` (line 27) and `'/voice_call'` (line 33) with `AppRouterName.*`.

#### [MODIFY] [incoming_call_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/video_call/presentation/pages/incoming_call_screen.dart)
- Replace `'/video_call'` (line 35) and `'/voice_call'` (line 44) with `AppRouterName.*`.

#### [MODIFY] [chat_room_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/pages/chat_room_screen.dart)
- Replace `'/home'` (line 199) with `AppRouterName.home`.

#### [MODIFY] [chat_list_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/pages/chat_list_screen.dart)
- Replace `'/auth'` (line 60) with `AppRouterName.auth`.
- Replace `'/chat_room'` (line 278) with `AppRouterName.chatRoom`.

#### [MODIFY] [group_info_page.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/pages/group_info_page.dart)
- Replace `'/home'` (line 90) with `AppRouterName.home`.

#### [MODIFY] [create_group_page.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/pages/create_group_page.dart)
- Replace `'/home'` (line 70) with `AppRouterName.home`.

#### [MODIFY] [auth_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/auth/presentation/pages/auth_screen.dart)
- Replace `'/video_call'` (line 183) with `AppRouterName.videoCall`.

---

### Group 2: Socket Architecture & Real-Time Sync

---

#### [NEW] [socket_events.dart](file:///e:/zeyad/ciro-chat-app/lib/core/network/socket_events.dart)
- Create `SocketEvents` class with all 24 socket event string constants (see data-model.md).

#### [MODIFY] [socket_service.dart](file:///e:/zeyad/ciro-chat-app/lib/core/network/socket_service.dart)
- Import `socket_events.dart`.
- Replace all hardcoded event strings in `_socket?.on(...)` and `_socket?.emit(...)` calls with `SocketEvents.*` constants.

#### [MODIFY] [chat_cubit.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/bloc/chat_cubit.dart)
- **Typing fix**: In `onUserTyping` handler, add a per-user auto-expire timer (5s). When a `isTyping: true` event arrives, start/reset a `Timer` for that user. When the timer fires, remove the user from the typing set and re-emit `TypingUpdate`. This ensures typing indicators clear even if the `isTyping: false` event is lost.
- **Presence fix**: In `onUserStatusChanged` handler (line 117-119), after updating SQLite, check if the changed `userId` matches any participant in the active room. If so, emit a state update so the UI rebuilds with the new online status.
- **Typing cleanup**: In `closeRoom()`, also clear `_typingUsersByRoom[_activeRoomId]` to prevent stale typing state for the closed room.

---

### Group 3: Data Layer & API Polish

---

#### [MODIFY] [chat_info_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/pages/chat_info_screen.dart)
- In `_buildMediaSection()` (line 374), wrap `url` with a URL resolver that prepends the base URL when the path is relative (doesn't start with `http`).
- Import or inline the `resolveMediaUrl` utility.

#### [NEW] [url_utils.dart](file:///e:/zeyad/ciro-chat-app/lib/core/utils/url_utils.dart)
- Create `resolveMediaUrl(String url)` utility function.
- Reads base URL from `String.fromEnvironment('API_URL')` with the same default value used by `DioClient`.

#### [MODIFY] [chat_remote_data_source.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/data/datasources/chat_remote_data_source.dart)
- **Dead code removal**: Delete `connect()`, `disconnect()`, `sendMessage(String text)` from the abstract class (lines 16-18).
- Delete the empty implementations from `ChatRemoteDataSourceImpl` (lines 82-96).

#### [MODIFY] [chat_repository.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/domain/repositories/chat_repository.dart)
- **Dead code removal**: Delete `connect()`, `disconnect()`, `sendMessage(String text)` (lines 9-11).

#### [MODIFY] [chat_repository_impl.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/data/repositories/chat_repository_impl.dart)
- **Dead code removal**: Delete `connect()`, `disconnect()`, `sendMessage(String text)` overrides (lines 17-30).

---

### Group 4: Media & Waveform Performance Optimization

> **Goal**: Eliminate media reloading on scroll, slow image/video opens, and waveform recalculation. Achieve WhatsApp-level smoothness in the message list.

---

#### [MODIFY] [message_bubble_widget.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/widgets/message_bubble_widget.dart)

**4a. Convert `_VoiceBubble` to use `AutomaticKeepAliveClientMixin`**:
- Mixin `AutomaticKeepAliveClientMixin` into `_VoiceBubbleState`.
- Override `wantKeepAlive => true` so the widget's state (prepared player, cached waveform, playback position) survives ListView recycling.
- This eliminates the re-prepare/re-extract cycle that shows a spinner every time the user scrolls a voice note out and back in.

**4b. Pre-load waveform from `metadata['waveformSamples']` synchronously**:
- In `_VoiceBubbleState.initState()`, immediately check `message.metadata['waveformSamples']` and populate `_cachedWaveformData` before `_preparePlayer()` runs.
- If waveform data is already in metadata, render the static waveform bars **instantly** (no spinner) while the player prepares in the background.
- The current implementation already checks for this in `_preparePlayer()`, but the render path still shows a spinner until prepare completes. Decouple waveform display from player readiness.

**4c. Add `cacheKey` to `CachedNetworkImage` in `_ImageBubble` and `_VideoBubble`**:
- Add `cacheKey: message.id` (or `message.clientMessageId`) to all `CachedNetworkImage` usages.
- This ensures the disk cache is keyed by message ID, preventing redundant downloads when the same URL appears with different query params or the URL changes during upload resolution.

**4d. Increase `cacheExtent` on the `ListView.builder`** (in `chat_room_screen.dart`):
- Set `cacheExtent: 500.0` (or higher) on the `ListView.builder` at line 356.
- This pre-renders widgets slightly beyond the viewport, so images/voice notes don't visually "pop in" when scrolling.

#### [MODIFY] [chat_room_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/pages/chat_room_screen.dart)
- Add `cacheExtent: 500.0` to the `ListView.builder` (line 356) to keep more items rendered off-screen.
- Set `addAutomaticKeepAlives: true` (default, but make explicit) on the `ListView.builder`.

---

### Group 5: WhatsApp-Style Reactive Message Fetching (Zero Loading Time)

> **Goal**: Opening a chat room shows messages **instantly** from SQLite with zero loading state. API sync happens silently in the background and seamlessly updates the UI via the existing SQLite stream.

---

#### Current Architecture (Problem)

```
openRoom() → emit(ChatLoading) → watchRoomMessages(roomId) → [wait for stream] → emit(ChatRoomActive)
                                  ↑
                                  watchRoomMessages first does getRoomMessages() async → then returns stream
```

The `ChatLoading` state causes a visible `CircularProgressIndicator`. Even though `watchRoomMessages` kicks off an initial query, there's a brief async gap where the UI shows a spinner.

#### Target Architecture (Solution)

```
openRoom() → getRoomMessages(roomId) sync → emit(ChatRoomActive(cached)) → subscribe(watchRoomMessages)
                                                                            ↑
                                                              fetchRoomMessages(API) → saveMessage → stream auto-updates UI
```

#### [MODIFY] [chat_cubit.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/bloc/chat_cubit.dart)

**5a. Eliminate `ChatLoading` from `openRoom()`**:
- Remove `emit(ChatLoading())` (line 335).
- **Before** subscribing to the watch stream, do a synchronous `await getRoomMessages(roomId)` and immediately `emit(ChatRoomActive(roomId, cachedMessages))`.
- This ensures the UI **never** shows a loading spinner when opening a room — messages from SQLite appear instantly.

**5b. Background API sync**:
- The existing `fetchRoomMessages(roomId)` calls (lines 308-329) already run in the background and save to SQLite.
- After saving, `_dispatchUpdateForRoom(roomId)` already fires, which pushes new messages through the `watchRoomMessages` stream.
- The `BlocConsumer` in `ChatRoomScreen` already listens to `ChatRoomActive` state updates.
- **No additional work needed** — the current background sync is already wired correctly.

**5c. Pagination follows SQLite-first approach**:
- `loadMoreMessages()` already reads from SQLite via `getRoomMessages(roomId, offset: _messageOffset)`.
- For deeper history beyond local cache, add a fallback: if `getRoomMessages` returns fewer than `_pageSize` results AND the room has remote history, trigger a background `fetchOlderMessages(roomId, beforeTimestamp)` API call.
- Save fetched messages to SQLite → stream auto-updates the UI.

#### [MODIFY] [chat_room_screen.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/presentation/pages/chat_room_screen.dart)

**5d. Remove `ChatLoading` handling from the `BlocConsumer`**:
- The `builder:` block at line 344 currently returns `CircularProgressIndicator` for `ChatLoading` state.
- Replace with: if no messages are available yet (empty `ChatRoomActive`), show an empty state or a subtle "catching up..." text — **never** a full-screen spinner.
- Update `listenWhen` (line 336) to stop listening for `ChatLoading`.

#### [MODIFY] [chat_local_data_source.dart](file:///e:/zeyad/ciro-chat-app/lib/features/chat/data/datasources/chat_local_data_source.dart)

**5e. Optimize `watchRoomMessages` for instant first emission**:
- The current implementation (line 595-604) creates a broadcast `StreamController`, calls `getRoomMessages` async, and pushes results.
- Refactor to emit the initial batch synchronously in the stream setup using `StreamController.onListen` callback so the subscriber gets data on the same microtask.

---

## Project Structure

### Documentation (this feature)

```text
specs/005-refactor-bugfix-batch/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── spec.md              # Feature specification
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code Changes

```text
lib/
├── core/
│   ├── network/
│   │   ├── socket_events.dart         [NEW]  — Socket event constants
│   │   ├── socket_service.dart        [MOD]  — Use SocketEvents.*
│   │   └── dio_client.dart            (unchanged)
│   ├── routing/
│   │   └── app_router.dart            [MOD]  — GlobalKey + route string cleanup
│   └── utils/
│       └── url_utils.dart             [NEW]  — resolveMediaUrl utility
├── features/
│   ├── auth/presentation/pages/
│   │   └── auth_screen.dart           [MOD]  — Route constant
│   ├── chat/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── chat_remote_data_source.dart  [MOD]  — Dead code removal
│   │   │   │   └── chat_local_data_source.dart   [MOD]  — Stream optimization (G5)
│   │   │   └── repositories/
│   │   │       └── chat_repository_impl.dart     [MOD]  — Dead code removal
│   │   ├── domain/repositories/
│   │   │   └── chat_repository.dart              [MOD]  — Dead code removal
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── chat_cubit.dart               [MOD]  — Typing/presence + zero-load openRoom (G2+G5)
│   │       ├── pages/
│   │       │   ├── chat_info_screen.dart          [MOD]  — Image URL fix
│   │       │   ├── chat_list_screen.dart          [MOD]  — Route constants
│   │       │   ├── chat_room_screen.dart          [MOD]  — Route const + cacheExtent + no loading (G1+G4+G5)
│   │       │   ├── create_group_page.dart         [MOD]  — Route constant
│   │       │   └── group_info_page.dart           [MOD]  — Route constant
│   │       └── widgets/
│   │           ├── call_overlay.dart              [MOD]  — Route constant
│   │           └── message_bubble_widget.dart     [MOD]  — KeepAlive + cacheKey + waveform instant (G4)
│   ├── splash/presentation/pages/
│   │   └── splash_screen.dart                    [MOD]  — Route constants
│   └── video_call/presentation/pages/
│       ├── incoming_call_screen.dart              [MOD]  — Route constants
│       ├── outgoing_call_screen.dart              [MOD]  — Route constants
│       ├── video_call_screen.dart                 [MOD]  — Route constant
│       └── voice_call_screen.dart                 [MOD]  — Route constants
```

## Verification Plan

### Automated Tests
- `grep -rn "'/home'\|'/auth'\|'/video_call'\|'/voice_call'\|'/chat_room'\|'/incoming_call'\|'/outgoing_call'" lib/` returns zero matches (outside `AppRouterName` definitions).
- `grep -rn "'messageSent'\|'receiveMessage'\|'sendMessage'\|'typing'\|'joinRoom'" lib/core/network/socket_service.dart` returns zero hardcoded strings (only `SocketEvents.*` references).
- `grep -rn "connect()\|disconnect()\|sendMessage(String" lib/features/chat/domain/repositories/chat_repository.dart lib/features/chat/data/` confirms dead methods removed.
- `grep -rn "ChatLoading" lib/features/chat/presentation/pages/chat_room_screen.dart` returns zero matches (Group 5 verification).
- `grep -rn "AutomaticKeepAliveClientMixin" lib/features/chat/presentation/widgets/message_bubble_widget.dart` confirms keepalive is applied (Group 4 verification).

### Manual Verification
- Initiate a video/voice call from `ChatRoomScreen` → verify no crash.
- Receive an incoming call while on any screen → verify `CallOverlay` navigates correctly.
- Two-device test: User A types → User B sees "typing…" in both chat room and chat list → User A stops → indicator clears within 5s.
- Two-device test: User B goes offline → User A sees status change within 5s.
- Block a user from `ChatInfoScreen` → inspect network request confirms user ID in path.
- Open `ChatInfoScreen` with shared media → verify images load correctly.
- Build app → verify no compilation errors from removed dead code.

### Group 4 Verification (Media Performance)
- Scroll a voice note message out of the viewport and back in → waveform renders instantly with no spinner.
- Scroll an image message out and back in → image appears instantly from cache with no reload flicker.
- Open a chat with 50+ messages including images → smooth scroll at 60fps with no jank.
- Tap an image message → full-screen viewer opens immediately from cache.

### Group 5 Verification (Zero Loading Time)
- Open a chat room that has messages in SQLite → messages appear **instantly** with zero `CircularProgressIndicator`.
- Open a chat room while offline → cached messages display. Online sync happens when connectivity resumes.
- Send a message, close the room, reopen → new message is visible instantly from SQLite.
- Open a chat that has new messages on the server but not yet in SQLite → cached messages show first, new messages seamlessly append as the background sync completes.
- Scroll up to load older messages → older messages appear from SQLite; if more exist on the server, they sync in the background.
