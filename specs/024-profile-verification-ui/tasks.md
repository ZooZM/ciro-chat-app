# Profile Verification UI Implementation Tasks

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and translation/routing setup

- [x] T001 [P] Add translation keys in `assets/translations/en.json`
- [x] T002 [P] Add translation keys in `assets/translations/ar.json`
- [x] T003 [P] Add routing constants, handlers, and update auth redirect logic in `lib/core/routing/app_router.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T004 Create custom stepper widget in `lib/features/auth/presentation/widgets/profile_verification_stepper.dart`
- [x] T005 Create flow screen container in `lib/features/auth/presentation/pages/profile_verification_flow_screen.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Welcome Screen & Navigation (Priority: P1) 🎯 MVP

**Goal**: Users see a welcome screen before starting the profile verification and can navigate through the multi-step form using a shared custom stepper widget.

**Independent Test**: Navigate to the Welcome screen and verify layout, navigation to the flow screen, and verify the custom stepper header renders.

### Implementation for User Story 1

- [x] T006 [US1] Create welcome screen in `lib/features/auth/presentation/pages/profile_verification_welcome_screen.dart`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. You should be able to view the Welcome Screen and tap "Get Started" to see an empty flow.

---

## Phase 4: User Story 2 - Invoice Information (Priority: P1)

**Goal**: Users can input their business details on the first step of the verification process.

**Independent Test**: Can be tested by navigating to Step 1 and verifying the UI layout, input fields, styling, and "Continue" button navigation.

### Implementation for User Story 2

- [x] T007 [P] [US2] Create invoice step widget in `lib/features/auth/presentation/widgets/profile_verification_step_invoice.dart`
- [x] T008 [US2] Integrate invoice step widget into `lib/features/auth/presentation/pages/profile_verification_flow_screen.dart`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Step 1 of the flow should be fully functional.

---

## Phase 5: User Story 3 - Identity Verification (Priority: P1)

**Goal**: Users can mock-verify their identity through multiple UI states (National ID, Document Upload, Selfie).

**Independent Test**: Can be tested by viewing the various mock states of Step 2 independently and verifying the sub-step navigation logic.

### Implementation for User Story 3

- [x] T009 [P] [US3] Create identity step widget in `lib/features/auth/presentation/widgets/profile_verification_step_identity.dart`
- [x] T010 [US3] Integrate identity step widget into `lib/features/auth/presentation/pages/profile_verification_flow_screen.dart`

**Checkpoint**: All P1 user stories should now be functional. Steps 1 and 2 of the flow should render correctly.

---

## Phase 6: User Story 4 - Bank Account Verification (Priority: P2)

**Goal**: Users can provide bank details with inline validation UI states and a custom dropdown.

**Independent Test**: Can be tested by viewing Step 3 UI, verifying the IBAN mock success validation, and interacting with the custom dropdown.

### Implementation for User Story 4

- [x] T011 [P] [US4] Create bank account step widget in `lib/features/auth/presentation/widgets/profile_verification_step_bank.dart`
- [x] T012 [US4] Integrate bank account step widget into `lib/features/auth/presentation/pages/profile_verification_flow_screen.dart`

**Checkpoint**: User stories 1-4 should now be fully functional.

---

## Phase 7: User Story 5 - Review Information (Priority: P2)

**Goal**: Users can review all entered information on a summary screen before activation.

**Independent Test**: Can be tested by viewing Step 4 and verifying the summary cards display mock data and badges correctly.

### Implementation for User Story 5

- [x] T013 [P] [US5] Create review step widget in `lib/features/auth/presentation/widgets/profile_verification_step_review.dart`
- [x] T014 [US5] Integrate review step widget into `lib/features/auth/presentation/pages/profile_verification_flow_screen.dart`

**Checkpoint**: All user stories should now be functional. The entire 4-step flow is complete.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T015 Verify RTL support and translations completeness across all UI states manually
- [x] T016 Verify keyboard scrolling behavior and responsive spacing across all fields
- [x] T017 Create success screen in `lib/features/auth/presentation/pages/profile_verification_success_screen.dart`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1, US2, US3, US4, US5**: Each depends on Foundational (Phase 2). They can be developed mostly in parallel by creating their step widgets independently, but integration into the flow screen is somewhat sequential.

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T001, T002, T003)
- The creation of the step widgets (T007, T009, T011, T013) can all happen in parallel before being integrated into the flow screen.

---

## Implementation Strategy

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 (Welcome) → Test independently
3. Add User Story 2 (Invoice) → Test independently
4. Add User Story 3 (Identity) → Test independently
5. Add User Story 4 (Bank) → Test independently
6. Add User Story 5 (Review) → Test independently
7. Each step adds value without breaking previous stories.
