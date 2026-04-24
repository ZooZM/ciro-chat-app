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

- [ ] T001 Create `CallState` in `lib/features/call/presentation/bloc/call_state.dart` (or suitable location if call feature exists). Assuming it's part of the new overlay structure, place it in `lib/features/chat/presentation/bloc/call_state.dart` or a shared core/call feature location if available. We will assume `lib/features/chat/presentation/bloc/` for now based on context.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [ ] T002 Refactor `SocketService` to separate messaging events from call signaling events in `lib/core/network/socket_service.dart` (or wherever it currently resides).
- [ ] T003 Ensure `Message` entity uses `MessageStatus` correctly in `lib/features/chat/domain/entities/message.dart`
- [ ] T004 Create or update `CallCubit` to manage `CallState` in `lib/features/chat/presentation/bloc/call_cubit.dart` (or dedicated call feature).
- [ ] T005 Register `CallCubit` in `lib/core/di/injection.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Real-time Chat Experience (Priority: P1) 🎯 MVP

**Goal**: Users should experience a seamless, lag-free real-time P2P and Group chat experience without unnecessary UI stutters or rebuilds when receiving rapid socket updates.

**Independent Test**: Can be fully tested by sending multiple rapid messages in P2P and Group chats and verifying the UI remains responsive and does not needlessly rebuild non-affected widgets.

### Implementation for User Story 1

- [ ] T006 [US1] Update `ChatState` to optimize field updates via `copyWith` in `lib/features/chat/presentation/bloc/chat_state.dart`
- [ ] T007 [US1] Refactor `ChatCubit` to selectively emit state changes (e.g., typing vs new message) in `lib/features/chat/presentation/bloc/chat_cubit.dart`
- [ ] T008 [US1] Refactor `ChatPage` to use `buildWhen` in `BlocBuilder` for targeted rebuilds in `lib/features/chat/presentation/pages/chat_page.dart`
- [ ] T009 [US1] Refactor list rendering in `ChatPage` (e.g., using `ListView.builder` optimally) to avoid full rebuilds in `lib/features/chat/presentation/pages/chat_page.dart`
- [ ] T010 [US1] Extract typing indicator into a separate `BlocBuilder` widget listening only to typing changes in `lib/features/chat/presentation/widgets/typing_indicator.dart`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Rapid socket updates should not cause full page rebuilds.

---

## Phase 4: User Story 2 - Non-Intrusive Call Integration (Priority: P1)

**Goal**: Users receiving or initiating Voice and Video calls should not have their text chat flow interrupted. The call state should act as an overlay or distinct state.

**Independent Test**: Can be fully tested by initiating a call while actively typing or reading messages, ensuring the chat UI remains accessible or gracefully manages the call UI.

### Implementation for User Story 2

- [ ] T011 [US2] Implement `CallOverlay` widget to display active/incoming calls in `lib/features/chat/presentation/widgets/call_overlay.dart`
- [ ] T012 [US2] Integrate `CallOverlay` into the root widget tree or `ChatPage` stack in `lib/features/chat/presentation/pages/chat_page.dart`
- [ ] T013 [US2] Connect `CallOverlay` to `CallCubit` to react to `CallState` changes in `lib/features/chat/presentation/widgets/call_overlay.dart`
- [ ] T014 [US2] Verify `SocketService` properly delegates call events (`call_initiate`, `call_answer`, etc.) to `CallCubit` without affecting `ChatCubit` in `lib/core/network/socket_service.dart`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Call integration should be non-intrusive.

---

## Phase 5: User Story 3 - Codebase Consistency (Priority: P2)

**Goal**: The chat feature strictly adheres to the core design system and utility classes, ensuring visual and architectural consistency.

**Independent Test**: Can be tested by verifying that no hardcoded strings, colors, or icons are used in the chat feature UI, and all styling comes from `lib/core/`.

### Implementation for User Story 3

- [ ] T015 [US3] [P] Scan and replace hardcoded colors with `AppColors` (or equivalent) in `lib/features/chat/presentation/pages/`
- [ ] T016 [US3] [P] Scan and replace hardcoded text styles with `AppTheme.textStyles` (or equivalent) in `lib/features/chat/presentation/pages/`
- [ ] T017 [US3] [P] Scan and replace hardcoded strings with localized strings or constants in `lib/features/chat/presentation/widgets/`
- [ ] T018 [US3] [P] Scan and replace hardcoded icons with core icons in `lib/features/chat/presentation/widgets/`

**Checkpoint**: All user stories should now be independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T019 [P] Code cleanup and refactoring across modified files.
- [ ] T020 Run quickstart.md validation locally.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### Parallel Opportunities

- All tasks marked [P] in User Story 3 can be run in parallel.
