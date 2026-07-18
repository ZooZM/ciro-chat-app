# Feature Specification: Digital Wallet UI

**Feature Branch**: `025-digital-wallet-ui`
**Created**: 2026-07-17
**Status**: Draft
**Input**: User description: "Digital Wallet feature — 7 screens: Main Wallet, Wallet Profile, Send Money, Receive Money, Add Amount (Numpad), Payment Success, Payment Failed. UI & mock data only, easy_localization keys, green brand color."

---

## Overview

The Digital Wallet feature gives Ciro users a dedicated in-app payments experience. Users can view their balance, send and receive money via QR code or contact search, top up using a custom numeric keypad, and review a success or failure confirmation after every transaction. All screens are display-only with mock data; no real payment gateway or database integration is included in this scope.

---

## Screen Inventory

| # | Screen Name | Route Key | Priority |
|---|-------------|-----------|----------|
| 1 | Main Wallet Screen | `/wallet` | P1 |
| 2 | Wallet Profile Screen | `/wallet/profile` | P1 |
| 3 | Send Money Screen | `/wallet/send` | P1 |
| 4 | Receive Money Screen | `/wallet/receive` | P2 |
| 5 | Add Amount (Numpad) Screen | `/wallet/add-amount` | P2 |
| 6 | Payment Status Screen (Success/Failed) | `/wallet/payment-status` | P1 |

---

## User Scenarios & Testing

### User Story 1 — View Wallet Balance & Quick Actions (Priority: P1)

A signed-in user opens the wallet section of the app. They immediately see their total balance on a gradient card, can toggle balance visibility with an eye icon, and have one-tap access to Add Money, Send, Receive, and QR Code actions. Below the actions a recent transaction list shows the last 4 transactions with direction (green positive, black negative) and timestamps.

**Why this priority**: The balance card is the entry point for every other wallet flow and must always be accessible.

**Independent Test**: Navigate to `/wallet`; verify the balance card renders, the eye icon toggles balance masking, all 4 quick action buttons are tappable, and the transaction list shows mock data.

**Acceptance Scenarios**:

1. **Given** the user is on the wallet home screen, **When** they tap the eye icon, **Then** the balance values are replaced with masked characters and the icon changes to a closed-eye variant.
2. **Given** the user is on the wallet home screen, **When** they tap "Add Money", **Then** they navigate to the Add Amount (Numpad) screen.
3. **Given** the user is on the wallet home screen, **When** they tap "Send", **Then** they navigate to the Send Money screen.
4. **Given** the user is on the wallet home screen, **When** they tap "Receive", **Then** they navigate to the Receive Money screen.
5. **Given** the user is on the wallet home screen, **When** they tap "QR Code", **Then** they navigate to the Receive Money screen.
6. **Given** mock transaction data is present, **When** the screen loads, **Then** a list of at least 4 transactions is displayed with avatar, name, date, and colored amount.
7. **Given** the screen loads, **When** the user taps "View All", **Then** a placeholder or extended transaction list is shown.
8. **Given** the screen loads, **When** the user taps the floating scanner FAB, **Then** a QR scanner sheet/screen is shown.

---

### User Story 2 — View Wallet Profile (Priority: P1)

A user wants to review their wallet identity details, share their barcode, and access wallet settings. They navigate to Wallet Profile and see their avatar with a green verified badge, Ciro ID (copyable), status, registration date, last-seen, country flag, and associated bank name (copyable).

**Why this priority**: Profile and identity information is critical for both sender and receiver verification.

**Independent Test**: Navigate to `/wallet/profile`; verify all info card rows render, copy icons respond to tap, barcode action cards are tappable, and all four settings rows navigate or show a placeholder.

**Acceptance Scenarios**:

1. **Given** the profile screen loads, **When** the user taps the copy icon next to Ciro ID, **Then** the ID value is copied to the clipboard and a confirmation message is shown.
2. **Given** the profile screen loads, **When** the user taps the copy icon next to Associated Bank, **Then** the bank name is copied to the clipboard.
3. **Given** the profile screen loads, **When** the user taps "Share Barcode", **Then** the native share sheet opens.
4. **Given** the profile screen loads, **When** the user taps "View Barcode", **Then** the Receive Money QR screen is shown.
5. **Given** the profile screen loads, **When** the user taps any settings row, **Then** a placeholder destination or toast is shown.
6. **Given** the profile screen loads, **When** the user taps the delete icon, **Then** a confirmation dialog is presented.
7. **Given** the profile screen loads, **When** the user taps the edit icon, **Then** a placeholder edit screen or bottom sheet is shown.

