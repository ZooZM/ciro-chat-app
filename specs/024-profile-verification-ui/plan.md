# Implementation Plan: Profile Verification UI (024)

**Branch**: `024-profile-verification-ui` | **Date**: 2026-07-12 | **Spec**: specs/024-profile-verification-ui/spec.md
**Input**: Feature specification from `specs/024-profile-verification-ui/spec.md`

---

## Summary

Build a complete, multi-step **Profile Verification / Sign-Up flow** UI within the existing `profile` feature. The flow consists of a Welcome screen plus 4 steps: Invoice Information, Verify Your Identity (3 sub-states), Bank Account Verification, and Review Your Information. All screens are **UI and mock data only** — no Cubit/Bloc, no real camera/file picker, no backend calls. All text uses `easy_localization` keys. Styling matches the brand green (`AppColors.primary`) with rounded-corner form fields.

---

## Technical Context

**Language/Version**: Dart / Flutter (existing project)
**Primary Dependencies**: `easy_localization ^3.0.8`, `go_router ^17.2.0`
**Storage**: N/A (mock data only, no persistence)
**Testing**: Manual widget inspection
**Target Platform**: iOS and Android mobile
**Project Type**: Mobile app (Flutter)
**Performance Goals**: 60 fps UI, instant local state transitions
**Constraints**: No new `pubspec.yaml` dependencies; pure UI, no state management packages
**Scale/Scope**: 2 new screens, 5 new widgets, ~35 new translation keys

---

## Constitution Check

- [x] **I. Clean Architecture**: UI-only. All files in `presentation/pages/` and `presentation/widgets/`. No domain or data layer additions.
- [x] **II. State Management**: No Cubit/Bloc — spec explicitly forbids it. `StatefulWidget` + `setState` for local UI state.
- [x] **III. Offline-First**: N/A — no data persistence.
- [x] **IV. Socket.io**: N/A — no real-time communication.
- [x] **V. Teardown**: All `TextEditingController` instances disposed in `dispose()`. No stream subscriptions.
- [x] **Code Quality**: `snake_case` files, `PascalCase` classes, `const` constructors, `AppColors` tokens used.
- [x] **Error Handling**: N/A — no network calls.

---

## Project Structure

### New Files

```
lib/features/auth/presentation/
    pages/
        profile_verification_welcome_screen.dart   [NEW]
        profile_verification_flow_screen.dart      [NEW]
    widgets/
        profile_verification_stepper.dart          [NEW]
        profile_verification_step_invoice.dart     [NEW]
        profile_verification_step_identity.dart    [NEW]
        profile_verification_step_bank.dart        [NEW]
        profile_verification_step_review.dart      [NEW]
```

### Modified Files

```
lib/core/routing/app_router.dart     [MODIFY]
assets/translations/en.json         [MODIFY]
assets/translations/ar.json         [MODIFY]
```

---

## Phase 1: Detailed Component Design

### Widget 1: ProfileVerificationStepper

File: `lib/features/auth/presentation/widgets/profile_verification_stepper.dart`

Reusable, stateless widget.

Parameters:
- currentStep: int (0-3)
- stepLabels: List<String> (4 labels from localization)

Node rendering:
- stepIndex < currentStep  = Completed: green filled circle + white checkmark icon
- stepIndex == currentStep = Active: green filled circle + white number + green label
- stepIndex > currentStep  = Inactive: grey filled circle + grey number + grey label

Connectors: `Expanded Container(height: 2)` — green if completed, grey otherwise.

---

### Screen 1: ProfileVerificationWelcomeScreen

File: `lib/features/auth/presentation/pages/profile_verification_welcome_screen.dart`

- StatelessWidget, no stepper header
- Large icon (stacked Icons.receipt_long + Icons.check_circle badge), size ~180x180
- Title: `'profile_verification_welcome_title'.tr()` — Bold 28sp
- Subtitle: `'profile_verification_welcome_subtitle'.tr()` — 15sp grey centered
- Bottom: ElevatedButton ("Get Started") + TextButton with underline ("Skip for now")

---

### Screen 2: ProfileVerificationFlowScreen

File: `lib/features/auth/presentation/pages/profile_verification_flow_screen.dart`

- StatefulWidget with _currentStep (int, 0-3) and _identitySubStep
- Header: ProfileVerificationStepper(currentStep: _currentStep, stepLabels: [...])
- Body SingleChildScrollView switches on _currentStep:
  - 0 = ProfileVerificationStepInvoice
  - 1 = ProfileVerificationStepIdentity(subStep: _identitySubStep)
  - 2 = ProfileVerificationStepBank
  - 3 = ProfileVerificationStepReview
- CTA button labels per step:
  - Step 0: "Continue"
  - Step 1 sub-states 0/1: "Next"; sub-state 2: "Save"
  - Step 2: "Save" (bank_save key)
  - Step 3: "Activate Account" (inside review widget)
- Back navigation: AppBar back/forward arrow (RTL-aware), decrements step.

---

### Widget 2: ProfileVerificationStepInvoice (Step 1)

File: `lib/features/auth/presentation/widgets/profile_verification_step_invoice.dart`

- StatelessWidget
- Title: "Invoice Information" (22sp bold)
- Circular logo placeholder: Container(w:120, h:120), grey border, Icons.upload + "Company Logo"
- 4 text fields (all with AppColors.primary border, borderRadius: 16):
  - Business Name
  - Commercial Registration Number
  - Tax Number (label + "(Optional)" suffix in lighter weight)
  - Business Address

---

### Widget 3: ProfileVerificationStepIdentity (Step 2)

File: `lib/features/auth/presentation/widgets/profile_verification_step_identity.dart`

- StatefulWidget, manages _subStep (0, 1, 2)
- Sub-state 0 (nationalId): label + styled TextField
- Sub-state 1 (uploadId): "Upload Your ID" title + 2 upload boxes + hint text
- Sub-state 2 (selfie): "Take a Selfie" title + circular camera placeholder (220px) + hint text
- Upload box: Container with green border, label on left, Icons.file_upload_outlined on right

---

### Widget 4: ProfileVerificationStepBank (Step 3)

File: `lib/features/auth/presentation/widgets/profile_verification_step_bank.dart`

- StatefulWidget
- State: _isDropdownOpen (bool), _selectedBank (String?), _isIbanValid (bool, default true)
- Title: "Bank Account Verification" (22sp bold)
- Full Name TextField
- IBAN TextField + suffix Icon(Icons.check_circle) when _isIbanValid
- Bank dropdown: GestureDetector trigger + AnimatedContainer with bank list
- Bank list: SNB, Al Rajhi, Riyad, SAB, Saudi Fransi, ANB, Alinma, Bank Albilad, Bank AlJazira, SAIB, GIB, stc Bank

---

### Widget 5: ProfileVerificationStepReview (Step 4)

File: `lib/features/auth/presentation/widgets/profile_verification_step_review.dart`

- StatelessWidget
- Title: "Review Your Information" (22sp bold)
- Subtitle: grey 14sp
- Card 1 — Business Information: logo placeholder + business name, CR number, tax number, address
- Card 2 — Identity Verification: mock ID image container + ID number + "Verified" badge + "Matched" badge
- Card 3 — Business Information (Bank): bank name, account holder, masked IBAN
- Green status badge: Container(green background, borderRadius 20) with icon + text
- Warning banner: amber background Container + info icon + warning text
- Activate button: full-width green ElevatedButton

---

### Routing

File: `lib/core/routing/app_router.dart`

New route names:
- profileVerificationWelcome = '/profile/verification'
- profileVerificationFlow = '/profile/verification/flow'

Update the GoRouter redirect logic in `app_router.dart`:
- When `authState is Authenticated` and `isAuthRoute` is true, redirect to `AppRouterName.profileVerificationWelcome` instead of `AppRouterName.home`.
- The "Skip for now" button on the Welcome screen will then use `context.go(AppRouterName.home)` to complete the login process.

---

## Verification Plan

### Manual Verification Steps

1. Navigate to `/profile/verification` — Welcome screen renders correctly.
2. Tap "Get Started" — navigates to flow screen with stepper visible.
3. Step 1: Logo placeholder, 4 styled fields, "Continue" button present.
4. Step 2 sub-state A: National ID field + "Next" button.
5. Step 2 sub-state B: Two upload boxes + hint.
6. Step 2 sub-state C: Camera circle + "Save" button.
7. Step 3: IBAN shows green checkmark, dropdown expands with bank list.
8. Step 4: 3 summary cards with mock data, green badges, warning banner, "Activate Account" button.
9. RTL: back arrow flips to forward in Arabic locale.
10. No widget exceptions on forward/back navigation.
