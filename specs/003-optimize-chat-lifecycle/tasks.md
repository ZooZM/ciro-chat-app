---
description: "Task list for Optimize Chat Lifecycle feature"
---

# Tasks: Optimize Chat Lifecycle

**Input**: Design documents from `/specs/003-optimize-chat-lifecycle/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phases 1-21: COMPLETED (T001-T110) ✅

All original user stories (US1-US17) and their tasks have been completed in prior sessions. The following phases cover the new P2P-focused requirements (FR-018 through FR-026) added in the April 30, 2026 planning session.

---

## Phase 22: Message Idempotency & Monotonic Status (FR-019) — Priority: P0 🐛

**Goal**: Prevent duplicate message inserts on socket reconnect and enforce monotonic-only status promotion (pending→sent→delivered→read, never backward).

**Independent Test**: Simulate socket reconnect that replays already-received messages. Verify no duplicates in SQLite. Manually call `updateMessageStatus` with a lower-rank status and verify it's silently ignored.

### Implementation

- [x] T111 [FR-019] Add `_statusRank(MessageStatus status)` helper method returning `{pending:0, sent:1, delivered:2, read:3}` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T112 [FR-019] Modify `saveMessage()` to check `SELECT id FROM messages WHERE client_message_id = ?` before insert — if row exists, return early (skip insert) in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T113 [FR-019] Modify `updateMessageStatus()` to query by `client_message_id` instead of `id`, fetch current status rank, and skip update if incoming rank ≤ current rank in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T114 [FR-019] Update `ChatCubit.handleMessageStatusUpdate()` to pass `clientMessageId` instead of `id` to `updateMessageStatus()` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T115 [FR-019] Add dedup check in `ChatCubit._handleIncomingMessage()` — if `clientMessageId` already exists in current `state.messages`, skip processing in `lib/features/chat/presentation/bloc/chat_cubit.dart`

**Checkpoint**: Duplicate messages are silently rejected. Status never regresses.

---

## Phase 23: Scoped Inbox Status Ticks (FR-020) — Priority: P0 🐛

**Goal**: Inbox tick icons only show for the user's own sent messages (WhatsApp behavior). Room status updates only apply to the latest message.

**Independent Test**: Send a message, verify tick shows. Receive a message from other party, verify NO tick shows on inbox tile for that received message.

### Implementation

- [x] T116 [FR-020] Add `last_message_id TEXT DEFAULT ''` and `last_message_sender_id TEXT DEFAULT ''` columns to `_roomsSchema` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T117 [FR-020] Add `ALTER TABLE rooms ADD COLUMN last_message_id TEXT DEFAULT ''; ALTER TABLE rooms ADD COLUMN last_message_sender_id TEXT DEFAULT '';` migration in `initDB()` wrapped in try/catch in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T118 [FR-020] Update `saveMessage()` room upsert to set `last_message_id` and `last_message_sender_id` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T119 [FR-020] In `updateMessageStatus()`, before updating `rooms.lastMessageStatus`, verify the message matches `rooms.last_message_id` — skip room update if mismatch in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T120 [FR-020] Add `lastMessageSenderId` field to `ChatSession` entity in `lib/features/chat/domain/entities/chat_session.dart` and update `fromMap()`/`toMap()`
- [x] T121 [FR-020] Update `ChatTileWidget` to only render tick icons when `lastMessageSenderId == currentUserId` — hide ticks for received messages in `lib/features/chat/presentation/widgets/` (chat tile widget file)

**Checkpoint**: Ticks only appear for sent messages. Status scoped to latest message.

---

## Phase 24: Infinite Scroll Pagination (FR-018) — Priority: P0

**Goal**: Load 30 messages initially, lazy-load 30 more on scroll-up (WhatsApp-style infinite scroll).

**Independent Test**: Open a chat with 100+ messages. Verify only 30 load initially. Scroll up, verify 30 more load. Repeat until all loaded.

### Implementation

- [x] T122 [FR-018] Add `{int limit = 30, int offset = 0}` parameters to `getRoomMessages()` — update SQL to `ORDER BY timestamp DESC LIMIT ? OFFSET ?` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T123 [FR-018] Update `watchRoomMessages()` to accept `limit` parameter — initial emission uses `LIMIT 30` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T124 [FR-018] Add `_messageOffset`, `_hasMoreMessages`, `_isLoadingMore` fields to `ChatCubit` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T125 [FR-018] Implement `loadMoreMessages()` method in `ChatCubit` — fetch next 30, prepend to state, increment offset, set `_hasMoreMessages = false` if <30 returned in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T126 [FR-018] Add `ScrollController` listener in `ChatRoomScreen` — trigger `loadMoreMessages()` when `position.extentAfter < 200` in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [x] T127 [FR-018] Show `CupertinoActivityIndicator` at top of message list when `_isLoadingMore` in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [x] T128 [FR-018] Review and remove hardcoded `LIMIT 20` in `_dispatchRecentChatsUpdate()` if present in `lib/features/chat/data/datasources/chat_local_data_source.dart`

**Checkpoint**: Chat loads 30 messages initially. Scrolling up loads more in batches. No data loss.

---

## Phase 25: Atomic JIT Room Creation (FR-021) — Priority: P1

**Goal**: First message in a new P2P chat is sent atomically with room creation — no 300ms delay hack.

**Independent Test**: Start a new P2P chat from contacts, send the first message. Verify it arrives instantly without the 300ms delay.

### Backend Implementation

- [ ] T129 [P] Update `POST /chat/private/resolve` to accept optional `firstMessage` field in request body in backend `chat.controller.ts` / `chat.service.ts`
- [ ] T130 Implement atomic handler: if `firstMessage` present, create room → join socket → persist message → emit to recipient → return `{ roomId, message }` in backend `chat.service.ts`

### Frontend Implementation

- [x] T131 Update `createPrivateChatRoom()` to accept optional `firstMessage` parameter and parse response for both `roomId` and `message` in `lib/features/chat/data/datasources/chat_remote_data_source.dart`
- [x] T132 Remove `Future.delayed(const Duration(milliseconds: 300))` from `_ensureRoom()` and use atomic resolve for first message in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T133 Update `sendMessage()` — if `roomId` is empty (JIT), call atomic resolve with first message payload. Use response to set roomId and confirm message sent in `lib/features/chat/presentation/bloc/chat_cubit.dart`

**Checkpoint**: First message in new chat arrives without delay. No `Future.delayed` hack.

---

## Phase 26: Message Deletion (FR-022) — Priority: P1

**Goal**: WhatsApp-style "Delete for Me" (local) and "Delete for Everyone" (socket broadcast, 1-hour limit).

**Independent Test**: Send a message, long-press, delete for everyone within 1 hour. Verify both parties see "This message was deleted". Try after 1 hour — verify option is hidden.

### Schema & Entity

- [x] T134 [P] Add `is_deleted INTEGER DEFAULT 0` column to messages schema and `ALTER TABLE` migration in `initDB()` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T135 [P] Add `final bool isDeleted` field (default `false`) to `Message` entity, update `fromMap()`/`toMap()` in `lib/features/chat/domain/entities/message.dart`

### Backend

- [ ] T136 [P] Add `isDeleted: { type: Boolean, default: false }` to message schema in backend `message.schema.ts`
- [ ] T137 Implement `deleteForEveryone` socket event handler in backend `chat.gateway.ts` — validate sender ownership + 1-hour limit, set `isDeleted: true`, broadcast `messageDeleted` event

### Frontend

- [x] T138 Implement `deleteMessageForMe(String messageId)` with confirmation dialog in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T139 Implement `deleteMessageForEveryone(String clientMessageId)` — emit socket event, update local SQLite, refresh UI in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T140 Listen for `messageDeleted` socket event — find message by `clientMessageId`, set `isDeleted = true` in local DB and state in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T141 Update `MessageBubbleWidget` — if `message.isDeleted`, render "🚫 This message was deleted" in italic grey text in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T142 Update long-press menu — show "Delete for Me" always, show "Delete for Everyone" only if `isMine && DateTime.now() - message.createdAt < 1 hour` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

**Checkpoint**: Both delete modes work. Deleted messages show placeholder. Time limit enforced.

---

## Phase 27: Voice Waveform Optimization (FR-025) — Priority: P1

**Goal**: Extract waveform at record time (sender), transmit via socket, receiver renders instantly from cached data — never re-extracts.

**Independent Test**: Record and send a voice note. On receiver device, verify waveform renders instantly without extraction delay. Exit and re-enter chat — waveform still instant.

### Implementation

- [ ] T143 In `_stopAndSendRecording()`, after recording stops, use `PlayerController` to extract waveform data (50 samples) from the recorded file. Pass `waveformSamples` in metadata to `sendVoiceNote()` in `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- [ ] T144 Update `sendVoiceNote()` to include `metadata.waveformSamples` in the socket `sendMessage` event payload in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [ ] T145 Update `_VoiceBubble._preparePlayer()` — always call `preparePlayer(shouldExtractWaveform: false)`. Read waveform from `message.metadata['waveformSamples']` directly. Remove all calls to `extractWaveformData()` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

