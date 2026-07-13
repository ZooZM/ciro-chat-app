# Data Model: Profile Verification UI (024)

**Phase**: 1 — Design  
**Date**: 2026-07-12  
**Feature**: [spec.md](file:///c:/Users/user/Desktop/ciro-app/ciro-chat-app/specs/024-profile-verification-ui/spec.md)

> **Note**: This feature is UI-only with mock data. No persistence layer, no domain entities, no backend calls. The entities below represent **in-memory mock data structures** used to render the Review screen.

---

## Mock Data Entities

### `MockBusinessInfo`

Represents the business details entered in Step 1 (Invoice Information). Used as static mock data on the Review screen.

| Field | Type | Mock Value |
|-------|------|------------|
| `logoAsset` | `String?` | `null` (placeholder shown) |
| `businessName` | `String` | `"Al Noor Trading Company"` |
| `crNumber` | `String` | `"1010234567"` |
| `taxNumber` | `String` | `"300123456700003"` |
| `address` | `String` | `"Riyadh, Al Olaya, Kingdom of Saudi Arabia"` |

---

### `MockIdentityInfo`

Represents the identity data from Step 2 (Verify Your Identity). Used as static mock data on the Review screen.

| Field | Type | Mock Value |
|-------|------|------------|
| `idNumber` | `String` | `"1234567890"` |
| `idImageAsset` | `String` | Asset path or placeholder |
| `isVerified` | `bool` | `true` |
| `isFaceMatched` | `bool` | `true` |

---

### `MockBankInfo`

Represents the bank details from Step 3 (Bank Account Verification). Used as static mock data on the Review screen.

| Field | Type | Mock Value |
|-------|------|------------|
| `bankName` | `String` | `"Al Rajhi Bank"` |
| `accountHolder` | `String` | `"Al Noor Trading Company"` |
| `iban` | `String` | `"SA12 **** **** **** 1234"` (masked) |

---

## UI State Models

### `ProfileVerificationStep` (enum)

Controls the top-level step in the 4-step flow.

```
welcome → invoiceInfo → identity → bankAccount → review
```

| Value | Screen |
|-------|--------|
| `invoiceInfo` | Step 1 — Invoice Information |
| `identity` | Step 2 — Verify Your Identity |
| `bankAccount` | Step 3 — Bank Account Verification |
| `review` | Step 4 — Review Your Information |

---

### `IdentitySubStep` (enum)

Controls the sub-state within Step 2.

| Value | UI State |
|-------|----------|
| `nationalId` | State A — National ID Number input field |
| `uploadId` | State B — Front/Back ID upload buttons |
| `selfie` | State C — Camera placeholder circle |

---

## Widget Hierarchy

```
ProfileVerificationWelcomeScreen (StatelessWidget)
  └── "Get Started" → navigates to ProfileVerificationFlowScreen

ProfileVerificationFlowScreen (StatefulWidget)
  ├── ProfileVerificationStepper (widget, driven by currentStep int 0–3)
  └── Body (switches on currentStep)
      ├── Step 0 → ProfileVerificationStepInvoice (StatelessWidget)
      ├── Step 1 → ProfileVerificationStepIdentity (StatefulWidget)
      │           └── subStep: nationalId | uploadId | selfie
      ├── Step 2 → ProfileVerificationStepBank (StatefulWidget)
      │           └── isDropdownOpen: bool
      │           └── isIbanValid: bool (mock: true)
      └── Step 3 → ProfileVerificationStepReview (StatelessWidget)

ProfileVerificationStepper (StatelessWidget)
  Parameters: currentStep (int 0–3), stepLabels (List<String>)
  Node states:
    - stepIndex < currentStep  → Completed (green + checkmark)
    - stepIndex == currentStep → Active (green + number)
    - stepIndex > currentStep  → Inactive (grey outline + grey number)
```

---

## Translation Key Inventory

### New keys to add to `en.json` and `ar.json`

```json
{
  "profile_verification_welcome_title": "Complete Your Profile",
  "profile_verification_welcome_subtitle": "To start creating invoices, please complete your account verification.",
  "profile_verification_get_started": "Get Started",
  "profile_verification_skip": "Skip for now",
  "profile_verification_step_invoice": "Invoice Info",
  "profile_verification_step_identify": "Identify",
  "profile_verification_step_bank": "Bank Account",
  "profile_verification_step_review": "Review",
  "profile_verification_invoice_title": "Invoice Information",
  "profile_verification_company_logo": "Company Logo",
  "profile_verification_business_name": "Business Name",
  "profile_verification_cr_number": "Commercial Registration Number",
  "profile_verification_tax_number": "Tax Number",
  "profile_verification_tax_optional": "(Optional)",
  "profile_verification_address": "Business Address",
  "profile_verification_continue": "Continue",
  "profile_verification_id_upload_title": "Upload Your ID",
  "profile_verification_selfie_title": "Take a Selfie",
  "profile_verification_bank_title": "Bank Account Verification",
  "profile_verification_review_title": "Review Your Information",
  "profile_verification_review_subtitle": "Please review your information before confirming and activating your account",
  "profile_verification_business_info": "Business Information",
  "profile_verification_identity_card": "Identity Verification",
  "profile_verification_bank_info": "Business Information",
  "profile_verification_edit": "Edit",
  "profile_verification_verified": "Verified",
  "profile_verification_matched": "Matched",
  "profile_verification_id_number_label": "ID Number",
  "profile_verification_status_label": "Status",
  "profile_verification_face_match_label": "Face Match",
  "profile_verification_activate": "Activate Account",
  "profile_verification_warning": "Please make sure all information is correct before proceeding",
  "profile_verification_bank_name_label": "Bank Name",
  "profile_verification_account_holder_label": "Account Holder Name",
  "profile_verification_iban_label": "IBAN"
}
```

**Existing keys reused (no duplication)**:
- `national_id_number`, `front_id_upload`, `back_id_upload`, `make_sure_image_clear`, `take_clear_selfie`
- `bank_full_name`, `bank_iban`, `bank_select`, `bank_choose`, `bank_save`
- `next`, `save`
