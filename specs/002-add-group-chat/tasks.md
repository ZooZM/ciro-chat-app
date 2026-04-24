# Tasks: Add Group Chat

**Input**: Design documents from `specs/002-add-group-chat/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests were NOT explicitly requested in the feature specification, so no test tasks are generated.

**Organization**: Tasks are grouped by foundational data layer updates and then by user story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)

## Path Conventions

- **Flutter Feature**: `lib/features/chat/`
- **Data Layer**: `lib/features/chat/data/`
- **Domain Layer**: `lib/features/chat/domain/`
- **Presentation Layer**: `lib/features/chat/presentation/`
- **Core Logic**: `lib/core/`

---

## Phase 1: Setup & Foundational (Data Model & Schema)

**Purpose**: Update the core data structures and local database schema to support group chat fields before implementing UI.

- [x] T001 Update `ChatRoom` entity in `lib/features/chat/domain/entities/chat_room.dart` to include `type`, `name`, `avatarUrl`, and `admins`
- [x] T002 [P] Update `ChatRoomModel` in `lib/features/chat/data/models/chat_room_model.dart` for `fromJson`/`toJson` mapping of new fields
- [x] T003 Update SQLite schema and migration logic in `lib/features/chat/data/datasources/chat_local_data_source.dart`
- [x] T004 [P] Define REST API endpoints in `lib/features/chat/data/datasources/chat_remote_data_source.dart` (Create, Add, Remove, Leave)
- [x] T005 [P] Update `ChatRepository` interface in `lib/features/chat/domain/repositories/chat_repository.dart` with new group methods
- [x] T006 Implement new methods in `ChatRepositoryImpl` in `lib/features/chat/data/repositories/chat_repository_impl.dart`

**Checkpoint**: The app can store and parse group chat rooms locally and remotely.

---

## Phase 2: User Story 1 - Create a Group Chat (Priority: P1) 🎯 MVP

**Goal**: Allow users to select multiple contacts and create a new group chat.

**Independent Test**: Navigate to the contacts list, select multiple contacts, provide a group name, tap "Create", and verify the app navigates to the new group chat screen.

### Implementation for User Story 1

- [x] T007 [US1] Create UI `CreateGroupPage` in `lib/features/chat/presentation/pages/create_group_page.dart` for contact selection and name input
- [x] T008 [US1] Update `ChatCubit` in `lib/features/chat/presentation/bloc/chat_cubit.dart` to handle group creation logic and state
- [x] T009 [US1] Implement `joinRoom` socket emission in `ChatCubit` immediately after successful group creation
- [x] T010 [US1] Integrate `CreateGroupPage` routing in `lib/core/routing/app_router.dart`
- [x] T011 [US1] Update `ChatListPage` in `lib/features/chat/presentation/pages/chat_list_page.dart` to display group `name` and `avatarUrl`

**Checkpoint**: Users can create a group and see it in their chat list.

---

## Phase 3: User Story 2 - Real-Time Group Messaging (Priority: P1)

**Goal**: Support sending/receiving messages and indicators within the group.

**Independent Test**: Open an existing group chat, send a message, and observe real-time updates and indicators.

### Implementation for User Story 2

- [X] T012 [P] [US2] Update `ChatBubble` widget in `lib/features/chat/presentation/widgets/chat_bubble.dart` to conditionally show sender's name/number for group chats
- [X] T013 [US2] Update `ChatDetailPage` in `lib/features/chat/presentation/pages/chat_detail_page.dart` to handle group routing and header display
- [X] T014 [US2] Verify `typing` and `userTyping` socket events in `ChatCubit` handle group `roomId`s correctly

**Checkpoint**: Users can chat seamlessly in groups with clear sender identification.

---

## Phase 4: User Story 3 - Group Administration (Priority: P2)

**Goal**: Allow admins to add or remove participants.

**Independent Test**: Open the Group Info screen as an admin and verify the "Add" and "Remove" options function correctly.

### Implementation for User Story 3

- [X] T015 [US3] Create UI `GroupInfoPage` in `lib/features/chat/presentation/pages/group_info_page.dart` to display the participant list
- [X] T016 [US3] Update `ChatCubit` to handle adding and removing participants
- [X] T017 [US3] Implement conditional "Add Participant" and "Remove" UI elements in `GroupInfoPage` based on admin status
- [X] T018 [US3] Add `GroupParticipantTile` widget in `lib/features/chat/presentation/widgets/group_participant_tile.dart`

**Checkpoint**: Admins can manage group membership.

---

## Phase 5: User Story 4 - Leave Group (Priority: P3)

**Goal**: Allow users to leave groups.

**Independent Test**: Select "Leave Group" in the Group Info screen and verify the group disappears from the chat list.

### Implementation for User Story 4

- [ ] T019 [US4] Update `ChatCubit` to handle the "leave group" action
- [ ] T020 [US4] Add a "Leave Group" button in `GroupInfoPage`
- [ ] T021 [US4] Ensure `ChatCubit` clears the room from the local database and UI upon successful departure

**Checkpoint**: Users can leave groups and local state remains consistent.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Blocks all user stories. Must be completed first to establish data structures.
- **Phase 2 (US1 - Create)**: Depends on Phase 1. Must be completed before messaging or admin tasks, as a group must exist first.
- **Phase 3 (US2 - Messaging)**: Depends on Phase 1 and ideally Phase 2 (to have a group to test with).
- **Phase 4 (US3 - Admin)**: Depends on Phase 2.
- **Phase 5 (US4 - Leave)**: Depends on Phase 2.

### Parallel Opportunities

- T002 (Model updates), T004 (Remote API), and T005 (Repository Interface) can be done in parallel during Setup.
- T012 (ChatBubble UI update) can be done in parallel with backend logic in US2.

### Implementation Strategy

#### MVP First
1. Complete Phase 1 (Data structures and API).
2. Complete Phase 2 (Create Group) and Phase 3 (Messaging).
3. Validate: Users can create and chat in groups.

#### Incremental Delivery
1. MVP Delivery (Create + Chat).
2. Add Administration (Phase 4).
3. Add Leave Group (Phase 5).