# Implementation Plan: Optimize Chat Lifecycle (P2P Focus)

**Branch**: `003-optimize-chat-lifecycle` | **Date**: 2026-04-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-optimize-chat-lifecycle/spec.md`

## Summary

Refactor the P2P chat module to achieve WhatsApp-grade reliability and UX. The scope covers 5 critical infrastructure fixes (infinite scroll pagination, message idempotency, scoped inbox status, atomic JIT room creation, dual-mode message deletion), 3 UI improvements (Poll/Event bubble refactors, SharedMediaScreen, voice waveform optimization), and ensures alignment with the project's offline-first constitution. All changes target the existing Clean Architecture layers without requiring schema migrations beyond adding `is_deleted` and `last_message_id` columns.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x
**Primary Dependencies**: `flutter_bloc` (Cubit), `sqflite`, `socket.io-client`, `dio`, `audio_waveforms`, `cached_network_image`, `get_it`/`injectable`
**Storage**: SQLite (`ciro_chat.db_v1`) — tables: `messages`, `rooms`, `contacts`, `statuses`
**Testing**: `flutter test`, manual device testing, `flutter analyze`
**Target Platform**: Android (primary), iOS
**Project Type**: Mobile app (Flutter)
**Performance Goals**: Chat list renders <500ms, message pagination loads 30 messages per batch, waveform renders without extraction delay
**Constraints**: Offline-capable, <200ms p95 for local SQLite queries, socket reconnect resilience
**Scale/Scope**: ~50 screens, single-user app, message history up to 10,000 per room

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature is split into `presentation`, `domain`, and `data` layers? ✅ All changes follow existing layer boundaries.
- [x] **II. State Management**: Uses `flutter_bloc` (Cubit preferred)? States extend `Equatable`? ✅ ChatCubit is the single state manager.
- [x] **III. Offline-First**: Relational data uses `sqflite`? Key-value uses `Hive`? ✅ All message/room data persisted to SQLite first.
- [x] **IV. Socket.io**: Real-time logic uses singleton `SocketService`? Events are idempotent? ✅ FR-019 specifically adds idempotency guards.
- [x] **V. Teardown**: Proper `dispose`/`cancel` implemented? Logout sequence handled? ✅ All new StreamControllers will follow existing disposal pattern.
- [x] **Code Quality**: Strict linting followed? Naming conventions (snake_case files) met? ✅
- [x] **Error Handling**: Exceptions mapped to `Failure` classes in Data layer? ✅

## Project Structure

### Documentation (this feature)

```text
specs/003-optimize-chat-lifecycle/
├── plan.md              # This file
├── research.md          # Phase 0 output (updated)
├── data-model.md        # Phase 1 output (updated)
├── quickstart.md        # Phase 1 output (updated)
├── contracts/
│   ├── block-user-api.md       # Existing
│   ├── socket-events.md        # Existing (updated)
│   ├── pagination-api.md       # NEW: Pagination query contracts
│   └── atomic-resolve-api.md   # NEW: Atomic room creation endpoint
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── bloc/
│   ├── di/
│   ├── helpers/
│   ├── network/          # SocketService singleton
│   ├── routing/
│   ├── services/          # LocationService
│   └── theme/             # AppColors, AppTypography, AppConstants
└── features/
    └── chat/
        ├── data/
        │   ├── datasources/   # ChatLocalDataSource, ChatRemoteDataSource
        │   ├── models/
        │   └── repositories/
        ├── domain/
        │   ├── entities/      # Message, ChatSession
        │   └── repositories/
        └── presentation/
            ├── bloc/          # ChatCubit, VoiceNoteController
            ├── pages/         # ChatRoomScreen, ChatInfoScreen, SharedMediaScreen (NEW)
            └── widgets/       # MessageBubble, ChatInputBar, ChatTileWidget
