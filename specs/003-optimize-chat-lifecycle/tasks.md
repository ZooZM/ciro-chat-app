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

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure. This feature refactors the existing chat.

- [x] T001 Create `CallState` in `lib/features/call/presentation/bloc/call_state.dart`. **RESOLVED**: Already implemented at `lib/features/video_call/presentation/bloc/call_cubit.dart`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T002 Refactor `SocketService` to separate messaging events from call signaling events in `lib/core/network/socket_service.dart`. **RESOLVED**: Already separated.
- [x] T003 Ensure `Message` entity uses `MessageStatus` correctly in `lib/features/chat/domain/entities/message.dart`. **RESOLVED**.
- [x] T004 Create or update `CallCubit` to manage `CallState`. **RESOLVED**: Fully implemented at `lib/features/video_call/presentation/bloc/call_cubit.dart`.
- [x] T005 Register `CallCubit` in `lib/core/di/injection.dart`. **RESOLVED**: Already registered as `@lazySingleton`.

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Real-time Chat Experience (Priority: P1) 🎯 MVP

- [x] T006 [US1] Update `ChatState` to optimize field updates via `copyWith` in `lib/features/chat/presentation/bloc/chat_state.dart`
- [x] T007 [US1] Refactor `ChatCubit` to selectively emit state changes in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T008 [US1] Refactor `ChatPage` to use `buildWhen` in `BlocBuilder` in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [x] T009 [US1] Refactor list rendering to avoid full rebuilds in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [x] T010 [US1] Extract typing indicator into a separate widget in `lib/features/chat/presentation/widgets/typing_indicator.dart`

---

## Phase 4: User Story 2 - Non-Intrusive Call Integration (Priority: P1)

- [x] T011 [US2] Implement `CallOverlay` widget in `lib/features/chat/presentation/widgets/call_overlay.dart`
- [x] T012 [US2] Integrate `CallOverlay` into root widget tree in `lib/main.dart`
- [x] T013 [US2] Connect `CallOverlay` to `CallCubit` for all `CallState` transitions
- [x] T014 [US2] Verify `SocketService` properly delegates call events to `CallCubit`. **RESOLVED**.

---

## Phase 5: User Story 3 - Codebase Consistency (Priority: P2)

- [x] T015 [US3] [P] Replace hardcoded colors with `AppColors` in `lib/features/chat/presentation/`
- [x] T016 [US3] [P] Replace hardcoded text styles with `AppTypography`
- [x] T017 [US3] [P] Scan hardcoded strings — functional status strings only
- [x] T018 [US3] [P] Scan hardcoded icons — all use `Icons.*` constants

---

## Phase 6: User Story 4 - Group Chat Persistence Bug Fix (Priority: P0) 🐛

- [x] T021 [US4] Fix room UPSERT SQL in `saveMessage()` to preserve `type`, `participants`, `admins` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T022 [US4] Verify `saveRoom()` correctly persists all room fields in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T023 [US4] Verify `ChatSession` is passed with correct `type` through GoRouter in `lib/core/routing/app_router.dart`
- [x] T024 [US4] Verify `ChatRoomScreen` AppBar conditionally renders Group vs P2P metadata

---

## Phase 7: User Story 6 - Message Rendering Fix (Priority: P0) 🐛

- [x] T025 [US6] [P] Add `system` to `MessageType` enum in `lib/features/chat/domain/entities/message.dart`
- [x] T026 [US6] [P] Add `system` case to `_mediaPreview()` in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T027 [US6] Implement `_buildSystemBubble()` widget in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T028 [US6] Add routing logic for `MessageType.system` in `MessageBubbleWidget.build()`

---

## Phase 8: User Story 5 - Group Info Logic Integration (Priority: P1)

- [x] T029 [US5] Replace static description with dynamic field from `ChatSession` in `lib/features/chat/presentation/pages/group_info_page.dart`
- [x] T030 [US5] Replace hardcoded media section with real media query in `lib/features/chat/presentation/pages/group_info_page.dart`
- [x] T031 [US5] [P] Replace `Colors.*` literals with `AppColors` in `lib/features/chat/presentation/pages/group_info_page.dart`
- [x] T032 [US5] Wire "Edit" AppBar button to group edit dialog in `lib/features/chat/presentation/pages/group_info_page.dart`

---

## Phase 9: User Story 7 - Chat Attachment Actions (Priority: P1)

