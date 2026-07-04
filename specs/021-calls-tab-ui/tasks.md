# Tasks: Calls Tab UI

**Input**: Design documents from `/specs/021-calls-tab-ui/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Not requested in feature spec — test tasks omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Feature**: `lib/features/call_history/`
- **Presentation Layer**: `lib/features/call_history/presentation/`
- **Pages**: `lib/features/call_history/presentation/pages/`
- **Widgets**: `lib/features/call_history/presentation/widgets/`
- **Mock Data**: `lib/features/call_history/presentation/data/`
- **Routing**: `lib/core/routing/app_router.dart`
- **Translations**: `assets/translations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Localization keys and mock data that all screens depend on

- [x] T001 Add all new localization keys (~16 keys) to `assets/translations/en.json` with `calls_info_*`, `calls_select_*`, `calls_dialpad_*` prefixes
- [x] T002 [P] Add corresponding Arabic translations to `assets/translations/ar.json`
- [x] T003 [P] Create mock data file with `MockContact` class, `CallDetailEntry` class, `kAvatarPalette` constant, `mockCallHistory`, `mockFrequentContacts`, `mockAllContacts`, and `mockCallDetails` in `lib/features/call_history/presentation/data/mock_call_data.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared widgets and routing infrastructure that MUST be complete before user story screens

- [x] T004 Create shared `ContactAvatar` widget (accepts `initials`, `avatarUrl`, `colorSeed`, `radius`) in `lib/features/call_history/presentation/widgets/contact_avatar.dart`
- [x] T005 [P] Create reusable `CallActionCard` widget (accepts `icon`, `label`, `onTap`) in `lib/features/call_history/presentation/widgets/call_action_card.dart`
- [x] T006 Add 3 new route constants (`callInfo`, `selectContact`, `dialpad`) and their `GoRoute` entries in `lib/core/routing/app_router.dart`

**Checkpoint**: Foundation ready — shared widgets, routes, mock data, and translations are in place. User story implementation can now begin.

---

## Phase 3: User Story 1 — Browse Call History (Priority: P1) 🎯 MVP

**Goal**: Users see a scrollable list of recent calls on the Calls tab with avatars, names, direction arrows, timestamps, and trailing voice/video icons. Tapping the FAB navigates to Select Contact. Tapping a row navigates to Call Information.

**Independent Test**: Navigate to Calls tab → verify 8 mock call entries render with correct avatars, names (red for missed), direction arrows, and trailing icons. Tap a row → verify Call Information screen opens.

### Implementation for User Story 1

- [x] T007 [US1] Update `calls_history_screen.dart` to change tile `onTap` from `_redial` to navigate to `AppRouterName.callInfo` with the `CallHistoryRecord` as extra in `lib/features/call_history/presentation/pages/calls_history_screen.dart`
- [x] T008 [US1] Update `calls_history_screen.dart` FAB `onPressed` to navigate to `AppRouterName.selectContact` instead of `AppRouterName.contacts` in `lib/features/call_history/presentation/pages/calls_history_screen.dart`

**Checkpoint**: Calls History screen now navigates correctly to Call Information and Select Contact screens.

---

## Phase 4: User Story 2 — View Call Information Details (Priority: P1)

**Goal**: Users tap a call entry and see a detail screen with large avatar, contact name, three action cards (Messaging, Video call, Voice call), and a date-grouped call log showing direction, time, and status.

**Independent Test**: From Calls History, tap any row → verify Call Information screen shows centered avatar, name, 3 action cards with green icons and localized labels, and a "Today" section with call detail entries including "Outgoing"/"Incoming" label and "Not answer" status.

### Implementation for User Story 2

- [x] T009 [US2] Build `CallInformationScreen` page with AppBar (back arrow + "Call information" title), large centered `ContactAvatar`, contact name, action row of 3 `CallActionCard` widgets, divider, and date-grouped call log `ListView` in `lib/features/call_history/presentation/pages/call_information_screen.dart`

**Checkpoint**: Full Call Information screen renders with mock data. Navigation from Calls History works end-to-end.

---

## Phase 5: User Story 3 — Select Contact for New Call (Priority: P2)

**Goal**: Users tap the FAB on Calls History and see a contact picker with "New contact" and "Call a number" top actions, "Frequently contacted" and "contact" sections, each entry with a circular avatar and an unselected radio button.

**Independent Test**: From Calls History, tap FAB → verify Select Contact screen shows AppBar with title/subtitle/search icon, "New contact" and "Call a number" rows with green icons, and grouped contact lists with empty radio buttons.

### Implementation for User Story 3

- [x] T010 [US3] Build `SelectContactScreen` as a `StatefulWidget` with AppBar (back arrow, "Select a contact" title, contact count subtitle, search icon), top action items ("New contact", "Call a number"), and grouped contact `ListView` with `ContactAvatar` and trailing radio buttons in `lib/features/call_history/presentation/pages/select_contact_screen.dart`

**Checkpoint**: Select Contact screen renders in empty state with all mock contacts and sections.

---

## Phase 6: User Story 4 — Select Contact and Initiate Call (Priority: P2)

**Goal**: Tapping a contact toggles selection: radio button fills green, a chip bar appears at the top with the selected contact's avatar (with "×" badge), truncated name, and trailing voice/video call icons. Tapping "×" deselects.

**Independent Test**: On Select Contact screen, tap a contact → verify green checkmark appears, chip bar shows with avatar, name, and action icons. Tap "×" → verify deselection reverts to empty state.

### Implementation for User Story 4

- [x] T011 [US4] Add selection state management (`MockContact? _selectedContact`) and selection bar UI (chip with "×" badge, truncated name, voice/video trailing icons) to `SelectContactScreen` in `lib/features/call_history/presentation/pages/select_contact_screen.dart`
- [x] T012 [US4] Implement radio button toggle logic (tap to select/deselect, only one selected at a time) and "×" badge deselect behavior in `lib/features/call_history/presentation/pages/select_contact_screen.dart`

**Checkpoint**: Select Contact screen fully functional with both empty and selected states matching screenshots 3 & 4.

---

## Phase 7: User Story 5 — Use Dialpad to Call a Number (Priority: P3)

**Goal**: Users tap "Call a number" on Select Contact and see a numeric keypad (4×3 grid of circular grey buttons: 1-9, *, 0, #) with a number display area above and a large green call button below.

**Independent Test**: From Select Contact, tap "Call a number" → verify Dialpad screen shows back arrow, 12 circular grey buttons in 4×3 grid, and a green call button at the bottom. Tap digit buttons → verify digits appear in the display area.

### Implementation for User Story 5

- [x] T013 [US5] Build `DialpadScreen` as a `StatefulWidget` with a large numeric display (including backspace icon) and a 3x4 grid of rounded buttons (0-9, *, #) with primary/secondary labels (e.g., "1", "o_o"; "2", "ABC") in `lib/features/call_history/presentation/pages/dialpad_screen.dart`
- [x] T014 [US5] Wire "Call a number" row in `SelectContactScreen` to navigate to `AppRouterName.dialpad` in `lib/features/call_history/presentation/pages/select_contact_screen.dart`

**Checkpoint**: Dialpad screen renders with full keypad. Navigation from Select Contact → Dialpad works.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final visual alignment, navigation verification, and cleanup

- [x] T015 [P] Verify all 5 screens match reference screenshots in layout, spacing, colors, and typography
- [x] T016 [P] Verify end-to-end navigation flows: Calls tab → History → Call Info, History → Select Contact → Dialpad
- [x] T017 [P] Verify locale switching (EN ↔ AR) correctly swaps all new strings across all 5 screens
- [x] T018 Run `flutter analyze` to ensure no lint warnings or errors in new/modified files

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (translations, mock data)
- **User Stories (Phases 3–7)**: All depend on Phase 2 (shared widgets, routes)
  - US1 + US2 can proceed in parallel after Phase 2
  - US3 + US4 are sequential (US4 extends US3's screen)
  - US5 depends on US3 (needs "Call a number" row in Select Contact)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — modifies existing `calls_history_screen.dart`
- **User Story 2 (P1)**: After Phase 2 — new `call_information_screen.dart` (independent of US1)
- **User Story 3 (P2)**: After Phase 2 — new `select_contact_screen.dart` (independent of US1/US2)
- **User Story 4 (P2)**: After US3 — extends `select_contact_screen.dart` with selection state
- **User Story 5 (P3)**: After US3 — new `dialpad_screen.dart` + wires navigation from Select Contact

### Parallel Opportunities

- T001 + T002 + T003 (all Setup) can run in parallel
- T004 + T005 (Foundational widgets) can run in parallel
- US1 (T007–T008) + US2 (T009) can run in parallel after Phase 2
- US3 (T010) can run in parallel with US1/US2
- T015 + T016 + T017 (Polish) can run in parallel

---

## Parallel Example: After Phase 2

```text
# Launch US1 and US2 together (different files):
Task T007: Update calls_history_screen.dart navigation (US1)
Task T009: Build call_information_screen.dart (US2)

# Launch US3 independently:
Task T010: Build select_contact_screen.dart (US3)
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (translations + mock data)
2. Complete Phase 2: Foundational (shared widgets + routes)
3. Complete Phase 3: US1 — Calls History navigation updates
4. Complete Phase 4: US2 — Call Information screen
5. **STOP and VALIDATE**: Navigate Calls tab → tap row → verify Call Info screen
6. Demo the core history + detail flow

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 + US2 → Test history→detail flow → Demo (MVP!)
3. Add US3 → Test Select Contact empty state → Demo
4. Add US4 → Test Select Contact selection → Demo
5. Add US5 → Test Dialpad → Demo
6. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No test tasks generated — not requested in feature spec
- All screens use hardcoded mock data (FR-014) — no backend integration
- All text uses `easy_localization` keys (FR-013) — no hardcoded strings
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
