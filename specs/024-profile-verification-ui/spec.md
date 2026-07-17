# Feature Specification: Profile Verification UI

**Feature Branch**: `[024-profile-verification-ui]`  
**Created**: 2026-07-12  
**Status**: Draft  
**Input**: User description: "Act as a Senior Flutter Developer. I have attached screenshots showing a complete multi-step 'Profile Verification / Sign Up' flow. Please analyze these images and UPDATE our UI specifications to include this entire flow..."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Welcome Screen & Navigation (Priority: P1)

Users see a welcome screen immediately after the OTP verification screen during sign-up, before starting the profile verification, and can navigate through the multi-step form using a shared custom stepper widget.

**Why this priority**: Essential entry point and navigation framework for the entire flow.

**Independent Test**: Can be fully tested by verifying the welcome screen displays correctly after sign-up, the stepper shows all 4 steps, and clicking "Get Started" moves to the first step.

**Acceptance Scenarios**:

1. **Given** the user is on the Welcome Screen, **When** they view the screen, **Then** they see a large document/invoice icon with a checkmark, "Complete Your Profile" title, and a subtitle.
2. **Given** the user is on the Welcome Screen, **When** they tap "Get Started", **Then** they are navigated to Step 1 of the verification flow.
3. **Given** the user is on the Welcome Screen, **When** they tap "Skip for now", **Then** the verification flow is skipped.
4. **Given** the user is anywhere in the flow (Steps 1-4), **When** they view the header, **Then** they see the Custom Stepper Widget showing 4 steps ("Invoice Info", "Identify", "Bank Account", "Review") with correct states (Inactive, Active, Completed).

---

### User Story 2 - Invoice Information (Step 1) (Priority: P1)

Users can input their business details on the first step of the verification process.

**Why this priority**: Core data gathering step required for the verification process.

**Independent Test**: Can be tested by navigating to Step 1 and verifying the UI layout, input fields, and styling.

**Acceptance Scenarios**:

1. **Given** the user is on Step 1, **When** they view the page, **Then** they see a circular "Company Logo" upload placeholder.
2. **Given** the user is on Step 1, **When** they view the form, **Then** they see text fields for Business Name, Commercial Registration Number, Tax Number (Optional), and Business Address, all styled with rounded corners and green active borders.
3. **Given** the user has filled the mock form, **When** they tap the "Continue" button, **Then** they proceed to Step 2.

---

### User Story 3 - Identity Verification (Step 2) (Priority: P1)

Users can mock-verify their identity through multiple UI states (National ID, Document Upload, Selfie).

**Why this priority**: Key step for regulatory compliance in the mock flow.

**Independent Test**: Can be tested by viewing the various mock states of Step 2 independently.

**Acceptance Scenarios**:

1. **Given** the user is on Step 2 (State A), **When** they view the page, **Then** they see a "National ID Number" text field and a "Next" button.
2. **Given** the user is on Step 2 (State B), **When** they view the page, **Then** they see an "Upload Your ID" section with two outlined buttons for "Front ID" and "Back ID".
3. **Given** the user is on Step 2 (State C), **When** they view the page, **Then** they see a "Take a Selfie" section with a large circular camera placeholder and a "Save" button.

---

### User Story 4 - Bank Account Verification (Step 3) (Priority: P2)

Users can provide bank details with inline validation UI states.

**Why this priority**: Necessary for payout setup in the mock flow.

**Independent Test**: Can be tested by viewing the Step 3 UI and interacting with the dropdown.

**Acceptance Scenarios**:

1. **Given** the user is on Step 3, **When** they view the form, **Then** they see text fields for "Full Name" and "IBAN".
2. **Given** the user views the IBAN field, **When** they enter a value, **Then** a mock green checkmark icon is displayed inside the field to simulate successful validation.
3. **Given** the user views the bank selection, **When** they interact with it, **Then** a custom dropdown appears matching the green border style, showing a list of mock Saudi banks.

---

### User Story 5 - Review Information (Step 4) (Priority: P2)

Users can review all entered information on a summary screen before activation.

**Why this priority**: Final confirmation step before mock submission.

**Independent Test**: Can be tested by viewing Step 4 and verifying the summary cards.

**Acceptance Scenarios**:

1. **Given** the user is on Step 4, **When** they view the page, **Then** they see three summary cards: "Business Information", "Identity Verification", and "Business Information" (Bank info).
2. **Given** the user views a summary card, **When** they inspect it, **Then** it has a title, an "Edit" pencil icon, and mock data.
3. **Given** the user views the Identity card, **When** they inspect it, **Then** they see a mock ID image and green "Verified" / "Matched" badges.
4. **Given** the user views the bottom of Step 4, **When** they inspect it, **Then** they see a warning banner and a large "Activate Account" button.

### Edge Cases

- How does the UI handle long translations in the Custom Stepper titles? (Should wrap or scale down).
- What happens when the user opens the keyboard? (The screen should scroll and the bottom button might float or stay at the bottom of the scroll view).
- How is the custom dropdown displayed when there is not enough screen height below the field? (Should scroll or appear above).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a multi-step Profile Verification UI according to the provided screenshots.
- **FR-002**: System MUST implement a reusable top Custom Stepper Widget showing 4 steps ("Invoice Info", "Identify", "Bank Account", "Review") supporting Inactive, Active, and Completed states.
- **FR-003**: System MUST provide a Welcome Screen with "Get Started" and "Skip for now" actions.
- **FR-004**: System MUST implement Step 1 (Invoice Info) with a logo placeholder and 4 styled text fields.
- **FR-005**: System MUST implement Step 2 (Identity Verification) supporting 3 visual states (National ID input, ID Upload buttons, Selfie placeholder).
- **FR-006**: System MUST implement Step 3 (Bank Account) featuring a custom dropdown and an IBAN field with a mock success validation icon.
- **FR-007**: System MUST implement Step 4 (Review) with 3 summary cards displaying mock data, "Edit" icons, and status badges.
- **FR-008**: System MUST implement all forms using UI layout widgets and mock states ONLY (No real backend forms, state management like Riverpod/Bloc, or actual camera/file picker logic).
- **FR-009**: System MUST use `easy_localization` keys for all text (No hardcoded strings).
- **FR-010**: System MUST maintain the exact form field styling (rounded corners, green active borders, specific brand green color).

### Key Entities

- **MockProfileData**: Represents the mock data displayed in the Review step (Business Name, CR Number, Tax Number, Address, ID Number, Bank Name, Account Name, IBAN).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of all displayed text strings are localized using `easy_localization`.
- **SC-002**: UI components visually match the provided screenshots (colors, border radii, iconography) on standard mobile device sizes.
- **SC-003**: No complex state management (Riverpod/Bloc) is introduced for this purely UI-focused task.
- **SC-004**: The custom stepper correctly renders all 3 possible states (Inactive, Active, Completed) depending on the mock step index.

## Assumptions

- No actual user data needs to be captured or persisted; this is strictly a UI implementation with mock data.
- The brand green color code is already defined in the project's theme or will be extracted from the screenshots.
- "easy_localization" is already configured in the Flutter project.
- No real camera or file picker plugins need to be added to `pubspec.yaml`.