- [x] T033 [US7] [P] Add `LOCATION`, `AUDIO`, `POLL`, `EVENT` to backend `MessageType` enum in `E:\zeyad\chat-app-backend\src\modules\chat\schemas\message.schema.ts`
- [x] T034 [US7] [P] Add metadata fields to backend `MessageMetadata` in `E:\zeyad\chat-app-backend\src\modules\chat\schemas\message.schema.ts`
- [x] T035 [US7] [P] Add `location`, `audio`, `poll`, `event` to Flutter `MessageType` enum in `lib/features/chat/domain/entities/message.dart`
- [x] T036 [US7] [P] Update `_mediaPreview()` for new types in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T037 [US7] Add `google_maps_flutter`, `geolocator`, `geocoding`, `flutter_dotenv` to `pubspec.yaml`
- [x] T038 [US7] Create `.env` file with `GOOGLE_MAPS_API_KEY` placeholder
- [x] T039 [US7] Configure Android/iOS for Maps API key and location permissions
- [x] T040 [US7] Implement `sendCameraMessage()` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T041 [US7] Implement `sendLocationMessage()` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T042 [US7] Implement `sendAudioMessage()` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T043 [US7] Implement `sendPollMessage()` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T044 [US7] Implement `sendEventMessage()` in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T045 [US7] Wire `_handleCamera` handler in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T046 [US7] Wire `_handleLocation` handler in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T046b [US7] Implement graceful location permission handling in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T047 [US7] Wire `_handleAudio` handler in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T048 [US7] Wire `_handlePoll` handler in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T049 [US7] Wire `_handleEvent` handler in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T050 [US7] Update `_routeTap` switch in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T051 [US7] [P] Implement `_buildLocationBubble()` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T052 [US7] [P] Implement `_buildAudioBubble()` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T053 [US7] [P] Implement `_buildPollBubble()` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T054 [US7] [P] Implement `_buildEventBubble()` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T055 [US7] Add routing logic for `location`, `audio`, `poll`, `event` in `MessageBubbleWidget.build()`

---

## Phase 10: User Story 8 - Voice Notes Stability (Priority: P1)