---

### User Story 3 — Send Money (Priority: P1)

A user wants to send money to a contact. They search by name, mobile, or Ciro ID, or tap one of three shortcut actions (Contact Ciro, Scan QR, Upload QR). They pick a contact from "Suggested People" or "Recent Transaction" lists, then proceed to enter an amount.

**Why this priority**: Send is the primary financial action and drives the core payment flow.

**Independent Test**: Navigate to `/wallet/send`; type in the search bar and verify the list filters; tap a contact and verify navigation to the Add Amount screen.

**Acceptance Scenarios**:

1. **Given** the Send Money screen loads, **When** the user types in the search bar, **Then** the Suggested People list filters in real-time.
2. **Given** the screen loads, **When** the user taps "Contact Ciro", **Then** a placeholder contacts screen or modal is shown.
3. **Given** the screen loads, **When** the user taps "Scan QR", **Then** the camera QR scanner view opens.
4. **Given** the screen loads, **When** the user taps "Upload QR", **Then** the device photo library opens or a mock action fires.
5. **Given** mock suggested contacts are present, **When** the user taps a contact row, **Then** they navigate to the Add Amount (Numpad) screen.
6. **Given** mock recent transactions are present, **When** the user taps a recent transaction row, **Then** they navigate to the Add Amount screen with recipient pre-filled.

---

### User Story 4 — Receive Money via QR Code (Priority: P2)

A user wants to receive money from someone else. They open the Receive Money screen and see a QR code containing their Ciro ID. They can share it, download it, or customize its appearance. A security note and an auto-refresh banner are always visible.

**Why this priority**: Receiving is secondary to sending but essential for a complete payments experience.

**Independent Test**: Navigate to `/wallet/receive`; verify QR code, user info, action buttons, security note, and auto-refresh banner all render correctly.

**Acceptance Scenarios**:

1. **Given** the Receive Money screen loads, **When** the QR code is displayed, **Then** the mock Ciro ID is embedded visually in the QR center area.
2. **Given** the screen loads, **When** the user taps the copy icon next to Ciro ID, **Then** the ID is copied to clipboard.
3. **Given** the screen loads, **When** the user taps "Share QR", **Then** the native share sheet opens with the QR image.
4. **Given** the screen loads, **When** the user taps "Download", **Then** a mock save action fires with a toast.
5. **Given** the screen loads, **When** the user taps "Customize", **Then** a placeholder customization sheet is shown.
6. **Given** the screen loads, **When** the bottom warning banner close button is tapped, **Then** the banner is dismissed.
7. **Given** the screen is open, **Then** a banner stating the QR refreshes every 60 seconds is always shown within the QR card.

---

### User Story 5 — Add Amount via Custom Numpad (Priority: P2)

A user wants to enter the amount they wish to add or send. The screen shows the Ciro Wallet logo, an "Add Amount" title, a large amount display, the minimum amount hint, the selected payment method with a "Change" link, and a custom 12-key dialpad. The native device keyboard must never appear.

**Why this priority**: Entering an amount is a mandatory step in the send and top-up flows.

**Independent Test**: Navigate to `/wallet/add-amount`; tap numpad digits and verify the amount display updates; tap backspace to delete; tap the green arrow and verify navigation to Payment Status.

**Acceptance Scenarios**:

1. **Given** the numpad screen loads, **When** the user taps digit buttons (1-9, 0), **Then** the amount display updates without invoking the native keyboard.
2. **Given** one or more digits have been entered, **When** the user taps the backspace key, **Then** the last digit is removed.
3. **Given** no digits are entered, **When** the user taps the backspace key, **Then** the display remains at "0".
4. **Given** a valid amount (>= 10 SAR) is entered, **When** the user taps the green next/arrow button, **Then** they navigate to the Payment Status screen.
5. **Given** the screen loads, **When** the user taps "Change" next to the payment method, **Then** a bottom sheet listing available payment methods is shown.
6. **Given** the screen loads, **Then** the currency label "SAR" is always displayed in green next to the amount.
7. **Given** the screen loads, **Then** the hint "Minimum add 10 SAR" is visible below the amount field.

---

### User Story 6 — Payment Status: Success or Failed (Priority: P1)

