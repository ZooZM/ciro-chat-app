---
description: "Task list template for feature implementation"
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

**Goal**: Seamless, lag-free real-time P2P and Group chat experience without unnecessary UI rebuilds.

**Independent Test**: Send multiple rapid messages and verify UI remains responsive.

### Implementation for User Story 1

- [x] T006 [US1] Update `ChatState` to optimize field updates via `copyWith` in `lib/features/chat/presentation/bloc/chat_state.dart`
- [x] T007 [US1] Refactor `ChatCubit` to selectively emit state changes in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T008 [US1] Refactor `ChatPage` to use `buildWhen` in `BlocBuilder` in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [x] T009 [US1] Refactor list rendering to avoid full rebuilds in `lib/features/chat/presentation/pages/chat_room_screen.dart`
- [x] T010 [US1] Extract typing indicator into a separate widget in `lib/features/chat/presentation/widgets/typing_indicator.dart`

**Checkpoint**: US1 complete — rapid socket updates should not cause full page rebuilds.

---

## Phase 4: User Story 2 - Non-Intrusive Call Integration (Priority: P1)

**Goal**: Voice and Video calls should not interrupt the text chat flow.

**Independent Test**: Initiate a call while typing — chat UI state must be preserved.

### Implementation for User Story 2

- [x] T011 [US2] Implement `CallOverlay` widget in `lib/features/chat/presentation/widgets/call_overlay.dart`
- [x] T012 [US2] Integrate `CallOverlay` into root widget tree in `lib/main.dart` and register `/outgoing_call` route in `lib/core/routing/app_router.dart`
- [x] T013 [US2] Connect `CallOverlay` to `CallCubit` for all `CallState` transitions in `lib/features/chat/presentation/widgets/call_overlay.dart`
- [x] T014 [US2] Verify `SocketService` properly delegates call events to `CallCubit`. **RESOLVED**: Already cleanly separated.

**Checkpoint**: US1 and US2 complete — call integration is non-intrusive.

---

## Phase 5: User Story 3 - Codebase Consistency (Priority: P2)

**Goal**: Chat feature strictly adheres to core design system — no hardcoded colors, strings, or icons.

**Independent Test**: Verify no hardcoded styling in `lib/features/chat/presentation/`.

### Implementation for User Story 3

- [x] T015 [US3] [P] Replace hardcoded colors with `AppColors` in `lib/features/chat/presentation/` — 18 occurrences replaced.
- [x] T016 [US3] [P] Replace hardcoded text styles with `AppTypography` — already compliant.
- [x] T017 [US3] [P] Scan hardcoded strings — functional status strings only, no change needed.
- [x] T018 [US3] [P] Scan hardcoded icons — all use `Icons.*` constants, no change needed.

**Checkpoint**: US1-US3 complete.

---

## Phase 6: User Story 4 - Group Chat Persistence Bug Fix (Priority: P0) 🐛

**Goal**: Fix the bug where Group Chat rooms revert to P2P after exit/re-entry. Root cause: `saveMessage()` UPSERT in SQLite omits `type`, `participants`, `admins` columns.

**Independent Test**: Send a message in a Group Chat, exit, re-enter — AppBar must show group metadata (participant count), not P2P metadata (online status).

### Implementation for User Story 4

- [x] T021 [US4] Fix the room UPSERT SQL in `saveMessage()` to preserve `type`, `participants`, and `admins` columns using COALESCE in `lib/features/chat/data/datasources/chat_local_data_source.dart` (lines 191-220)
- [x] T022 [US4] Verify `saveRoom()` correctly persists all room fields including `type` in `lib/features/chat/data/datasources/chat_local_data_source.dart` (lines 441-469)
- [x] T023 [US4] Verify `ChatSession` is passed with correct `type` through GoRouter navigation in `lib/core/routing/app_router.dart` (line 111) and `lib/features/chat/presentation/pages/chat_list_screen.dart` (line 243)
- [x] T024 [US4] Verify `ChatRoomScreen` AppBar conditionally renders Group vs P2P metadata based on `chatData.type` in `lib/features/chat/presentation/pages/chat_room_screen.dart`