```

**Structure Decision**: All new code fits within the existing `lib/features/chat/` feature folder. One new page (`SharedMediaScreen`) and two new dialog widgets (`CreatePollDialog`, `CreateEventDialog`) are added. No new feature directories needed.

## Detailed Change Plan

### Phase A — Message Idempotency & Status Fixes (FR-019, FR-020)

**Priority: P0 (Critical — must ship first)**

These are data-integrity bugs that affect every message exchange.

#### A1: `ChatLocalDataSource` — Idempotent Insert + Monotonic Status

**File**: `lib/features/chat/data/datasources/chat_local_data_source.dart`

| Change | Description |
|--------|-------------|
| `saveMessage()` | Before `INSERT OR REPLACE`, query by `clientMessageId`. If row exists, skip insert (return early). |
| `updateMessageStatus()` | Change query from `WHERE id = ?` to `WHERE client_message_id = ?`. Add monotonic guard: fetch current status rank, compare with incoming rank, skip if incoming ≤ current. |
| `updateMessageStatus()` | Before updating `rooms.lastMessageStatus`, compare `messageId` with `rooms.last_message_id`. Only update room if they match. |
| Schema helper | Add `_statusRank()` method: `pending=0, sent=1, delivered=2, read=3`. |

#### A2: `ChatCubit` — Fix Status Handler

**File**: `lib/features/chat/presentation/bloc/chat_cubit.dart`

| Change | Description |
|--------|-------------|
| `handleMessageStatusUpdate()` | Pass `clientMessageId` instead of `id` to `updateMessageStatus()`. |
| `_handleIncomingMessage()` | Add dedup check: if `clientMessageId` already in current `state.messages`, skip. |

#### A3: `rooms` Schema — Add `last_message_id` + `last_message_sender_id`

**File**: `lib/features/chat/data/datasources/chat_local_data_source.dart`

| Change | Description |
|--------|-------------|
| `_roomsSchema` | Add `last_message_id TEXT DEFAULT ''` and `last_message_sender_id TEXT DEFAULT ''` columns. |
| `initDB()` | Add `ALTER TABLE` migration for existing DBs. |
| `saveMessage()` | Set `last_message_id` and `last_message_sender_id` during room upsert. |

#### A4: `ChatTileWidget` — Sender-Scoped Ticks

**File**: `lib/features/chat/presentation/widgets/chat_tile_widget.dart` (or equivalent inbox widget)

| Change | Description |
|--------|-------------|
| Tick icon rendering | Only show tick icons when `lastMessageSenderId == currentUserId`. Hide for received messages. |

---

### Phase B — Infinite Scroll Pagination (FR-018)

**Priority: P0 (Critical — data loss prevention)**

#### B1: `ChatLocalDataSource` — Offset-Based Query

| Change | Description |
|--------|-------------|
| `getRoomMessages()` | Add `{int limit = 30, int offset = 0}` parameters. SQL: `ORDER BY timestamp DESC LIMIT ? OFFSET ?` |
| `watchRoomMessages()` | Accept `limit` param. Initial emission uses `LIMIT 30`. Subsequent triggers append. |

#### B2: `ChatCubit` — Pagination State

| Change | Description |
|--------|-------------|
| New fields | `int _messageOffset = 0`, `bool _hasMoreMessages = true`, `bool _isLoadingMore = false` |
| `loadMoreMessages()` | New method: if `_hasMoreMessages && !_isLoadingMore`, fetch next 30, append to state, increment offset. If <30 returned, set `_hasMoreMessages = false`. |
| `_dispatchRecentChatsUpdate()` | Review and remove hardcoded `LIMIT 20` if present. |

#### B3: `ChatRoomScreen` — Scroll Listener

| Change | Description |
|--------|-------------|
| `ScrollController` | Add scroll listener: when `position.extentAfter < 200`, call `cubit.loadMoreMessages()`. |
| Loading indicator | Show `CircularProgressIndicator` at top of list when `_isLoadingMore`. |

---

### Phase C — Atomic JIT Room Creation (FR-021)

**Priority: P1 (Important — eliminates race condition)**

#### C1: Backend — Update `POST /chat/private/resolve`

**File**: Backend `chat.service.ts` / `chat.controller.ts`

| Change | Description |
|--------|-------------|
| Request body | Accept optional `firstMessage: { content, clientMessageId, type, fileUrl?, metadata? }` |
| Handler | If `firstMessage` present: create room → join socket → persist message → emit to recipient → return `{ roomId, message }` |

#### C2: `ChatRemoteDataSource` — Update Resolve Call

| Change | Description |
|--------|-------------|
| `createPrivateChatRoom()` | Accept optional `firstMessage` parameter. Include in POST body if present. Parse response for both `roomId` and `message`. |

#### C3: `ChatCubit` — Remove 300ms Delay

| Change | Description |
|--------|-------------|
| `_ensureRoom()` | Remove `Future.delayed(const Duration(milliseconds: 300))`. For first message, use the atomic resolve endpoint. For subsequent messages, use normal socket flow. |
| `sendMessage()` | If `roomId` is empty (JIT), call atomic resolve with first message. Use response to set roomId and mark message as sent. |

---

### Phase D — Message Deletion (FR-022)

**Priority: P1 (Important — user expectation)**

#### D1: `Message` Entity — Add `isDeleted` Field

| Change | Description |
|--------|-------------|
| `message.dart` | Add `final bool isDeleted` field, default `false`. |
| SQLite schema | Add `is_deleted INTEGER DEFAULT 0` column. Migration in `initDB()`. |

#### D2: Backend — Delete For Everyone Event

| Change | Description |
|--------|-------------|
| `ChatGateway` | New event handler: `deleteForEveryone` → set `isDeleted: true` on message doc → broadcast `messageDeleted` to room. |
| Time limit | Check `message.createdAt` — reject if >1 hour old. |

#### D3: `ChatCubit` — Delete Methods

| Change | Description |
|--------|-------------|
| `deleteMessageForMe()` | Existing local delete + confirmation dialog. |
| `deleteMessageForEveryone()` | Emit socket event → local update → UI refresh. |

#### D4: `MessageBubble` — Deleted State

| Change | Description |
|--------|-------------|
| Bubble rendering | If `message.isDeleted`, show "🚫 This message was deleted" in italic grey. |
| Long-press menu | Show "Delete for Me" always. Show "Delete for Everyone" only if `isMine && withinOneHour`. |

---

### Phase E — UI Refactoring (FR-023)

**Priority: P2 (Enhancement)**

#### E1: Create Poll Dialog

**File**: `lib/features/chat/presentation/widgets/create_poll_dialog.dart`

Match `images_ui/create_poll.jpeg` layout with `AppColors`:
- Dark background modal, QUESTION section, OPTIONS with drag-reorder handles
- "Allow multiple answers" toggle, Cancel/Send actions

#### E2: Create Event Dialog

**File**: `lib/features/chat/presentation/widgets/create_event_dialog.dart`

Match `images_ui/create_event.jpeg` layout with `AppColors`:
- Event name, description (2048 char limit), date-time pickers
- "Include end time" toggle, location field, reminder dropdown, "Allow guests" toggle

#### E3: Poll Message Bubble

**File**: `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