After a payment attempt completes, a single reusable screen is shown. If successful, a green checkmark icon with confetti and "Payment Successful" text is displayed. If failed, a red cross icon with confetti and "Payment Failed" text is shown. Both states show the Reference ID card and a green "Done" button.

**Why this priority**: Every payment flow must terminate with clear success/failure feedback; this screen is the final step of every transaction.

**Independent Test**: Render the screen in both Success and Failed states; verify icon color, title text, subtitle text, reference ID card, and Done button.

**Acceptance Scenarios**:

1. **Given** the screen is shown in Success state, **When** it renders, **Then** a green checkmark icon is displayed with decorative confetti.
2. **Given** the screen is shown in Success state, **When** it renders, **Then** the title reads "Payment Successful" and subtitle shows the amount and recipient.
3. **Given** the screen is shown in Failed state, **When** it renders, **Then** a red cross icon is displayed with decorative confetti.
4. **Given** the screen is shown in Failed state, **When** it renders, **Then** the title reads "Payment Failed" and subtitle shows the failure reason in red.
5. **Given** either state, **When** the screen renders, **Then** a Reference ID card (icon + label + ID value) is always visible.
6. **Given** either state, **When** the user taps the green "Done" button, **Then** they are returned to the Main Wallet Screen with all intermediate screens removed from the stack.

---

### Edge Cases

- What happens when the user enters an amount below the minimum (< 10 SAR) and taps Next? Display an inline validation message; do not navigate.
- What happens when the balance is hidden and the user navigates away and back? Balance remains hidden (persisted in ephemeral session state).
- What happens when the search bar on Send Money has no matching results? Show a "No contacts found" empty-state illustration.
- What happens if the QR code auto-refresh timer fires while the user is still on the Receive screen? The QR widget resets (visual shimmer/reload).
- What happens when the user taps Done after a failed payment? They are returned to the Main Wallet Screen.
- What happens when the Suggested People list is empty? Show a "No suggestions yet" empty-state message inside the card.

---

## Requirements

### Functional Requirements

#### Screen 1 — Main Wallet Screen

- **FR-001**: The screen MUST display a custom "ciro wallet" branded header with a notification bell icon and user avatar.
- **FR-002**: The screen MUST show a gradient balance card (green-to-blue) with Total Balance, a balance-visibility toggle (eye icon), and Current Balance.
- **FR-003**: The balance MUST be masked when the visibility toggle is in the hidden state.
- **FR-004**: The screen MUST present four quick-action buttons in a horizontal row: Add Money, Send, Receive, QR Code — each as a rounded-square card with a green icon.
- **FR-005**: The screen MUST display a "Recent Transaction" section header with a "View All" link and a scrollable list of at least 4 mock transactions.
- **FR-006**: Each transaction list item MUST show: a circular user avatar, a display name, a date/time string, and an amount — positive amounts in green, negative amounts in the primary text color.
- **FR-007**: A floating action button (FAB) with a scanner/QR frame icon MUST be centered at the bottom of the screen.
- **FR-008**: All visible text strings MUST use `easy_localization` keys (no hardcoded strings).

#### Screen 2 — Wallet Profile Screen

- **FR-009**: The screen MUST show a top navigation bar with title "Wallet Profile" (localized), a back arrow, a delete icon, and an edit icon.
- **FR-010**: The profile area MUST display a circular avatar with a green verified-checkmark badge, the user's display name, and phone number.
- **FR-011**: The information card MUST contain the following labeled rows: Ciro ID (with copy icon), Status (with green verified badge), Registration Date, Last Seen, Country (with flag image), Associated Bank (with copy icon).
- **FR-012**: The barcode action area MUST contain two side-by-side cards: "Share Barcode" and "View Barcode".
- **FR-013**: The settings section MUST be titled "Wallet Setting" (localized) and contain four tappable rows with trailing chevron arrows: Account Information, Verification & Security, Payment Method & Bank Account, Notification.
- **FR-014**: Each settings row MUST have a leading icon relevant to its category.

#### Screen 3 — Send Money Screen

- **FR-015**: The screen MUST display a search bar at the top with localized placeholder text ("Search by name, mobile or ciro id").
- **FR-016**: The screen MUST display three action shortcut buttons: Contact Ciro, Scan QR, Upload QR.
- **FR-017**: A "Suggested People" section MUST display at least 3 mock contact rows with: avatar, display name, phone number, Ciro ID, and trailing chevron.
- **FR-018**: A "Recent Transaction" section MUST display at least 3 mock entries with: initials avatar, display name, transaction type in green, date, amount in SAR, and trailing chevron.
- **FR-019**: Typing in the search bar MUST filter the Suggested People list in real-time on mock data.