**Checkpoint**: Waveform extraction happens once at recording. Receiver never extracts. Instant rendering.

---

## Phase 28: Poll & Event UI Refactoring (FR-023) — Priority: P2

**Goal**: Refactor Create Poll dialog, Create Event dialog, Poll bubble, and Event bubble to match WhatsApp reference images using `AppColors`.

**Independent Test**: Open Group chat → attachment → Poll. Verify dialog matches `create_poll.jpeg`. Send poll, verify bubble matches `poll_msg.jpeg`. Same for events.

### Implementation

- [ ] T146 [P] Refactor `CreatePollDialog` to match `images_ui/create_poll.jpeg` — dark modal, QUESTION section, OPTIONS with drag-reorder handles, "Allow multiple answers" toggle, Cancel/Send actions, all using `AppColors` in `lib/features/chat/presentation/widgets/create_poll_dialog.dart`
- [ ] T147 [P] Refactor `CreateEventDialog` to match `images_ui/create_event.jpeg` — event name, description (2048 char limit), start/end date-time pickers, "Include end time" toggle, location field, reminder dropdown, "Allow guests" toggle, Cancel/Send, all using `AppColors` in `lib/features/chat/presentation/widgets/create_event_dialog.dart`
- [ ] T148 [P] Refactor `_buildPollBubble()` to match `images_ui/poll_msg.jpeg` — question title, "Select one or more" hint, radio/checkbox options with vote counts and progress bars, "View votes" button, all using `AppColors` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [ ] T149 [P] Refactor `_buildEventBubble()` to match `images_ui/event_msg_in_chat.jpeg` — calendar icon, event title, date range, description, "Join call" and "Add to calendar" buttons, all using `AppColors` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

**Checkpoint**: All 4 UIs match reference images with `AppColors` palette.

---

## Phase 29: Shared Media Screen (FR-024) — Priority: P2

**Goal**: Dedicated tabbed media screen (Media/Links/Docs) accessible from ChatInfoScreen with instant loading from SQLite.

**Independent Test**: Open ChatInfoScreen, tap "Media, links and documents". Verify tabbed screen opens with grid/list views. Verify media loads instantly without spinner.

### Data Layer

- [x] T150 [P] Add `getSharedLinks(String roomId)` method — query messages containing URLs in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T151 [P] Add `getSharedDocs(String roomId)` method — query messages where `type = 'file'` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T152 [P] Add `getMediaCount(String roomId)` method — return `{photos: int, videos: int}` counts in `lib/features/chat/data/datasources/chat_local_data_source.dart`

### Presentation Layer

- [x] T153 Create `SharedMediaScreen` page with `TabBarView` (3 tabs: Media, Links, Docs). Media tab: 4-column `GridView.builder`. Links/Docs tabs: `ListView.builder`. Footer with count summary. "Select" button for multi-select. Styled with `AppColors`, matching `images_ui/media_screen.jpeg` in `lib/features/chat/presentation/pages/shared_media_screen.dart`
- [x] T154 Wrap "Media, links and documents" header in `ChatInfoScreen` with `GestureDetector` → navigate to `SharedMediaScreen` in `lib/features/chat/presentation/pages/chat_info_screen.dart`

**Checkpoint**: Tabbed media screen opens from ChatInfoScreen. Media loads instantly from SQLite cache.

---

## Phase 30: Media Bubble Display Refactor (FR-026) — Priority: P2

