---
description: "Task list template for feature implementation"
---

# Tasks: 023-dynamic-group-call

**Input**: Design documents from `/specs/023-dynamic-group-call/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [P] Setup feature-specific routes in `lib/core/routing/app_router.dart`
- [x] T002 [P] Add translation keys in `assets/translations/en.json`
- [x] T003 [P] Add translation keys in `assets/translations/ar.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T004 Create `CallParticipant` domain entity and mock data in `lib/features/video_call/presentation/data/mock_call_participants.dart`
- [x] T005 Build reusable `MockParticipantTile` widget in `lib/features/video_call/presentation/widgets/mock_participant_tile.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - View Active Group Call with 4–6 Participants (Priority: P1) 🎯 MVP

**Goal**: A user joins a group call with 4 to 6 participants and sees a 2-column grid of participant cells. Each cell displays either a live video placeholder or a centered avatar on a vibrant solid-color background. Small floating badges indicate mute status and active speaker status.

**Independent Test**: Set `participantCount = 4` (then 5, then 6) using the mock state variable. Verify the 2-column grid renders correctly, all cells show the correct avatar-or-video state, and overlay badges appear in the expected positions.

### Implementation for User Story 1

- [x] T006 [US1] Create basic screen structure and `StatefulWidget` in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`
- [x] T007 [US1] Implement `_buildWaitingLayout()` for count <= 1 in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`
- [x] T008 [US1] Implement `_buildGridLayout()` for count >= 4 in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`
- [x] T009 [US1] Build header section with group name and participant count in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently (for grid layouts).

---

## Phase 4: User Story 2 - View Active Call with 2 Participants (P2P) (Priority: P2)

**Goal**: When only 2 participants are present, the screen re-uses the standard 1-on-1 call layout: the remote user is shown full-screen, and the local user appears in a small, draggable floating picture-in-picture (PIP) window.

**Independent Test**: Set `participantCount = 2`. Verify the full-screen remote view and the floating PIP for the local user both render correctly.

### Implementation for User Story 2

- [x] T010 [US2] Implement `_buildP2PLayout()` in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`
- [x] T011 [US2] Integrate P2P layout selection logic into `build()` based on `_participantCount == 2` in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently.

---

## Phase 5: User Story 3 - View Active Call with 3 Participants (Priority: P2)

**Goal**: When exactly 3 participants are present, the screen uses a split layout: the top half shows one participant at full width, while the bottom half is split into two equal columns for the other two participants.

**Independent Test**: Set `participantCount = 3`. Verify the top-half / bottom-half split renders correctly.

### Implementation for User Story 3

- [x] T012 [US3] Implement `_buildTriSplitLayout()` in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`
- [x] T013 [US3] Integrate Tri-split layout selection logic into `build()` based on `_participantCount == 3` in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`

**Checkpoint**: All user stories should now be independently functional.

---

## Phase 6: User Story 4 - Manually Test Different Layouts via State Variable (Priority: P3)

**Goal**: A developer or tester can manually change the `participantCount` state variable to switch between layouts (2, 3, 4, 5, 6) and verify each layout without needing any live calling infrastructure.

**Independent Test**: Change `participantCount` from 2 to 6 in increments; verify layout transitions are correct and no overflow or rendering errors occur.

### Implementation for User Story 4

- [x] T014 [US4] Verify layout toggles flawlessly on hot-reload and ensure no UI overflow occurs for counts up to 6+ in `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart`

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T015 Run quickstart.md validation
- [x] T016 Code cleanup and refactoring (ensure imports and styles follow project standards)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after User Story 1 (P1)
- **User Story 3 (P2)**: Can start after User Story 2 (P2)
- **User Story 4 (P3)**: Can start after User Story 3 (P2)

### Parallel Opportunities

- All Setup tasks (T001, T002, T003) marked [P] can run in parallel.
- Once the foundational widget (`MockParticipantTile`) and data model are ready, building the different layouts in `dynamic_group_call_screen.dart` can be tested independently.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently (4-6 participant grid)

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories
