# Tasks: Group Call UI Update

**Input**: Design documents from `specs/`
**Prerequisites**: `group_call_ui_plan.md`, `group_call_ui_update.md`, `group_call_ui_data-model.md`, `group_call_ui_research.md`

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Update global translation files needed by all user stories.

- [x] T001 Add group call UI translation keys to `assets/translations/en.json`
- [x] T002 Add group call UI translation keys to `assets/translations/ar.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented
*Note: Since this is purely a UI update modifying existing files, there are no foundational blocking data-layer tasks required.*

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Incoming Group Call (Priority: P1) 🎯 MVP

**Goal**: Users should see a clear, localized incoming call screen indicating who is calling and giving options to join or ignore.

**Independent Test**: Can be tested by triggering a mock incoming call state and verifying UI layout and localized text.

### Implementation for User Story 1

- [x] T003 [US1] Update `lib/features/video_call/presentation/pages/incoming_group_call_screen.dart` to use new `easy_localization` keys for text elements.
- [x] T004 [US1] Ensure the "Ignore" button in `lib/features/video_call/presentation/pages/incoming_group_call_screen.dart` purely dismisses the UI without executing any backend Socket.io decline logic.

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 3 - Active Group Call Grid (Priority: P1)

**Goal**: Users in a group call should see a dynamic grid of participants with their names and call controls.

**Independent Test**: Mock a call with 5-10 participants and verify the grid layout, participant counts, and controls.

### Implementation for User Story 3

- [x] T005 [P] [US3] Update `lib/features/video_call/presentation/widgets/participant_grid.dart` to dynamically render 1-9 participants correctly using localized strings.
- [x] T006 [US3] Update `lib/features/video_call/presentation/widgets/participant_grid.dart` to implement the "+N others" logic when there are more than 10 participants.
- [x] T007 [P] [US3] Update `lib/features/video_call/presentation/widgets/call_controls.dart` to include the magic wand, screen share, and record buttons, ensuring the magic wand performs no action.
- [x] T008 [US3] Integrate the updated widgets and localized header string into `lib/features/video_call/presentation/pages/group_call_screen.dart`.

**Checkpoint**: At this point, User Stories 1 AND 3 should both work independently

---

## Phase 5: User Story 2 - Waiting for Others (Priority: P2)

**Goal**: When a user joins a call before others, they should see a waiting screen.

**Independent Test**: Join a call with no other participants and verify the waiting state UI.

### Implementation for User Story 2

- [x] T009 [US2] Update `lib/features/video_call/presentation/pages/group_call_screen.dart` to render the localized "Waiting for other people to join..." text and placeholder avatar when the participant count is exactly 1.

**Checkpoint**: All user stories should now be independently functional

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T010 Validate `easy_localization` toggles correctly between English and Arabic layouts across all three screens.
- [x] T011 Verify UI doesn't overflow during dynamic participant count scaling (e.g. going from 1 -> 5 -> 15 active speakers).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **User Stories (Phase 3+)**: US1 and US3 (both P1) can be started in parallel once Phase 1 is done. US2 can follow US3 since they both touch `group_call_screen.dart`.

### Implementation Strategy

1. Complete Phase 1: Setup translations.
2. Complete Phase 3: Incoming Call UI (US1) -> Demo MVP.
3. Complete Phase 4: Grid UI (US3) -> Demo.
4. Complete Phase 5: Waiting UI (US2) -> Demo.