#### Screen 4 — Receive Money Screen

- **FR-020**: The screen MUST display a centered card with: circular avatar with verified badge, user name, copyable Ciro ID in green, and a large QR code widget with the brand logo at its center.
- **FR-021**: The QR card MUST include a "Secure payments" row and a "QR refreshes automatically every 60 seconds" banner.
- **FR-022**: Below the QR card, three square action buttons MUST be displayed: Share QR, Download, Customize.
- **FR-023**: A dismissible bottom banner MUST be shown with a green verified icon, security advisory text, and a close button.

#### Screen 5 — Add Amount (Numpad) Screen

- **FR-024**: The screen MUST show the "ciro wallet" branded logo in the header.
- **FR-025**: The screen MUST display an "Add Amount" title and subtitle instruction text (both localized).
- **FR-026**: An amount input card MUST show a large numeric amount display with "SAR" in green and a "Minimum add 10 SAR" hint.
- **FR-027**: A payment method row MUST show the selected method (default: Apple Pay) and a green "Change" link.
- **FR-028**: A custom 12-key dialpad MUST be rendered as a 3x4 grid: digits 1-9, backspace key, digit 0, and a large green next/arrow button. The native device keyboard MUST NOT appear.
- **FR-029**: Tapping digit keys MUST append the digit to the amount display. Tapping backspace MUST remove the last digit. Minimum displayable value is "0".

#### Screen 6 — Payment Status Screen (Reusable)

- **FR-030**: The screen MUST accept a `PaymentStatus` parameter with two variants: `success` and `failed`.
- **FR-031**: In the `success` state: large green checkmark icon (3D-style circular badge), decorative confetti dots, localized title "Payment Successful", localized subtitle with amount and recipient name.
- **FR-032**: In the `failed` state: large red cross icon (3D-style circular badge), decorative confetti dots, localized title "Payment Failed", failure reason text in red.
- **FR-033**: Both states MUST display a Reference ID card with a receipt icon, "Reference ID" label, and the reference ID value in bold.
- **FR-034**: Both states MUST display a full-width green "Done" button that pops the payment flow back to the Main Wallet Screen.

### Key Entities

- **WalletUser**: Represents the wallet account holder — attributes: displayName, phoneNumber, ciroId, avatarUrl, status (Verified/Pending), registrationDate, lastSeen, country, associatedBank.
- **Transaction**: Represents a money movement — attributes: id, senderName, recipientName, amount (SAR), direction (incoming/outgoing), timestamp, referenceId.
- **Contact**: Represents a searchable payee — attributes: displayName, phoneNumber, ciroId, avatarUrl.
- **PaymentMethod**: Represents a funding source — attributes: type (ApplePay / Card / Bank), displayName, logoAsset.
- **PaymentResult**: Represents the outcome of a transaction attempt — attributes: status (success/failed), amount, recipientName, failureReason, referenceId.

---

## UI Design Specifications

### Brand & Color System

| Token | Value | Usage |
|-------|-------|-------|
| brandGreen | #2DB34A (approx.) | Primary actions, positive amounts, icons, FAB, buttons |
| gradientStart | #2DB34A | Balance card left/top |
| gradientEnd | #1A8FC0 | Balance card right/bottom |
| statusRed | #E53935 | Failed state icon, error text |
| textPrimary | #1A1A1A | Body text, names |
| textSecondary | #8A8A8A | Subtitles, dates |
| cardBackground | #FFFFFF | Cards, containers |
| scaffoldBackground | #F5F5F5 | Page background |

### Typography

- Display amount: fontSize 36, fontWeight bold, color textPrimary
- Balance card total: fontSize 28, fontWeight bold, color white
- Section headers: fontSize 16, fontWeight w600, color textPrimary
- Body/name: fontSize 14, fontWeight w500, color textPrimary
- Subtitle/date: fontSize 12, fontWeight normal, color textSecondary
- Button labels: fontSize 16, fontWeight bold, color white

### Component Specifications

#### Balance Card
- Gradient: LinearGradient from brandGreen to gradientEnd, left-to-right
- Border radius: 16px
- Padding: 20px horizontal, 16px vertical
- Divider: dashed horizontal line between Total Balance and Current Balance sections

#### Quick Action Button
- Container: 80x80dp, border radius 16px, white background, light shadow
- Icon: 28dp green icon centered
- Label: 12px below icon, centered

#### Transaction List Item
- Height: 72dp
- Avatar: 48dp circular
- Amount: right-aligned; positive in brandGreen, negative in textPrimary

#### Custom Numpad Key
- Regular key: white background, shadow, border radius 12px, fontSize 24, fontWeight w500
- Backspace key: light grey (#F0F0F0) background
- Next/arrow key: brandGreen background, white right-arrow icon

#### FAB (Scanner)
- Size: 64dp circular, brandGreen background
- Icon: QR-frame/scanner icon in white, 28dp
- Elevation: 6dp

---

## Localization Keys

All strings MUST be defined in the easy_localization translation files. Required keys:

wallet.title
wallet.totalBalance
wallet.currentBalance
wallet.balanceHidden
wallet.addMoney
wallet.send
wallet.receive
wallet.qrCode
wallet.recentTransactions
wallet.viewAll
wallet.profile.title
wallet.profile.ciroId
wallet.profile.status
wallet.profile.registrationDate
wallet.profile.lastSeen
wallet.profile.country
wallet.profile.associatedBank
wallet.profile.shareBarcode
wallet.profile.shareBarcodeDesc
wallet.profile.viewBarcode
wallet.profile.viewBarcodeDesc
wallet.profile.settings
wallet.profile.accountInfo
wallet.profile.verificationSecurity
wallet.profile.paymentMethod
wallet.profile.notification
wallet.send.title
wallet.send.searchHint
wallet.send.contactCiro
wallet.send.scanQr
wallet.send.uploadQr
wallet.send.suggestedPeople
wallet.send.recentTransaction
wallet.receive.title
wallet.receive.ciroId
wallet.receive.securePayments
wallet.receive.securePaymentsDesc
wallet.receive.qrRefresh
wallet.receive.shareQr
wallet.receive.download
wallet.receive.customize
wallet.receive.securityBanner
wallet.addAmount.title
wallet.addAmount.subtitle
wallet.addAmount.enterAmount
wallet.addAmount.minimumHint
wallet.addAmount.paymentMethod
wallet.addAmount.change
wallet.payment.success.title
wallet.payment.success.subtitle
wallet.payment.failed.title
wallet.payment.failed.subtitle
wallet.payment.failed.reason.insufficientBalance
wallet.payment.referenceId
wallet.payment.done

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: All 6 screens render without runtime errors on first launch on both Android and iOS simulators.
- **SC-002**: Navigation between all screens completes in under 500 ms on a mid-range device.
- **SC-003**: Balance visibility toggle responds in under 100 ms (single frame).
- **SC-004**: Custom numpad input updates the amount display within a single frame with no native keyboard visible.
- **SC-005**: The Payment Status screen renders correctly in both Success and Failed states with the correct icon color, title, subtitle, and reference card.
- **SC-006**: 100% of visible text strings are sourced from easy_localization keys — zero hardcoded strings.
- **SC-007**: Search filtering on the Send Money screen returns updated results within 200 ms of the last keystroke on mock data of up to 50 contacts.
- **SC-008**: Tapping "Done" on the Payment Status screen returns the user to the Main Wallet Screen with all intermediate screens removed from the navigation stack.

---

## Assumptions

- The wallet feature is accessed from an existing bottom navigation tab or a dedicated wallet entry point within the Ciro app.
- Mock data (contacts, transactions, balance amounts, reference IDs) is sufficient for the initial UI spec; real API integration is explicitly out of scope.
- The easy_localization package is already installed and configured in the project's pubspec.yaml.
- The brand green color is approximately #2DB34A; exact hex values will be confirmed against the design system token file before implementation.
- The QR code widget will use a Flutter QR-code generation package (e.g., qr_flutter); the brand logo is overlaid as a centered Image widget within the QR painter.
- The "confetti" decoration on the Payment Status screen is implemented with static positioned Container/CustomPaint colored dots.
- The Apple Pay logo displayed in the payment method row is a static local asset (SVG/PNG) — no Apple Pay SDK calls are made.
- All screens follow the app's existing scaffold structure (no new navigation shell required).
- Country flag images are sourced from a local assets/flags/ directory or a flags package already available in the project.
