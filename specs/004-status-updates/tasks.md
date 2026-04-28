# Tasks: Status Updates Screen

**Input**: Design documents from `/specs/004-status-updates/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter Feature**: `lib/features/status/`
- **Data Layer**: `lib/features/status/data/`
- **Domain Layer**: `lib/features/status/domain/`
- **Presentation Layer**: `lib/features/status/presentation/`
- **Core Logic**: `lib/core/`
- **Tests**: `test/features/status/`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create feature directory structure (`data`, `domain`, `presentation`) in `lib/features/status/`
- [x] T002 Register `StatusCubit` and repository dependencies in `lib/core/di/injection.dart`
- [x] T003 [P] Setup `UpdatesScreen` route in `lib/core/routing/app_router.dart`
- [x] T004 Create `statuses` table creation query in `lib/core/services/database_helper.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T005 Create domain entity in `lib/features/status/domain/entities/status_entity.dart`
- [x] T006 Define abstract repository interface in `lib/features/status/domain/repositories/status_repository.dart`
- [x] T007 Implement data model (DTO) in `lib/features/status/data/models/status_model.dart`
- [x] T008 Create empty abstract data sources (remote/local) in `lib/features/status/data/datasources/`
- [x] T009 Create basic repository shell in `lib/features/status/data/repositories/status_repository_impl.dart`
- [x] T010 Setup `StatusCubit` and `StatusState` in `lib/features/status/presentation/bloc/status_cubit.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View Recent Statuses (Priority: P1) 🎯 MVP

**Goal**: Users can view a list of recent, unread statuses from their contacts which auto-syncs in real time via Socket.io.

**Independent Test**: Open the Updates tab and verify the "Recent status" list populates from local cache and updates upon new socket events.

### Implementation for User Story 1

- [x] T011 [US1] Implement `getStatuses(isViewed: false)` and `cacheStatus` in `lib/features/status/data/datasources/status_local_data_source.dart`
- [x] T012 [US1] Implement `onStatusReceived` stream in `lib/features/status/data/datasources/status_remote_data_source.dart`
- [x] T013 [US1] Implement `getRecentStatuses()` and `statusStream` in `lib/features/status/data/repositories/status_repository_impl.dart`
- [x] T014 [US1] Update `StatusCubit` to handle `loadRecentStatuses()` and listen to the socket stream
- [x] T015 [US1] Create UI `StatusTile` widget in `lib/features/status/presentation/widgets/status_tile.dart` (green ring for unviewed)
- [x] T016 [US1] Build `UpdatesScreen` base UI and "Recent status" section in `lib/features/status/presentation/pages/updates_screen.dart`
- [x] T017 [US1] [P] Write unit tests for local data source retrieval in `test/features/status/data/status_local_data_source_test.dart`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - View Presented/Viewed Statuses (Priority: P1)

**Goal**: Users see a separate list of statuses they have already viewed, loaded from local history.

**Independent Test**: Tap an unread status, return, and verify it moves to "Status that were presented".

### Implementation for User Story 2

- [x] T018 [US2] Implement `getStatuses(isViewed: true)` and `markAsViewed()` in `lib/features/status/data/datasources/status_local_data_source.dart`
- [x] T019 [US2] Implement `notifyViewed()` API call in `lib/features/status/data/datasources/status_remote_data_source.dart`
- [x] T020 [US2] Implement `getViewedStatuses()` and `markAsViewed()` in `lib/features/status/data/repositories/status_repository_impl.dart`
- [x] T021 [US2] Update `StatusCubit` to handle `loadViewedStatuses()` and `markStatusAsViewed()`
- [x] T022 [US2] Add "Status that were presented" section to `lib/features/status/presentation/pages/updates_screen.dart` (grey ring for viewed)
- [x] T023 [US2] [P] Write unit tests for mark-as-viewed logic in `test/features/status/presentation/bloc/status_cubit_test.dart`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Add New Status (Priority: P2)

**Goal**: Users can add a new status via the top tile or FABs.

**Independent Test**: Tap Camera FAB, upload an image, and verify it appears in the active status ring for the user.

### Implementation for User Story 3

- [x] T024 [US3] Implement `uploadStatus()` API call in `lib/features/status/data/datasources/status_remote_data_source.dart`
- [x] T025 [US3] Implement `getMyStatus()` in local data source and repository.
- [x] T026 [US3] Implement `addStatus()` in `lib/features/status/data/repositories/status_repository_impl.dart`
- [x] T027 [US3] Update `StatusCubit` to handle `addStatus()` and error states (Failure mapping).
- [x] T028 [US3] Build "Add Status" top tile in `lib/features/status/presentation/pages/updates_screen.dart`
- [x] T029 [US3] Add Camera and Pencil `FloatingActionButton`s in `lib/features/status/presentation/pages/updates_screen.dart`

**Checkpoint**: All 3 user stories functional.

---

## Phase 6: User Story 4 - Search Statuses (Priority: P2)

**Goal**: Users can search for specific statuses by author name across both sections.

**Independent Test**: Type a name in the search bar and verify list filters correctly.

### Implementation for User Story 4

- [x] T030 [US4] Update `StatusCubit` with `searchStatuses(query)` method to filter lists locally.
- [x] T031 [US4] Create `StatusSearchBar` widget in `lib/features/status/presentation/widgets/status_search_bar.dart`
- [x] T032 [US4] Integrate search bar and filtered states into `UpdatesScreen` UI.

---

## Phase 7: User Story 5 - Automatic Expiry (Priority: P1)

**Goal**: Statuses automatically disappear 24 hours after creation.

**Independent Test**: Set device time 25 hours ahead and verify expired statuses are purged from the UI and DB.

### Implementation for User Story 5

- [x] T033 [US5] Implement `deleteExpiredStatuses()` query in `lib/features/status/data/datasources/status_local_data_source.dart`
- [x] T034 [US5] Implement `purgeExpiredStatuses()` in `lib/features/status/data/repositories/status_repository_impl.dart`
- [x] T035 [US5] Update `StatusCubit` to call `purgeExpiredStatuses()` on initialization and timer intervals.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T036 Code cleanup and refactoring in `lib/features/status/`
- [x] T037 Pixel-perfection check against `image_0.png` using core theme values.
- [x] T038 Add integration test for the entire `UpdatesScreen` in `test/features/status/presentation/pages/updates_screen_test.dart`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in sequential priority order (US1 → US2 → US5 → US3 → US4)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### Parallel Opportunities

- Foundational tasks (T005-T010) can be implemented in parallel.
- Data layer tasks (Data Source, Repository) for a single US can be built in parallel.
- US1, US2, and US5 can technically be implemented in parallel once Foundational is done since they are all P1 priorities touching different logic.