**Checkpoint**: Group Chat rooms persist their `ChatRoomType.GROUP` across exit/re-entry.

---

## Phase 7: User Story 6 - Message Rendering Fix (Priority: P0) 🐛

**Goal**: System/admin event messages (e.g., "created the group") must render correctly. Root cause: Flutter `MessageType` enum lacks `system` case.

**Independent Test**: Open a Group Chat with system messages — all must render as centered event bubbles.

### Implementation for User Story 6

- [x] T025 [US6] [P] Add `system` to `MessageType` enum and add `case 'system':` to `messageTypeFromString()` in `lib/features/chat/domain/entities/message.dart`
- [x] T026 [US6] [P] Add `system` case to `_mediaPreview()` helper (return `'ℹ️ System'`) in `lib/features/chat/data/datasources/chat_local_data_source.dart` (line 64-77)
- [x] T027 [US6] Implement `_buildSystemBubble()` widget — centered, no avatar, no status ticks, styled with `AppColors.textSecondary` — in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T028 [US6] Add routing logic in `MessageBubbleWidget.build()` to detect `MessageType.system` (or sentinel senderId `000000000000000000000000`) and render `_buildSystemBubble()` in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

**Checkpoint**: Zero messages silently dropped — system events render as centered bubbles.

---

## Phase 8: User Story 5 - Group Info Logic Integration (Priority: P1)

**Goal**: Connect `GroupInfoPage` UI to real business logic — display real-time members, description, admin status from SQLite.

**Independent Test**: Open Group Info — participant names, admin badges, and description must be sourced from DB.

### Implementation for User Story 5

- [x] T029 [US5] Replace static "Add description for group" text with dynamic description field from `ChatSession` (add `description` field if needed) in `lib/features/chat/presentation/pages/group_info_page.dart` (line 248-261)
- [x] T030 [US5] Replace hardcoded media section (`itemCount: 4` placeholder) with real media query or empty state in `lib/features/chat/presentation/pages/group_info_page.dart` (lines 263-306)
- [x] T031 [US5] [P] Replace remaining hardcoded `Colors.*` literals with `AppColors` in `lib/features/chat/presentation/pages/group_info_page.dart`
- [x] T032 [US5] Wire the "Edit" AppBar button to a group name/description edit dialog in `lib/features/chat/presentation/pages/group_info_page.dart` (line 129)

**Checkpoint**: GroupInfoPage displays real data from the database.

---

## Phase 9: User Story 7 - Chat Attachment Actions (Priority: P1)

**Goal**: Implement Camera, Location, Audio, Poll, Event attachment actions end-to-end. (Gallery, Document, Contact already implemented.)

**Independent Test**: Open attachment sheet, tap each action, complete the flow — message must be sent and rendered.

### Backend Changes

- [x] T033 [US7] [P] Add `LOCATION`, `AUDIO`, `POLL`, `EVENT` to `MessageType` enum in `E:\zeyad\chat-app-backend\src\modules\chat\schemas\message.schema.ts`
- [x] T034 [US7] [P] Add `latitude`, `longitude`, `address`, `question`, `options`, `votes`, `title`, `dateTime`, `description` fields to `MessageMetadata` in `E:\zeyad\chat-app-backend\src\modules\chat\schemas\message.schema.ts`

### Flutter Domain Layer

- [x] T035 [US7] [P] Add `location`, `audio`, `poll`, `event` to `MessageType` enum and update `messageTypeFromString()` + `messageTypeToString()` in `lib/features/chat/domain/entities/message.dart`
- [x] T036 [US7] [P] Update `_mediaPreview()` to handle new types (`📍 Location`, `🎵 Audio`, `📊 Poll`, `📅 Event`) in `lib/features/chat/data/datasources/chat_local_data_source.dart`

### Flutter Dependencies & Config

- [x] T037 [US7] Add `google_maps_flutter`, `geolocator`, `geocoding`, `flutter_dotenv` to `pubspec.yaml` and run `flutter pub get`
- [x] T038 [US7] Create `.env` file at project root with `GOOGLE_MAPS_API_KEY` placeholder and add `.env` to `.gitignore`
- [x] T039 [US7] Configure Android (`AndroidManifest.xml`: Maps API key meta-data + location permissions) and iOS (`AppDelegate.swift`: GMSServices + `Info.plist` location usage description)

### Flutter Cubit Methods

- [x] T040 [US7] Implement `sendCameraMessage(BuildContext context)` method using `ImagePicker(source: ImageSource.camera)` → upload → socket emit in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T041 [US7] Implement `sendLocationMessage(double lat, double lng, String address)` method → socket emit with `MessageType.location` + metadata in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T042 [US7] Implement `sendAudioMessage(BuildContext context)` method using `FilePicker` with audio filter → upload → socket emit in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T043 [US7] Implement `sendPollMessage(String question, List<String> options)` method → socket emit with `MessageType.poll` + metadata in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [x] T044 [US7] Implement `sendEventMessage(String title, DateTime dateTime, String description)` method → socket emit with `MessageType.event` + metadata in `lib/features/chat/presentation/bloc/chat_cubit.dart`

### Flutter Attachment Sheet Handlers

- [x] T045 [US7] Wire `_handleCamera` handler → `ChatCubit.sendCameraMessage()` in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T046 [US7] Wire `_handleLocation` handler → show `google_maps_flutter` picker → `ChatCubit.sendLocationMessage()` in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T046b [US7] Implement graceful handling of location permission denial during the Location attachment flow in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T047 [US7] Wire `_handleAudio` handler → `ChatCubit.sendAudioMessage()` in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T048 [US7] Wire `_handlePoll` handler → show poll creation dialog → `ChatCubit.sendPollMessage()`. Hide/disable Poll option when `ChatSession.type == PRIVATE` in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T049 [US7] Wire `_handleEvent` handler → show event creation dialog → `ChatCubit.sendEventMessage()` in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`
- [x] T050 [US7] Update `_routeTap` switch to route Camera, Location, Audio, Poll, Event to their handlers in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart`

### Flutter Message Bubble Renderers

- [x] T051 [US7] [P] Implement `_buildLocationBubble()` — Google Maps Static API thumbnail + tap-to-open in native maps in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T052 [US7] [P] Implement `_buildAudioBubble()` — playback widget with duration + play/pause button in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T053 [US7] [P] Implement `_buildPollBubble()` — question + votable options with tap-to-vote in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T054 [US7] [P] Implement `_buildEventBubble()` — title + date/time + description card in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T055 [US7] Add routing logic in `MessageBubbleWidget.build()` to detect `location`, `audio`, `poll`, `event` types and render corresponding bubbles in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`

**Checkpoint**: All 8 attachment actions (Camera, Gallery, Document, Location, Contact, Audio, Poll, Event) complete end-to-end.

---

## Phase 10: User Story 8 - Voice Notes Stability (Priority: P1)

**Goal**: Voice note recording, sending, and playback must work without state leaks, audio overlaps, or disposal errors.

**Independent Test**: Record and send 3 consecutive voice notes, play them back — no overlaps, no exceptions.

### Implementation for User Story 8

- [x] T056 [US8] Audit voice note recording lifecycle in `ChatInputBar` — ensure `RecorderController.stop()` is always called before `dispose()` and on app backgrounding in `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- [x] T057 [US8] Implement singleton audio playback manager — ensure only one audio player is active at a time (stop previous before starting new) in `lib/features/chat/presentation/widgets/message_bubble_widget.dart`
- [x] T058 [US8] Add `mounted` checks after all async operations (record stop, upload, playback) in `lib/features/chat/presentation/widgets/chat_input_bar.dart` and `message_bubble_widget.dart`
- [x] T059 [US8] Verify `AudioWaveforms` controller is properly disposed in widget `dispose()` in `lib/features/chat/presentation/widgets/chat_input_bar.dart`

**Checkpoint**: Voice note recording + playback has zero `PlatformException` errors.

---

## Phase 11: User Story 9 - Static/Mock Data Cleanup (Priority: P2)