- [x] T056 [US8] Audit voice note recording lifecycle in `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- [x] T057 [US8] Implement singleton audio playback manager in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T058 [US8] Add `mounted` checks after all async operations in chat widgets
- [x] T059 [US8] Verify `AudioWaveforms` controller disposal in `lib/features/chat/presentation/widgets/chat_input_bar.dart`

---

## Phase 11: User Story 9 - Static/Mock Data Cleanup (Priority: P2)

- [x] T060 [US9] [P] Delete orphan backup file `lib/features/chat/presentation/pages/chat_screen.dart.bak`
- [x] T061 [US9] [P] Remove hardcoded media placeholder thumbnails in `group_info_page.dart`
- [x] T062 [US9] [P] Scan for remaining static data arrays in `lib/features/chat/`
- [x] T063 [US9] [P] Replace remaining `Colors.*` literals in `attachment_sheet_widget.dart`

---

## Phase 12: User Story 10 - Codebase Audit (Priority: P2)

- [x] T064 [US10] [P] Scan for `TODO`, `FIXME`, `HACK`, `XXX` markers in `lib/features/chat/`
- [x] T065 [US10] [P] Scan for commented-out function bodies or dead code in `lib/features/chat/`
- [x] T066 [US10] [P] Verify all `StreamSubscription` have matching `.cancel()` in `chat_cubit.dart`

---

## Phase 13: Polish & Cross-Cutting Concerns (Original)

- [x] T067 [P] Verify `_mediaPreview()` handles ALL `MessageType` values in `chat_local_data_source.dart`
- [x] T068 Run full `flutter analyze` — zero warnings/errors
- [x] T069 Validate quickstart.md — all setup steps accurate
- [x] T070 Final smoke test — open P2P chat, Group chat, send all message types

---

## Phase 14: User Story 11 - Audio Waveform Local Persistence (Priority: P1)

**Goal**: Cache waveform data in SQLite so voice note waveforms render instantly on re-entry without re-extraction.

**Independent Test**: Send a voice note, exit chat, re-enter. Waveform must render instantly from cache.

### Implementation for User Story 11

- [ ] T071 [US11] Add `getWaveformCache(String messageId)` and `saveWaveformCache(String messageId, List<double> samples)` methods to `lib/features/chat/data/datasources/chat_local_data_source.dart`. Store waveform samples as JSON in the message `metadata` column under key `waveformSamples`.
- [ ] T072 [US11] Update `_VoiceBubble._preparePlayer()` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`: before calling `preparePlayer(shouldExtractWaveform: true)`, check if `metadata['waveformSamples']` exists. If yes, pass cached data to the `PlayerController` and skip native extraction.
- [ ] T073 [US11] After successful first-time waveform extraction in `_VoiceBubble`, call `saveWaveformCache()` to persist the extracted `List<double>` samples to SQLite metadata in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`.

**Checkpoint**: Waveform renders from cache on second visit — no re-extraction.

---

## Phase 15: User Story 12 - Video Message Support (Priority: P1)

**Goal**: Send and receive video messages with thumbnail preview, inline playback, and WhatsApp-style media gallery.

**Independent Test**: Select video from gallery, send. Verify thumbnail renders with play icon. Tap to play full-screen. Swipe between media.

### Implementation for User Story 12

- [ ] T074 [US12] [P] Add `VIDEO = 'video'` to backend `MessageType` enum in `E:\zeyad\chat-app-backend\src\modules\chat\schemas\message.schema.ts`. Add `thumbnailUrl` to `MessageMetadata`.
- [ ] T075 [US12] [P] Add `video` to Flutter `MessageType` enum and update `messageTypeFromString()` / `messageTypeToString()` in `lib/features/chat/domain/entities/message.dart`. Update `_mediaPreview()` to return `'🎬 Video'` in `lib/features/chat/data/datasources/chat_local_data_source.dart`.
- [ ] T076 [US12] Add `video_player` and `video_thumbnail` to `pubspec.yaml` and run `flutter pub get`.
- [ ] T077 [US12] Implement `sendVideoMessage(BuildContext context)` in `lib/features/chat/presentation/bloc/chat_cubit.dart` — use `ImagePicker().pickVideo()`, generate thumbnail via `video_thumbnail`, upload both via `POST /chat/upload`, emit socket message with `MessageType.video` and metadata `{ duration, mimeType, thumbnailUrl }`.
- [ ] T078 [US12] Add video option to attachment sheet: wire `_handleVideo` handler → `ChatCubit.sendVideoMessage()` in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`. Add a "Video" entry to `_attachmentOptions` list.
- [ ] T079 [US12] Implement `_VideoBubble` widget in `lib/features/chat/presentation/widgets/message_bubble_widget.dart` — renders `CachedNetworkImage` thumbnail with centered play-icon overlay. Tap opens full-screen `VideoPlayer`.
- [ ] T080 [US12] Add `video` case routing in `MessageBubbleWidget.build()` to render `_VideoBubble` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`.
- [ ] T081 [US12] Create `MediaGalleryViewer` widget in `lib/features/chat/presentation/widgets/media_gallery_viewer.dart` — full-screen `PageView` with all media messages (images + videos) from the conversation. Images use `CachedNetworkImage`, videos use `VideoPlayer`. Supports horizontal swipe.
- [ ] T082 [US12] Wire tap on any image/video bubble to open `MediaGalleryViewer` at the tapped item's index in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`.

**Checkpoint**: Video messages send and render with thumbnail + play icon. Media gallery supports swipe.

---

## Phase 16: User Story 13 - Resend Failed Messages (Priority: P1)

**Goal**: Display a resend icon on failed messages and allow one-tap retry.

**Independent Test**: Disable network, send message, verify error icon. Re-enable, tap resend, verify delivery.

### Implementation for User Story 13

