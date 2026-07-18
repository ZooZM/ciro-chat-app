# Tasks: Digital Wallet UI (025)

**Input**: Design documents from `/specs/025-digital-wallet-ui/`
**Prerequisites**: plan.md, spec.md, data-model.md, wallet_ui_contracts.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Tests are NOT included as they were not explicitly requested in the specification.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [P] Create feature directory structure in `lib/features/payment/presentation/entities/`
- [x] T002 [P] Create mock data directory `lib/features/payment/presentation/wallet_mock_data.dart`
- [x] T003 Setup feature-specific routes in `lib/core/routing/app_router.dart`
- [x] T004 Add wallet colors to `lib/core/theme/app_colors.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T005 [P] Implement `WalletUserStatus`, `WalletTransactionDirection`, `PaymentMethodType`, `PaymentResultStatus` enums in `lib/features/payment/presentation/entities/wallet_entities.dart`
- [x] T006 Implement `WalletUser`, `WalletBalance`, `WalletTransaction`, `WalletContact`, `PaymentMethod`, `PaymentResult` classes in `lib/features/payment/presentation/entities/wallet_entities.dart`
- [x] T007 Implement mock data source in `lib/features/payment/presentation/wallet_mock_data.dart`
- [x] T008 [P] Add English translation keys (`wallet.*`) to `assets/translations/en.json`
- [x] T009 [P] Add Arabic translation keys (`wallet.*`) to `assets/translations/ar.json`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View Wallet Balance & Quick Actions (Priority: P1) 🎯 MVP

**Goal**: Navigate to `/wallet`; view balance card, toggle balance visibility, access one-tap actions (Add Money, Send, Receive, QR Code) and recent transactions.

**Independent Test**: Navigate to `/wallet`; verify the balance card renders, the eye icon toggles balance masking, all 4 quick action buttons are tappable, and the transaction list shows mock data.

### Implementation for User Story 1

- [x] T010 [P] [US1] Create UI widget `WalletBalanceCard` in `lib/features/payment/presentation/widgets/wallet_balance_card.dart`
- [x] T011 [P] [US1] Create UI widget `WalletQuickActionButton` in `lib/features/payment/presentation/widgets/wallet_quick_action_button.dart`
- [x] T012 [P] [US1] Create UI widget `WalletTransactionTile` in `lib/features/payment/presentation/widgets/wallet_transaction_tile.dart`
- [x] T013 [US1] Build UI page `WalletHomeScreen` in `lib/features/payment/presentation/pages/wallet_home_screen.dart`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - View Wallet Profile (Priority: P1)

**Goal**: Review wallet identity details, share barcode, and access wallet settings.

**Independent Test**: Navigate to `/wallet/profile`; verify all info card rows render, copy icons respond to tap, barcode action cards are tappable, and settings rows exist.

### Implementation for User Story 2

- [x] T014 [P] [US2] Create UI widget `WalletProfileInfoCard` in `lib/features/payment/presentation/widgets/wallet_profile_info_card.dart`
- [x] T015 [P] [US2] Create UI widget `WalletBarcodeActionCard` in `lib/features/payment/presentation/widgets/wallet_barcode_action_card.dart`
- [x] T016 [P] [US2] Create UI widget `WalletSettingsTile` in `lib/features/payment/presentation/widgets/wallet_settings_tile.dart`
- [x] T017 [US2] Build UI page `WalletProfileScreen` in `lib/features/payment/presentation/pages/wallet_profile_screen.dart`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Send Money (Priority: P1)

**Goal**: Search for contacts, pick a contact, and proceed to enter amount.

**Independent Test**: Navigate to `/wallet/send`; type in the search bar and verify the list filters; tap a contact and verify navigation placeholder.

### Implementation for User Story 3

- [x] T018 [P] [US3] Create UI widget `WalletContactTile` in `lib/features/payment/presentation/widgets/wallet_contact_tile.dart`
- [x] T019 [P] [US3] Create UI widget `WalletSendTransactionTile` in `lib/features/payment/presentation/widgets/wallet_send_transaction_tile.dart`
- [x] T020 [US3] Build UI page `WalletSendScreen` in `lib/features/payment/presentation/pages/wallet_send_screen.dart`

**Checkpoint**: All P1 user stories should now be functional

---

## Phase 6: User Story 6 - Payment Status: Success or Failed (Priority: P1)

**Goal**: Show a reusable screen after a payment completes with Success or Failed state.

**Independent Test**: Render the screen in both Success and Failed states; verify icon color, title text, subtitle text, reference ID card, and Done button.

### Implementation for User Story 6

- [x] T021 [P] [US6] Create UI widget `WalletPaymentStatusIcon` in `lib/features/payment/presentation/widgets/wallet_payment_status_icon.dart`
- [x] T022 [P] [US6] Create UI widget `WalletReferenceIdCard` in `lib/features/payment/presentation/widgets/wallet_reference_id_card.dart`
- [x] T023 [US6] Build UI page `WalletPaymentStatusScreen` in `lib/features/payment/presentation/pages/wallet_payment_status_screen.dart`

**Checkpoint**: Payment Status flows are now functional

---

## Phase 7: User Story 4 - Receive Money via QR Code (Priority: P2)

**Goal**: Show QR code containing Ciro ID with action buttons and security banner.

**Independent Test**: Navigate to `/wallet/receive`; verify QR code, user info, action buttons, security note, and auto-refresh banner all render correctly.

### Implementation for User Story 4

- [x] T024 [P] [US4] Create UI widget `WalletQrCard` in `lib/features/payment/presentation/widgets/wallet_qr_card.dart`
- [x] T025 [US4] Build UI page `WalletReceiveScreen` in `lib/features/payment/presentation/pages/wallet_receive_screen.dart`

**Checkpoint**: Receive Money flows are now functional

---

## Phase 8: User Story 5 - Add Amount via Custom Numpad (Priority: P2)

**Goal**: Enter amount via custom 12-key dialpad without native keyboard.

**Independent Test**: Navigate to `/wallet/add-amount`; tap numpad digits and verify the amount display updates; tap backspace to delete.

### Implementation for User Story 5

- [x] T026 [P] [US5] Create UI widget `WalletNumpad` in `lib/features/payment/presentation/widgets/wallet_numpad.dart`
- [x] T027 [US5] Build UI page `WalletAddAmountScreen` in `lib/features/payment/presentation/pages/wallet_add_amount_screen.dart`

**Checkpoint**: All user stories should now be independently functional

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T028 [P] Code cleanup and review against Ciro Chat App Constitution
- [x] T029 Run quickstart.md validation if applicable

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

- **User Story 1 (P1)**: Can start after Foundational (Phase 2)
- **User Story 2 (P1)**: Can start after Foundational (Phase 2)
- **User Story 3 (P1)**: Can start after Foundational (Phase 2)
- **User Story 6 (P1)**: Can start after Foundational (Phase 2)
- **User Story 4 (P2)**: Can start after Foundational (Phase 2)
- **User Story 5 (P2)**: Can start after Foundational (Phase 2)

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- Different user stories can be worked on in parallel by different team members

## Implementation Strategy

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Add User Story 6 → Test independently → Deploy/Demo
6. Add User Story 4 → Test independently → Deploy/Demo
7. Add User Story 5 → Test independently → Deploy/Demo
