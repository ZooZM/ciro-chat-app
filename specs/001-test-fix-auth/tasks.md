# Tasks: Auth Testing and Bug Fix

**Input**: Design documents from `specs/001-test-fix-auth/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are MANDATORY for this feature as its primary goal is testing and bug fixing.

**Organization**: Tasks are grouped by foundational refactoring and then by user story to ensure a robust testing base.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)

## Path Conventions

- **Flutter Feature**: `lib/features/auth/`
- **Data Layer**: `lib/features/auth/data/`
- **Domain Layer**: `lib/features/auth/domain/`
- **Presentation Layer**: `lib/features/auth/presentation/`
- **Core Logic**: `lib/core/`
- **Tests**: `test/features/auth/`

---

## Phase 1: Setup (Infrastructural Refactor)

**Purpose**: Prepare the codebase for testability by introducing standard error handling and repository interfaces.

- [x] T001 Create domain failures in `lib/core/error/failures.dart`
- [x] T002 Refactor `AuthRepository` interface in `lib/features/auth/domain/repositories/auth_repository.dart` to return `Either<Failure, T>`
- [x] T003 [P] Update `AuthState` in `lib/features/auth/presentation/bloc/auth_state.dart` to include `Failure` in `AuthError`
- [x] T004 [P] Configure `mocktail` and `bloc_test` dependencies in `pubspec.yaml` (verify if already present)

---

## Phase 2: Foundational (Data & Domain Testing)

**Purpose**: Ensure the data and domain layers are correctly implemented and tested before moving to the presentation layer.

- [x] T005 [P] Create mocks for `Dio`, `FlutterSecureStorage`, and data sources in `test/features/auth/mocks.dart`
- [x] T006 [P] Write unit tests for `AuthRemoteDataSource` in `test/features/auth/data/datasources/auth_remote_data_source_test.dart`
- [x] T007 [P] Write unit tests for `AuthLocalDataSource` in `test/features/auth/data/datasources/auth_local_data_source_test.dart`
- [x] T008 [P] Refactor `AuthRepositoryImpl` in `lib/features/auth/data/repositories/auth_repository_impl.dart` to implement the new interface with `Either`
- [x] T009 Write unit tests for `AuthRepositoryImpl` in `test/features/auth/data/repositories/auth_repository_impl_test.dart` (covers US1 logic)

**Checkpoint**: Foundational layers are refactored, tested, and ready for Cubit integration.

---

## Phase 3: User Story 1 - Verify Authentication Logic (Priority: P1) 🎯 MVP

**Goal**: Ensure `AuthCubit` handles all authentication flows, state transitions, and bug fixes correctly.

**Independent Test**: Run `flutter test test/features/auth/presentation/bloc/auth_cubit_test.dart`

### Implementation for User Story 1

- [x] T010 [US1] Create unit test file `test/features/auth/presentation/bloc/auth_cubit_test.dart` with `getIt` mock registrations
- [x] T011 [US1] Write test for `verifyAuthStatus` handling `Authenticated` and `Unauthenticated` states
- [x] T012 [US1] Write test for `submitPhoneNumber` handling success and failure
- [x] T013 [US1] Write test for `submitOtp` handling success and failure
- [x] T014 [US1] Write test for `logOut` ensuring all teardown steps (Socket, Cubits, Storage) are called
- [x] T015 [US1] Refactor `AuthCubit` in `lib/features/auth/presentation/bloc/auth_cubit.dart` to fix identified bugs (delay, raw string errors)
- [x] T016 [US1] Verify 100% coverage for `AuthCubit` transitions

**Checkpoint**: Core authentication logic is verified and robust.

---

## Phase 4: User Story 2 - UI State Integrity (Priority: P2)

**Goal**: Ensure the Auth UI correctly reflects the internal states and handles user interactions.

**Independent Test**: Run `flutter test test/features/auth/presentation/pages/`

### Implementation for User Story 2

- [x] T017 [P] [US2] Write widget test for Login page loading state in `test/features/auth/presentation/pages/login_page_test.dart`
- [x] T018 [P] [US2] Write widget test for OTP page error handling in `test/features/auth/presentation/pages/otp_page_test.dart`
- [x] T019 [US2] Write widget test for logout interaction and navigation
- [x] T020 [US2] Verify user-friendly error messages are displayed on failure states

**Checkpoint**: Auth UI is verified to be consistent with internal state changes.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation.

- [x] T021 Run all tests in `test/features/auth/` and ensure 0 failures
- [x] T022 Generate final coverage report and verify SC-002 (>90% coverage)
- [x] T023 Update `quickstart.md` if any new test steps were added
- [x] T024 Perform a final check against the Constitution for compliance

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Prerequisites for all subsequent phases.
- **Foundational (Phase 2)**: Depends on Phase 1 completion.
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion.
- **User Story 2 (Phase 4)**: Depends on Phase 3 completion (UI depends on Cubit logic).
- **Polish (Final Phase)**: Depends on all stories being complete.

### Within Each User Story

- Setup mocks and registrations first
- Write failing tests for each scenario
- Refactor/Fix implementation to pass tests
- Verify coverage

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup and Foundational refactoring.
2. Complete all tests and fixes for `AuthCubit` (US1).
3. **VALIDATE**: Ensure core auth logic is 100% covered and bug-free.

### Incremental Delivery

1. Setup + Foundational -> Stable Base
2. US1 -> Reliable Auth Logic (MVP)
3. US2 -> Reliable Auth UI
4. Polish -> Final verification
