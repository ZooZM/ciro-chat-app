# Tasks: Profile Tab UI

**Input**: Design documents from `/specs/022-profile-tab-ui/`
**Prerequisites**: plan.md, spec.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Exact file paths are included in descriptions

## Path Conventions

- **Flutter Feature**: `lib/features/profile/`
- **Presentation Layer**: `lib/features/profile/presentation/`
- **Core Logic**: `lib/core/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [P] Create `lib/features/profile/presentation/` directory structure (pages, widgets, data)
- [x] T002 [P] Update `lib/core/routing/app_router.dart` to add 4 new route constants and GoRoute definitions
- [x] T003 [P] Add ~30 localization keys to `assets/translations/en.json` and `assets/translations/ar.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T004 Create `lib/features/profile/presentation/data/mock_profile_data.dart` and populate with data models and static mock lists

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View Profile Tab (Priority: P1) 🎯 MVP

**Goal**: Display the main Profile Tab overview including user section, wallet card, completion progress, and settings list.

**Independent Test**: Navigate to the Profile tab in the bottom navigation and verify all sections render correctly with mock data.

### Implementation for User Story 1

- [x] T005 [P] [US1] Create `lib/features/profile/presentation/widgets/wallet_card.dart`
- [x] T006 [P] [US1] Create `lib/features/profile/presentation/widgets/profile_completion_bar.dart`
- [x] T007 [US1] Create `lib/features/profile/presentation/pages/profile_main_screen.dart` using the new widgets and mock data

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - View QR Code Screen (Priority: P1)

**Goal**: Display the QR Code screen showing the user's avatar, Ciro ID, and QR code placeholder image.

**Independent Test**: Tap the QR Code icon on the Profile tab and verify the layout, text, and buttons render correctly.

### Implementation for User Story 2

- [x] T008 [US2] Create `lib/features/profile/presentation/pages/qr_code_screen.dart` using mock data

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Edit Profile Info (Priority: P2)

**Goal**: Display the Profile Info editing screen with avatar and rounded text input fields.

**Independent Test**: Tap the pencil edit icon on the Profile tab and verify the text fields and Save button render.

### Implementation for User Story 3

- [x] T009 [US3] Create `lib/features/profile/presentation/pages/profile_info_screen.dart`

**Checkpoint**: All P1 and P2 profile editing stories should now be functional

---

## Phase 6: User Story 4 - Customize Appearance (Priority: P2)

**Goal**: Display the Appearance customization screen allowing single-selection of chat theme, color, and background.

**Independent Test**: Navigate to the Appearance screen from the Profile tab settings list and verify all three selection sections render and handle local state correctly.

### Implementation for User Story 4

- [x] T010 [P] [US4] Create `lib/features/profile/presentation/widgets/appearance_theme_list.dart`
- [x] T011 [P] [US4] Create `lib/features/profile/presentation/widgets/appearance_color_grid.dart`
- [x] T012 [P] [US4] Create `lib/features/profile/presentation/widgets/appearance_background_list.dart`
- [x] T013 [US4] Create `lib/features/profile/presentation/pages/appearance_screen.dart` integrating the selection widgets

**Checkpoint**: Appearance customization UI should be fully functional

---

## Phase 7: User Story 5 - Preview Chat Theme (Priority: P3)

**Goal**: Display a full-screen preview of the selected chat theme with mock chat bubbles.

**Independent Test**: Tap the "Preview Chat" button on the Appearance screen and verify the background and mock chat bubbles.

### Implementation for User Story 5

- [x] T014 [US5] Create `lib/features/profile/presentation/pages/chat_theme_preview_screen.dart`

**Checkpoint**: All user stories should now be independently functional

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T015 [P] Verify visual layout matches reference screenshots (padding, brand green color, gradients)
- [x] T016 [P] Validate `easy_localization` keys correctly swap strings on all 5 new screens

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2)
- **User Story 3 (P2)**: Can start after Foundational (Phase 2)
- **User Story 4 (P2)**: Can start after Foundational (Phase 2)
- **User Story 5 (P3)**: Depends on US4 (Preview screen navigated from Appearance screen)

### Within Each User Story

- Widgets before pages
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- Once Foundational phase completes, US1, US2, US3, and US4 can start in parallel (if team capacity allows)
- Widgets within a story marked [P] can run in parallel (e.g. US4 appearance lists)

---

## Parallel Example: User Story 4

```bash
# Launch all widgets for User Story 4 together:
Task: "Create appearance_theme_list.dart"
Task: "Create appearance_color_grid.dart"
Task: "Create appearance_background_list.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Add User Story 4 → Test independently → Deploy/Demo
6. Add User Story 5 → Test independently → Deploy/Demo
7. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