**Goal**: Remove all static/mock data from the Chat feature — all data must flow from repositories.

**Independent Test**: `grep -r` for mock/static data arrays in `lib/features/chat/` returns zero results.

### Implementation for User Story 9

- [x] T060 [US9] [P] Delete orphan backup file `lib/features/chat/presentation/pages/chat_screen.dart.bak`
- [x] T061 [US9] [P] Remove hardcoded media placeholder thumbnails in `_buildMediaSection()` in `lib/features/chat/presentation/pages/group_info_page.dart` (lines 284-302)
- [x] T062 [US9] [P] Scan `lib/features/chat/` for any remaining static `List<Message>`, `List<ChatSession>`, or mock data arrays and remove them
- [x] T063 [US9] [P] Replace remaining `Colors.*` literals in `lib/features/chat/presentation/widgets/attachment_sheet_widget.dart` with `AppColors` constants

**Checkpoint**: Zero static/mock data in chat feature.

---

## Phase 12: User Story 10 - Codebase Audit (Priority: P2)

**Goal**: Resolve all pending TODO/FIXME markers and incomplete handlers in the chat feature.

**Independent Test**: Search for `TODO`, `FIXME`, `HACK`, `XXX` in `lib/features/chat/` — all resolved or documented.

### Implementation for User Story 10

- [x] T064 [US10] [P] Scan `lib/features/chat/` for `TODO`, `FIXME`, `HACK`, `XXX` markers — resolve each or document deferral reason
- [x] T065 [US10] [P] Scan `lib/features/chat/` for commented-out function bodies or dead code — remove or restore
- [x] T066 [US10] [P] Verify all `StreamSubscription` instances have matching `.cancel()` calls in `close()` or `dispose()` in `lib/features/chat/presentation/bloc/chat_cubit.dart`

**Checkpoint**: All TODO/FIXME markers resolved or documented.

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup across all user stories

- [x] T067 [P] Verify `_mediaPreview()` handles ALL `MessageType` values (text, image, file, voiceNote, contact, system, location, audio, poll, event) in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T068 Run full `flutter analyze` — zero warnings/errors across `lib/features/chat/`
- [x] T069 Validate quickstart.md — all setup steps (`.env`, Android/iOS config, pubspec deps) are accurate and complete
- [x] T070 Final smoke test — open P2P chat, Group chat, send all message types, verify rendering

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1-5** (T001-T020): ✅ COMPLETED in prior session
- **Phase 6** (US4 - Group Bug): No dependencies on other new phases — can start immediately
- **Phase 7** (US6 - Message Rendering): No dependencies — can run parallel with Phase 6
- **Phase 8** (US5 - Group Info): Depends on Phase 6 (needs correct room type)
- **Phase 9** (US7 - Attachments): Depends on Phase 7 (needs extended MessageType enum)
- **Phase 10** (US8 - Voice Notes): No dependencies — can run parallel with Phase 9
- **Phase 11** (US9 - Cleanup): No dependencies — can run anytime
- **Phase 12** (US10 - Audit): No dependencies — can run anytime
- **Phase 13** (Polish): Depends on ALL previous phases

### Parallel Opportunities

- **Phase 6 + Phase 7**: Can run in parallel (different files, no conflicts)
- **Phase 10 + Phase 11 + Phase 12**: Can all run in parallel
- **T033 + T034**: Backend changes can run parallel with Flutter domain changes (T035 + T036)
- **T051-T054**: All bubble renderers can be implemented in parallel

---

## Implementation Strategy

### MVP First (P0 Bugs)

1. Complete Phase 6: Group Chat Bug Fix (T021-T024)
2. Complete Phase 7: Message Rendering Fix (T025-T028)
3. **STOP and VALIDATE**: Both P0 bugs fixed

### Incremental Delivery

1. P0 bugs → Foundation stable
2. Phase 8 (Group Info) + Phase 9 (Attachments) → Core features
3. Phase 10 (Voice Notes) → Stability
4. Phase 11-12 (Cleanup + Audit) → Technical debt
5. Phase 13 (Polish) → Ship-ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