- [ ] T083 [US13] Implement `resendMessage(String clientMessageId)` in `lib/features/chat/presentation/bloc/chat_cubit.dart` — look up the failed message from local state, update status to `pending`, re-emit via socket with the original `clientMessageId`. On failure, revert to `error` status.
- [ ] T084 [US13] In `MessageBubbleWidget`, detect `message.status == MessageStatus.error` and render a resend icon button (circular arrow `Icons.refresh`) positioned to the left of outgoing bubbles in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`. Tap calls `ChatCubit.resendMessage(message.clientMessageId)`.
- [ ] T085 [US13] Update SQLite status to `pending` on resend and to `error` on re-failure in `lib/features/chat/data/datasources/chat_local_data_source.dart` via existing `updateMessageStatus()` method.

**Checkpoint**: 100% of error-status messages show resend icon. Tapping retries successfully.

---

## Phase 17: User Story 14 - Block User (Priority: P2)

**Goal**: Full block/unblock user feature with backend REST + socket guard + frontend ChatInfoScreen integration.

**Independent Test**: Open Chat Info, tap "Block user", confirm. Verify messages stop. Unblock, verify resume.

### Backend Implementation

- [ ] T086 [US14] [P] Add `blockedUsers: [{ type: Schema.Types.ObjectId, ref: 'User', default: [] }]` field to the User schema in `E:\zeyad\chat-app-backend\src\modules\chat\schemas\` (either in existing user schema or via a new field on the auth user model).
- [ ] T087 [US14] [P] Implement `blockUser(userId, targetId)`, `unblockUser(userId, targetId)`, `getBlockList(userId)`, and `isBlocked(senderId, recipientId)` methods in `E:\zeyad\chat-app-backend\src\modules\chat\chat.service.ts`.
- [ ] T088 [US14] Add REST endpoints: `POST /chat/block/:userId`, `DELETE /chat/block/:userId`, `GET /chat/block-list` in `E:\zeyad\chat-app-backend\src\modules\chat\chat.controller.ts`. All require JWT auth guard.
- [ ] T089 [US14] Add block guard in the `send_message` socket handler in `E:\zeyad\chat-app-backend\src\modules\chat\chat.gateway.ts`: before delivering a message, call `isBlocked(senderId, recipientId)`. If blocked, silently drop the message.

### Frontend Implementation

- [ ] T090 [US14] Add `blockUser(String targetUserId)`, `unblockUser(String targetUserId)`, and `isUserBlocked(String targetUserId)` methods to `lib/features/chat/presentation/bloc/chat_cubit.dart`. Call REST endpoints via `ChatRemoteDataSource`.
- [ ] T091 [US14] Add `blockUser()`, `unblockUser()`, `getBlockList()` methods to `lib/features/chat/data/datasources/chat_remote_data_source.dart` using DioClient.
- [ ] T092 [US14] Wire "Block user" tile in `lib/features/chat/presentation/pages/chat_info_screen.dart`: show confirmation dialog, call `ChatCubit.blockUser()`, toggle tile text to "Unblock user" on success.

**Checkpoint**: Blocking prevents message exchange. Unblocking restores it.

---

## Phase 18: User Story 15 - Search in Chat Room (Priority: P2)

**Goal**: In-chat message search with results list and scroll-to-message navigation.

**Independent Test**: Open chat, tap search, type keyword. Verify results listed. Tap result, verify scroll + highlight.

### Implementation for User Story 15

- [ ] T093 [US15] Add `searchMessages(String roomId, String query)` method to `lib/features/chat/data/datasources/chat_local_data_source.dart` — SQL `SELECT * FROM messages WHERE roomId = ? AND text LIKE '%' || ? || '%' ORDER BY createdAt DESC LIMIT 50`.
- [ ] T094 [US15] Add `searchMessages(String query)` method to `lib/features/chat/presentation/bloc/chat_cubit.dart` — calls local data source, emits search results via a `ValueNotifier<List<Message>>` or a dedicated state field.
- [ ] T095 [US15] Create `ChatSearchBar` widget in `lib/features/chat/presentation/widgets/chat_search_bar.dart` — animated overlay at top of chat room with a `TextField`, shows results as a scrollable `ListView` of message previews.
- [ ] T096 [US15] Wire search trigger: add search icon to `ChatRoomScreen` AppBar actions. Tapping toggles `ChatSearchBar` visibility in `lib/features/chat/presentation/pages/chat_room_screen.dart`.
- [ ] T097 [US15] Implement scroll-to-message: when user taps a search result, calculate the message index in the full message list, call `ScrollController.jumpTo()` or `Scrollable.ensureVisible()`, and briefly highlight the target message with a fade animation in `lib/features/chat/presentation/pages/chat_room_screen.dart`.

**Checkpoint**: Search returns results <1s. Tapping scrolls to message with highlight.

---

## Phase 19: User Story 16 - ChatInfoScreen Full Logic (Priority: P1)

**Goal**: Wire all interactive elements in ChatInfoScreen to real data and actions.

**Depends on**: Phase 17 (Block User), Phase 18 (Search)

**Independent Test**: Open Chat Info — profile from real data, quick actions work, media shows real content.

### Implementation for User Story 16

- [ ] T098 [US16] Wire "Voice call" quick action to `CallCubit.initiateCall(type: voice)` and "Video call" to `CallCubit.initiateCall(type: video)` in `lib/features/chat/presentation/pages/chat_info_screen.dart`.
- [ ] T099 [US16] Wire "Search" quick action to navigate back to `ChatRoomScreen` and open `ChatSearchBar` in `lib/features/chat/presentation/pages/chat_info_screen.dart`.
- [ ] T100 [US16] Add `getSharedMedia(String roomId)` method to `lib/features/chat/data/datasources/chat_local_data_source.dart` — query messages with `type IN ('image', 'video', 'file')` ordered by `createdAt DESC`.
- [ ] T101 [US16] Replace static media grid in `_buildMediaSection()` with real shared media from `getSharedMedia()` in `lib/features/chat/presentation/pages/chat_info_screen.dart`. Show empty state if no media.
- [ ] T102 [US16] Wire "Block user" tile to `ChatCubit.blockUser()` from Phase 17 with confirmation dialog in `lib/features/chat/presentation/pages/chat_info_screen.dart`.
- [ ] T103 [US16] Wire "Mute notifications" and "Chat lock" toggle state to Hive-persisted preferences using keys `mute_<roomId>` and `lock_<roomId>` in `lib/features/chat/presentation/pages/chat_info_screen.dart`.

**Checkpoint**: ChatInfoScreen fully functional — all actions wired, real data displayed.

---

## Phase 20: User Story 17 - Splash Screen Chat Preload (Priority: P2)

**Goal**: Preload chat list during splash so home screen renders immediately without a loading spinner.

**Independent Test**: Launch app. Chat list visible instantly on home screen — no loading spinner.

### Implementation for User Story 17

- [ ] T104 [US17] In `SplashScreen`, after `AuthCubit.verifyAuthStatus()` resolves as authenticated, call `ChatCubit.loadRecentChats()` using `context.read<ChatCubit>()` in `lib/features/splash/presentation/pages/splash_screen.dart`.
- [ ] T105 [US17] Use `Future.wait([authFuture, chatLoadFuture])` to parallelize auth verification and chat preload. Navigate to home only after both complete in `lib/features/splash/presentation/pages/splash_screen.dart`.
- [ ] T106 [US17] Remove or gate the loading spinner in the home screen's chat list `BlocBuilder` — if state already has chats, render immediately in `lib/features/chat/presentation/pages/chat_list_screen.dart`.

**Checkpoint**: Chat list visible within 500ms of home screen navigation — no spinner.

---

## Phase 21: Final Polish & Cross-Cutting (New Features)

**Purpose**: Final validation across all new user stories

- [ ] T107 [P] Update `_mediaPreview()` to handle `video` type (`'🎬 Video'`) in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [ ] T108 Run full `flutter analyze` — zero errors across all modified files
- [ ] T109 Verify backend `flutter analyze` equivalent (`npm run lint`) passes in `E:\zeyad\chat-app-backend`
- [ ] T110 Final smoke test — send video, resend failed message, block/unblock user, search messages, verify splash preload

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1-13** (T001-T070): ✅ COMPLETED in prior sessions
- **Phase 14** (US11 - Waveform Cache): No dependencies — can start immediately
- **Phase 15** (US12 - Video Messages): No dependencies — can start immediately
- **Phase 16** (US13 - Resend Failed): No dependencies — can start immediately
- **Phase 17** (US14 - Block User): No dependencies — can start immediately
- **Phase 18** (US15 - Search): No dependencies — can start immediately
- **Phase 19** (US16 - ChatInfoScreen): Depends on Phase 17 (block) + Phase 18 (search)
- **Phase 20** (US17 - Splash Preload): No dependencies — can start immediately
- **Phase 21** (Polish): Depends on ALL previous phases

### Parallel Opportunities

- **Phase 14 + 15 + 16 + 17 + 18 + 20**: All independent — can run in parallel
- **T074 + T075**: Backend + Flutter enum changes can run in parallel
- **T086 + T087**: Backend schema + service can run in parallel
- **Phase 19**: Must wait for Phase 17 + 18

---

## Implementation Strategy

### MVP First (New Features)

1. Phase 16: Resend Failed Messages (T083-T085) — quick win, high user impact
2. Phase 14: Waveform Cache (T071-T073) — stability improvement
3. Phase 15: Video Messages (T074-T082) — largest new feature

### Incremental Delivery

1. Resend + Waveform Cache → Stability layer
2. Video Messages → Multimedia expansion
3. Block User (backend first, then frontend) → Safety feature
4. Search in Chat → Discovery feature
5. ChatInfoScreen Full Logic → Requires Block + Search
6. Splash Preload → Performance polish
7. Final Polish → Ship-ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- T001-T070 are all completed from prior sessions — new work starts at T071