Match `images_ui/poll_msg.jpeg` with `AppColors`:
- Question title, hint text, radio/checkbox options, vote counts, progress bars
- "View votes" action button

#### E4: Event Message Bubble

**File**: `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

Match `images_ui/event_msg_in_chat.jpeg` with `AppColors`:
- Calendar icon, event title, date range, description
- "Join call" and "Add to calendar" action buttons

---

### Phase F — Shared Media Screen (FR-024)

**Priority: P2 (Enhancement)**

#### F1: New `SharedMediaScreen` Page

**File**: `lib/features/chat/presentation/pages/shared_media_screen.dart`

- 3 tabs: Media, Links, Docs
- Grid layout for Media (4 columns), list for Links/Docs
- Footer with count summary
- "Select" button for multi-select
- Instant load from SQLite — no loading spinner

#### F2: `ChatInfoScreen` Navigation

**File**: `lib/features/chat/presentation/pages/chat_info_screen.dart`

| Change | Description |
|--------|-------------|
| Media header | Wrap in `GestureDetector` → navigate to `SharedMediaScreen`. |

#### F3: `ChatLocalDataSource` — Media Queries

| Change | Description |
|--------|-------------|
| `getSharedLinks()` | New method: query messages where `text` contains URLs. |
| `getSharedDocs()` | New method: query messages where `type = 'file'`. |
| `getMediaCount()` | New method: return `{photos: int, videos: int}` counts. |

---

### Phase G — Voice Waveform Optimization (FR-025)

**Priority: P1 (Important — performance)**

#### G1: Sender-Side Extraction

**File**: `lib/features/chat/presentation/widgets/chat_input_bar.dart`

| Change | Description |
|--------|-------------|
| `_stopAndSendRecording()` | After recording stops, extract waveform (50 samples) immediately. Pass `waveformSamples` in message metadata to `sendVoiceNote()`. |

#### G2: Socket Payload

**File**: `lib/features/chat/presentation/bloc/chat_cubit.dart`

| Change | Description |
|--------|-------------|
| `sendVoiceNote()` | Include `metadata.waveformSamples` in the socket `sendMessage` event payload. |

#### G3: Receiver-Side Rendering

**File**: `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