**Goal**: Image and video chat bubbles match WhatsApp-exact display — overlaid timestamps, video play button + duration, polished full-screen viewer.

**Independent Test**: Send an image. Verify timestamp + ticks overlay ON the image (not below). Send a video. Verify play button centered + duration label visible. Tap to open full-screen viewer with black background.

### Implementation

- [ ] T155 Refactor `_ImageBubble` — move timestamp+ticks footer INSIDE the image as overlay at bottom-right with semi-transparent dark gradient behind text. Increase border radius to `16.resR`. White text, smaller font, `Positioned(bottom: 6, right: 8)` inside a `Stack` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [ ] T156 Refactor `_VideoBubble` — same overlay pattern as `_ImageBubble` for timestamp+ticks. Add centered play button (white triangle in semi-transparent dark circle). Add duration label (e.g., "0:14") at bottom-left with dark background chip in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [ ] T157 Refactor `MediaGalleryViewer` — solid black background, header with sender name + date/time, top-right action icons (share, star, delete), bottom "Reply" button. Voice notes show white waveform on black background with progress bar in `lib/features/chat/presentation/widgets/media_gallery_viewer.dart`

**Checkpoint**: Media bubbles have overlaid timestamps. Videos show play button + duration. Full-screen viewer is polished.

---

## Phase 31: Final Polish & Cross-Cutting (P2P Focus)

**Purpose**: Final validation across all new P2P features

- [ ] T158 [P] Verify no `Future.delayed` hacks remain in `lib/features/chat/` — run `grep -rn "Future.delayed" lib/features/chat/`
- [ ] T159 [P] Verify no `ConflictAlgorithm.replace` on messages table — run `grep -rn "ConflictAlgorithm.replace" lib/features/chat/`
- [ ] T160 [P] Scan for remaining `Colors.*` literals in `lib/features/chat/` — all should use `AppColors`
- [ ] T161 Run full `flutter analyze` — zero errors across all modified files
- [ ] T162 Final smoke test — send messages in new P2P chat (atomic JIT), scroll up to load older messages, delete a message for everyone, verify waveform instant render, open shared media screen, verify media bubbles have overlaid timestamps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phases 1-21** (T001-T110): ✅ COMPLETED in prior sessions
- **Phase 22** (Idempotency): No dependencies — start immediately
- **Phase 23** (Scoped Status): Depends on Phase 22 (shares `updateMessageStatus()`)
- **Phase 24** (Pagination): No dependencies — can start in parallel with Phase 22
- **Phase 25** (Atomic JIT): No dependencies — can start immediately
- **Phase 26** (Deletion): Depends on Phase 22 (idempotency guards needed for delete events)
- **Phase 27** (Waveform): No dependencies — can start immediately
- **Phase 28** (Poll/Event UI): No dependencies — can start immediately
- **Phase 29** (Media Screen): No dependencies — can start immediately
- **Phase 30** (Media Bubbles): No dependencies — can start immediately
- **Phase 31** (Polish): Depends on ALL previous phases

### Parallel Opportunities

- **Phase 22 + 24 + 25 + 27 + 28 + 29 + 30**: All independent — can run in parallel
- **T134 + T135 + T136**: Schema changes can run in parallel (different files)
- **T146 + T147 + T148 + T149**: All 4 UI refactors are independent files
- **T150 + T151 + T152**: All 3 data queries are independent methods

---

## Implementation Strategy

### MVP First (P0 Critical)

1. Phase 22: Idempotency (T111-T115) — data integrity fix
2. Phase 23: Scoped Status (T116-T121) — inbox correctness
3. Phase 24: Pagination (T122-T128) — memory management

### Incremental Delivery

1. Idempotency + Scoped Status + Pagination → **Stability layer**
2. Atomic JIT (T129-T133) → **Race condition elimination**
3. Deletion (T134-T142) → **User trust feature**
4. Waveform (T143-T145) → **Performance optimization**
5. Poll/Event UI + Media Screen + Media Bubbles → **Visual polish**
6. Final Polish → **Ship-ready**

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- T001-T110 are all completed from prior sessions — new work starts at T111
- Backend tasks (T129-T130, T136-T137) require access to `E:\zeyad\chat-app-backend`
- Commit after each phase checkpoint
