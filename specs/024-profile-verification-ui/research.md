# Research: Profile Verification UI (024)

**Phase**: 0 — Outline & Research  
**Date**: 2026-07-12  
**Feature**: [spec.md](file:///c:/Users/user/Desktop/ciro-app/ciro-chat-app/specs/024-profile-verification-ui/spec.md)

---

## 1. Existing Codebase Analysis

### Decision: Extend the `profile` feature — do NOT create a new feature module

- **Rationale**: The project already contains `lib/features/profile/presentation/pages/identity_verification_stepper_screen.dart`, `bank_account_screen.dart`, `identity_verification_screen.dart`, and `identity_verification_success_screen.dart`. The new flow is an enhancement and expansion of this existing work, not a greenfield feature.
- **Alternatives considered**: Creating a separate `profile_verification` feature — rejected because it would duplicate routing, translation keys, and widget conventions that already live inside `profile`.

### Decision: No domain or data layer additions needed

- **Rationale**: The spec explicitly requires **UI and mock data only**. No backend calls, no persistence, no Cubit/Bloc state management. All screens will use `StatefulWidget` with local `setState` for UI-only toggle states (e.g. dropdown open/close).
- **Alternatives considered**: Creating a `ProfileVerificationCubit` — rejected per spec constraints ("No real backend forms, state management like Riverpod/Bloc").

---

## 2. Custom Stepper Widget Research

### Decision: Create a reusable `ProfileVerificationStepper` widget in `presentation/widgets/`

- **Rationale**: The new 4-step flow (Invoice Info → Identify → Bank Account → Review) needs a different stepper from the existing 3-step identity stepper (`identity_verification_stepper_screen.dart`). Sharing a parameterized widget avoids duplication.
- **Implementation**: The widget accepts `currentStep` (int), `totalSteps` (int), and a `List<String>` of step labels. Each node renders: Inactive (grey outline + grey number), Active (solid green circle + white number), Completed (solid green circle + white checkmark icon).
- **Alternatives considered**: Reusing the existing 3-step stepper directly — rejected because it is hard-coded for 3 steps and cannot display 4.

---

## 3. Localization Key Strategy

### Decision: Add new keys under the `profile_verification_*` namespace

- **Rationale**: Existing keys are already organized by feature prefix (`profile_*`, `bank_*`, `step_*`). The new flow maps directly to the existing `bank_*` keys for Step 3, and new `profile_verification_*` keys for the Welcome screen and Step 1.
- **Existing keys that can be REUSED** (no new keys needed):
  - `bank_full_name`, `bank_iban`, `bank_select`, `bank_choose`, `bank_save` → Step 3
  - `national_id_number`, `front_id_upload`, `back_id_upload`, `make_sure_image_clear`, `take_clear_selfie`, `step_id_number`, `step_upload_id`, `step_selfie` → Step 2
  - `next`, `save` → buttons
- **New keys required** for the Welcome screen, Step 1, and Step 4 (Review):
  - `profile_verification_welcome_title`, `profile_verification_welcome_subtitle`, `profile_verification_get_started`, `profile_verification_skip`
  - `profile_verification_step_invoice`, `profile_verification_step_identify`, `profile_verification_step_bank`, `profile_verification_step_review`
  - `profile_verification_invoice_title`, `profile_verification_company_logo`, `profile_verification_business_name`, `profile_verification_cr_number`, `profile_verification_tax_number`, `profile_verification_tax_optional`, `profile_verification_address`
  - `profile_verification_id_upload_title`, `profile_verification_selfie_title`
  - `profile_verification_bank_title`
  - `profile_verification_review_title`, `profile_verification_review_subtitle`, `profile_verification_business_info`, `profile_verification_identity_card`, `profile_verification_bank_info`, `profile_verification_edit`, `profile_verification_verified`, `profile_verification_matched`, `profile_verification_id_number`, `profile_verification_status`, `profile_verification_face_match`, `profile_verification_activate`, `profile_verification_warning`, `profile_verification_bank_name_label`, `profile_verification_account_holder`, `profile_verification_iban_label`
  - `profile_verification_continue`

---

## 4. Styling & Brand Color

### Decision: Use `AppColors.primary` (`Color(0xFF4CA02A)`) and the existing `Color(0xFF4CA440)` convention

- **Rationale**: `lib/core/theme/app_colors.dart` declares `AppColors.primary = Color(0xFF4CA02A)`. The existing stepper screen uses `Color(0xFF4CA440)` inline. To stay consistent with AppColors (single source of truth per Constitution VIII-B), the new widgets will use `AppColors.primary` for green elements and the `AppColors.primaryLight` for subtle backgrounds.
- **Form field border radius**: `BorderRadius.circular(16)` — consistent with all existing profile screens.
- **Bottom button style**: Full-width `ElevatedButton` with `minimumSize: Size(double.infinity, 54)`, `borderRadius: BorderRadius.circular(16)`.

---

## 5. Routing Strategy

### Decision: Add new named routes under `/profile/verification/`

- **Rationale**: The existing `AppRouterName` class in `lib/core/routing/app_router.dart` uses a clear path-based convention. The new flow will be registered as:
  - `/profile/verification` → `ProfileVerificationWelcomeScreen`
  - `/profile/verification/step` → `ProfileVerificationFlowScreen` (hosts the 4-step flow)
- **Alternatives considered**: Embedding the welcome screen inside the flow as step 0 — rejected because the spec treats it as a distinct screen with different layout (no stepper header).

---

## 6. File & Widget Structure

### Decision: New files under `lib/features/profile/presentation/`

New files to create:
- `pages/profile_verification_welcome_screen.dart` — Welcome screen
- `pages/profile_verification_flow_screen.dart` — Hosts the 4-step flow with the stepper
- `widgets/profile_verification_stepper.dart` — Reusable 4-step stepper widget
- `widgets/profile_verification_step_invoice.dart` — Step 1 content
- `widgets/profile_verification_step_identity.dart` — Step 2 content (3 internal sub-states)
- `widgets/profile_verification_step_bank.dart` — Step 3 content
- `widgets/profile_verification_step_review.dart` — Step 4 content

---

## 7. Bank Dropdown Implementation

### Decision: Build a custom inline dropdown using `AnimatedCrossFade` or `Column` expansion — no plugin required

- **Rationale**: The spec requires a custom dropdown with green border style when focused and an open state showing Saudi banks. The existing `bank_account_screen.dart` already has the complete bank list as a `List<String>`. We will replicate this approach using a `GestureDetector`-driven expandable `Container` with a `ListView` of options, rendered inline below the selector row.
- **Alternatives considered**: `DropdownButtonFormField` — rejected because it does not match the custom visual style (green border, custom list styling) shown in the screenshots.

---

## Summary of Resolved Unknowns

| Unknown | Resolution |
|---------|------------|
| Where to add new files? | Extend `lib/features/profile/presentation/` |
| New Cubit needed? | No — pure `StatefulWidget` with `setState` per spec |
| New translations? | ~25 new keys under `profile_verification_*` namespace |
| Brand green color? | `AppColors.primary` (`0xFF4CA02A`) |
| Bank list source? | Hardcoded in widget, matching `bank_account_screen.dart` list |
| Custom stepper reuse? | New parameterized `ProfileVerificationStepper` widget |
| Routing? | Two new routes in `app_router.dart` |