| Change | Description |
|--------|-------------|
| `_VoiceBubble._preparePlayer()` | Always call `preparePlayer(shouldExtractWaveform: false)`. Read waveform from `message.metadata['waveformSamples']` directly. Never call `extractWaveformData()`. |

---

### Phase H — Media Bubble Display Refactor (FR-026)

**Priority: P2 (Enhancement — visual polish)**

Reference: `images_ui/display_media_inside_chatroom.mp4`

#### H1: `_ImageBubble` — Overlay Timestamp on Media

**File**: `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

| Change | Description |
|--------|-------------|
| Layout | Move the `footer` (timestamp + ticks) from BELOW the image to INSIDE the image, overlaid at the bottom-right corner. |
| Gradient | Add a semi-transparent dark gradient (`LinearGradient` from transparent to `Colors.black54`) at the bottom of the media to ensure text readability. |
| Border radius | Increase to `16.resR` (WhatsApp standard). |
| Footer style | White text, smaller font, positioned with `Positioned(bottom: 6, right: 8)` inside a `Stack`. |

#### H2: `_VideoBubble` — Overlay Timestamp + Duration

**File**: `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

| Change | Description |
|--------|-------------|
| Layout | Same overlay pattern as `_ImageBubble` — timestamp + ticks inside the media. |
| Play button | White triangle inside a semi-transparent dark circle (`Colors.black.withOpacity(0.5)`), centered on the thumbnail. Already partially implemented — verify styling. |
| Duration label | Add video duration (e.g., "0:14") at the bottom-left of the thumbnail, white text with dark background chip. |

#### H3: `MediaGalleryViewer` — Full-Screen Refactor

**File**: `lib/features/chat/presentation/widgets/message_bubble_widget.dart` (or dedicated file)

| Change | Description |
|--------|-------------|
| Background | Solid black (`Colors.black`). |
| Header | Sender name + date/time (e.g., "25/04/2026, 2:01 AM"). |
| Actions | Top-right: share, star (favorite), delete icons. |
| Reply button | Bottom center: "Reply" button to reply directly while viewing media. |
| Voice notes | When viewing a voice note, show white waveform centered on black background with progress bar at the top. |

## Complexity Tracking

> No constitution violations. All changes follow Clean Architecture, use `sqflite` for persistence, and integrate through the existing `ChatCubit` Cubit pattern.

| Aspect | Assessment |
|--------|------------|
| Schema migration | Low — 2 new columns (`is_deleted`, `last_message_id`), handled via `ALTER TABLE` in `initDB()` |
| Backend changes | Medium — FR-021 (atomic resolve) and FR-022 (delete for everyone) require backend modifications |
| UI complexity | Medium-High — 4 bubble/dialog refactors (FR-023), media bubble overlay refactor (FR-026), 1 new screen (FR-024), full-screen viewer polish (FR-026) |
| Risk areas | JIT atomic resolve (C1-C3), pagination scroll listener edge cases (B3), media overlay layout on different screen sizes (H1-H2) |

