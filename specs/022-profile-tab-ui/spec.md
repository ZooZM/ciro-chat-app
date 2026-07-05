# Feature Specification: Profile Tab UI

**Feature Branch**: `022-profile-tab-ui`  
**Created**: 2026-07-05  
**Status**: Draft  
**Input**: User description: "Profile tab and its related sub-screens — Main Profile Tab, QR Code, Profile Info (Edit), Appearance, and Chat Theme Preview — all UI-only with mock data and easy_localization."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Profile Tab (Priority: P1)

A user navigates to the "Profile" tab in the bottom navigation and sees their personal profile overview. The screen has a "Profile" title at the top with a QR Code icon button on the right. Below the header, the user section shows a circular avatar with a camera badge overlay at the bottom-right, their full name ("Ahmed Mohamed"), a bio/status line ("Living the moment"), a Ciro ID ("CIR123456") with a copy icon next to it, and an edit pencil icon on the far right.

Below the user section, a Wallet Card is displayed — a gradient card transitioning from green to blue, showing "Total Balance" with a large formatted amount ("12,450.50 SAR"), a "Current Balance" with its amount ("12,120. SAR"), and a visibility (eye) toggle icon in the top-right corner. A wallet icon sits in the top-left of the card.

Next is a Profile Completion section showing a percentage label ("60%") and a linear progress bar (brand green, 60% filled), with supporting text "Complete your profile to unlock all features".

Finally, a settings list contains four menu items presented as ListTiles with leading icons, titles, subtitles, and trailing chevron arrows:
1. **Appearance** — "Theme, Colors, Background" (emoji/smiley icon)
2. **Linked Devices** — "Manage your devices" (devices icon)
3. **Invite a Friend** — "Share the app with friends" (person-add icon)
4. **Language** — "App Language" (globe icon)

**Why this priority**: The main Profile tab is the landing screen for all profile-related functionality. It is the single entry point for every sub-screen in this feature.

**Independent Test**: Can be fully tested by navigating to the Profile tab and verifying all sections (user info, wallet card, progress bar, settings list) render correctly with hardcoded dummy data.

**Acceptance Scenarios**:

1. **Given** the user is on any tab, **When** they tap the "Profile" tab in the bottom navigation, **Then** the Profile screen appears showing the "Profile" title and a QR Code icon button in the top header area.
2. **Given** the Profile screen loads, **When** the user section renders, **Then** a circular avatar with a camera badge is displayed, alongside the user's name, bio, Ciro ID with a copy icon, and a pencil edit icon.
3. **Given** the Profile screen loads, **When** the wallet card renders, **Then** a green-to-blue gradient card shows "Total Balance" with "12,450.50 SAR", "Current Balance" with "12,120. SAR", a wallet icon, and an eye visibility icon.
4. **Given** the Profile screen loads, **When** the profile completion section renders, **Then** a progress bar at 60% fill is displayed with the text "60%" and "Complete your profile to unlock all features".
5. **Given** the Profile screen loads, **When** the settings list renders, **Then** four ListTile items appear for Appearance, Linked Devices, Invite a Friend, and Language — each with a specific leading icon, subtitle, and trailing chevron arrow.

---

### User Story 2 - View QR Code Screen (Priority: P1)

A user taps the QR Code icon button on the top-right of the Profile tab and is taken to the QR Code screen. The screen has an AppBar with a back arrow, "QR Code" title, and a share icon on the right. The center of the screen contains a card with the user's circular avatar, their full name, their Ciro ID with a copy icon, and a large QR code image (placeholder/mock). Below the QR code card, a descriptive paragraph reads: "A QR code is a code that's unique to you. If you share it with someone, they can scan it using their CIRO camera to add you as a contact." At the bottom, a large green "Scan" button is displayed (full-width, rounded), and below it a "Reset QR code" text button.

**Why this priority**: The QR code screen is a direct action from the Profile tab header and is essential for user identity sharing.

**Independent Test**: Can be tested by navigating from the Profile tab to the QR Code screen and verifying the avatar, name, Ciro ID, QR image placeholder, description text, and both buttons render correctly.

**Acceptance Scenarios**:

1. **Given** the user is on the Profile tab, **When** they tap the QR Code icon button, **Then** the QR Code screen opens with an AppBar containing a back arrow, "QR Code" title, and a share icon.
2. **Given** the QR Code screen loads, **When** the center card renders, **Then** the user's avatar, name ("Ahmed Mohamed"), and Ciro ID ("CIR123456") with a copy icon are displayed above a large QR code placeholder image.
3. **Given** the QR Code screen loads, **When** the description renders, **Then** the text paragraph about the QR code's purpose is shown below the card.
4. **Given** the QR Code screen loads, **When** the bottom area renders, **Then** a large rounded green "Scan" button and a "Reset QR code" text button are displayed.

---

### User Story 3 - Edit Profile Info (Priority: P2)

A user taps the pencil edit icon on the Profile tab and is taken to the Profile Info screen. The screen has an AppBar with a back arrow and "Profile Info" title. Below the AppBar, a large circular avatar is displayed with a green camera badge overlay at the bottom-right. Below the avatar are two rounded text input fields: one for "Name" (required) and one for "About (Optional)". At the bottom of the screen, a large rounded green "Save info" button is displayed.

**Why this priority**: Editing profile information is a core user action but depends on the main Profile tab being built first.

**Independent Test**: Can be tested by navigating from the Profile tab to the Profile Info screen and verifying the avatar, both text fields, and the Save button render correctly.

**Acceptance Scenarios**:

1. **Given** the user is on the Profile tab, **When** they tap the pencil edit icon, **Then** the Profile Info screen opens with an AppBar showing a back arrow and "Profile Info" title.
2. **Given** the Profile Info screen loads, **When** the avatar section renders, **Then** a large circular avatar with a green camera badge at the bottom-right is displayed.
3. **Given** the Profile Info screen loads, **When** the input fields render, **Then** a "Name" text field and an "About (Optional)" text field are displayed, both with rounded green-outlined borders.
4. **Given** the Profile Info screen loads, **When** the bottom renders, **Then** a large rounded green "Save info" button spanning full width is displayed.

---

### User Story 4 - Customize Appearance (Priority: P2)

A user taps the "Appearance" item in the settings list on the Profile tab and navigates to the Appearance screen. The screen has an AppBar with a back arrow and "Appearance" title. The screen body is divided into three sections:

1. **Chat Theme**: A "Chat Theme" label followed by a horizontal scrollable row of theme preview cards. Each card is a small rectangular thumbnail showing a chat UI preview with different background styles. The currently selected card has a green border.
2. **Chat Color**: A "Chat Color" label followed by a grid/wrap of circular color swatches. The selected swatch has a white checkmark overlay. The grid contains multiple rows of colors spanning various hues (greens, blues, purples, browns, pinks, etc.).
3. **Chat Background**: A "Chat Background" label followed by a horizontal scrollable row of background image thumbnails. The first thumbnail is an "Add +" placeholder (grey background with a "+" icon) that lets the user pick a custom background.

At the bottom, a large rounded green "Preview Chat" button spans full width.

**Why this priority**: Appearance customization is a secondary feature that enriches the profile experience but is not essential for core profile viewing.

**Independent Test**: Can be tested by navigating to the Appearance screen and verifying all three sections (themes, colors, backgrounds) render with mock data, selection states work, and the Preview button is present.

**Acceptance Scenarios**:

1. **Given** the user is on the Profile tab, **When** they tap "Appearance" in the settings list, **Then** the Appearance screen opens with an AppBar showing a back arrow and "Appearance" title.
2. **Given** the Appearance screen loads, **When** the Chat Theme section renders, **Then** a horizontally scrollable row of theme preview cards is displayed, with one card having a green selection border.
3. **Given** the Appearance screen loads, **When** the Chat Color section renders, **Then** a grid of circular color swatches is displayed, with one swatch showing a white checkmark.
4. **Given** the Appearance screen loads, **When** the Chat Background section renders, **Then** a horizontally scrollable row of background thumbnails is displayed, with the first item being an "Add +" placeholder.
5. **Given** the user taps a different color swatch, **When** the selection changes, **Then** the checkmark moves to the newly selected swatch and the previous one loses its checkmark.
6. **Given** the Appearance screen is fully rendered, **When** the user looks at the bottom, **Then** a large green "Preview Chat" button is displayed.

---

### User Story 5 - Preview Chat Theme (Priority: P3)

A user taps the "Preview Chat" button on the Appearance screen and is taken to a full-screen Chat Theme Preview. The background fills the entire screen with the selected theme image. A back arrow is overlaid on the top. The body of the screen shows mock chat bubbles simulating a conversation:

- Sent messages (left-aligned, themed tint color) with timestamps and blue double-check read ticks.
- Received messages (right-aligned, white/light background) with timestamps.

The conversation includes messages like "Hey! How are you?", "I'm good, thanks! How about you?", "Doing great! Are you free for the meeting tomorrow?", "Yes, absolutely! What time?", and "Let's meet at 2:45 PM" with timestamps between 10:30 AM and 10:35 AM.

At the bottom, the text "This is how your chat will look" is displayed, followed by a large rounded green "Apply Theme" button.

**Why this priority**: This is a preview/confirmation screen that depends on the Appearance screen being built first. It provides the final visual feedback before applying a theme.

**Independent Test**: Can be tested by navigating from the Appearance screen to the preview and verifying the full-screen background, mock chat bubbles, descriptive text, and Apply Theme button render correctly.

**Acceptance Scenarios**:

1. **Given** the user is on the Appearance screen, **When** they tap the "Preview Chat" button, **Then** the Chat Theme Preview screen opens with a full-screen background image matching the selected theme.
2. **Given** the preview screen loads, **When** the top renders, **Then** a white/light back arrow is overlaid on the background.
3. **Given** the preview screen loads, **When** the chat body renders, **Then** mock chat bubbles are displayed — sent messages (themed tint, left-aligned) with timestamps and read ticks, and received messages (light background, right-aligned) with timestamps.
4. **Given** the preview screen is fully rendered, **When** the user looks at the bottom, **Then** the text "This is how your chat will look" and a large rounded green "Apply Theme" button are displayed.

---

### Edge Cases

- What happens when the avatar image fails to load? → A fallback initials-based avatar with a colored background is displayed.
- What happens when the Ciro ID copy icon is tapped? → The Ciro ID text is copied to the clipboard and a brief "Copied" snackbar is shown (mock behavior).
- What happens when "Save info" is tapped with an empty name field? → The button is visually present but no validation logic is implemented (UI only).
- What happens when the user scrolls through theme preview cards that exceed the viewport? → The horizontal scroll view allows smooth scrolling without overflow.
- What happens when no chat color is selected? → The first color swatch in the grid is selected by default with a checkmark.
- What happens when a very long bio/status text is provided? → The text is truncated with ellipsis in the Profile tab user section.
- What happens when the wallet balance visibility eye icon is tapped? → The balance toggles between visible (actual numbers) and hidden (asterisks or dots). This is local UI state only.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a "Profile" tab in the bottom navigation bar, navigating to the Main Profile screen.
- **FR-002**: The Profile screen MUST show a top header with a "Profile" title and a QR Code icon button on the right.
- **FR-003**: The Profile screen MUST display a user section containing: a circular avatar (~80px) with a camera badge at the bottom-right, the user's name, a bio/status line, a Ciro ID with a copy icon, and an edit pencil icon on the far right.
- **FR-004**: The Profile screen MUST display a Wallet Card with a green-to-blue linear gradient, showing "Total Balance" label, a large formatted balance with currency ("SAR"), "Current Balance" label with its amount, a wallet icon (top-left), and a visibility eye icon (top-right).
- **FR-005**: The Profile screen MUST display a Profile Completion section with a percentage label, a linear progress bar (brand green fill), and a supporting description text.
- **FR-006**: The Profile screen MUST display a settings list containing four items: Appearance (theme/colors/background), Linked Devices (manage devices), Invite a Friend (share app), and Language (app language) — each with a specific leading icon, title, subtitle, and trailing chevron arrow.
- **FR-007**: Tapping the QR Code icon MUST navigate to the QR Code screen.
- **FR-008**: The QR Code screen MUST display an AppBar with back arrow, "QR Code" title, and a share icon. The body shows the user's avatar, name, Ciro ID with copy icon, a large QR code placeholder image, and a descriptive paragraph.
- **FR-009**: The QR Code screen MUST display a full-width rounded green "Scan" button and a "Reset QR code" text button below it.
- **FR-010**: Tapping the edit pencil icon on the Profile tab MUST navigate to the Profile Info screen.
- **FR-011**: The Profile Info screen MUST display an AppBar with back arrow and "Profile Info" title, a large circular avatar with a green camera badge, a "Name" text field, an "About (Optional)" text field (both with rounded green borders), and a full-width rounded green "Save info" button at the bottom.
- **FR-012**: Tapping the "Appearance" settings item MUST navigate to the Appearance screen.
- **FR-013**: The Appearance screen MUST display an AppBar with back arrow and "Appearance" title, and three sections: Chat Theme (horizontal scrollable theme preview cards with green selection border), Chat Color (grid of circular color swatches with white checkmark on selection), and Chat Background (horizontal scrollable background thumbnails with an "Add +" first item).
- **FR-014**: Only one theme card, one color swatch, and one background image can be selected at a time in the Appearance screen (single-selection per category).
- **FR-015**: The Appearance screen MUST display a full-width rounded green "Preview Chat" button at the bottom.
- **FR-016**: Tapping "Preview Chat" MUST navigate to the Chat Theme Preview screen.
- **FR-017**: The Chat Theme Preview screen MUST display a full-screen background image (matching selected theme), an overlaid back arrow, mock chat bubbles (sent and received with timestamps and read ticks), the text "This is how your chat will look", and a full-width rounded green "Apply Theme" button.
- **FR-018**: All user-facing text strings MUST use `easy_localization` keys. No hardcoded strings in the UI layer.
- **FR-019**: All screens MUST use hardcoded mock data (no backend integration, no real QR scanner, no actual wallet logic, no image picker).
- **FR-020**: The UI MUST match the exact layout, colors, spacing, gradients, and typography shown in the provided reference screenshots.
- **FR-021**: The wallet card visibility toggle MUST toggle balance display between visible amounts and obscured (asterisks/dots) states using local widget state only.

### Key Entities

- **UserProfile**: Represents the current user's profile data — includes name, bio/status text, Ciro ID, avatar URL, profile completion percentage. Used as mock data for the Profile tab and QR Code screen.
- **WalletInfo**: Represents the user's wallet — includes total balance amount, current balance amount, currency code ("SAR"), and visibility toggle state. Mock data displayed in the gradient card.
- **ThemePreview**: Represents a chat theme option — includes a thumbnail image and a selection state. Used in the Appearance screen's horizontal theme list.
- **ChatColorOption**: Represents a selectable chat color — includes color value and selection state. Used in the Appearance screen's color grid.
- **BackgroundOption**: Represents a selectable chat background — includes a thumbnail image, an "is custom add" flag, and a selection state. Used in the Appearance screen's background list.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 5 screens (Main Profile Tab, QR Code, Profile Info, Appearance, Chat Theme Preview) render correctly and match the provided reference screenshots in layout, gradients, colors, and typography.
- **SC-002**: The Profile tab displays the user section, wallet card, profile completion bar, and all four settings items without any layout overflow or clipping on standard device sizes.
- **SC-003**: Navigation flows work end-to-end: Profile tab → QR Code (via icon), Profile tab → Profile Info (via pencil), Profile tab → Appearance (via list item) → Chat Theme Preview (via button).
- **SC-004**: All user-facing text is localized — replacing the locale correctly swaps all visible strings across all 5 screens.
- **SC-005**: The Appearance screen correctly handles single-selection across all three categories (theme, color, background) with visual feedback (green border, checkmark, highlight).
- **SC-006**: The wallet card gradient transitions smoothly from green to blue, and the visibility toggle correctly alternates between showing and hiding balance amounts.
- **SC-007**: The app renders all screens at 60fps with no jank or layout warnings during scrolling of horizontal lists and the settings list.
- **SC-008**: The QR Code screen correctly renders the mock QR image placeholder, and both bottom buttons ("Scan" and "Reset QR code") are visible and styled correctly.

## Assumptions

- The "Profile" tab already exists in the bottom navigation bar (route `AppRouterName.profile` is defined at `/profile`). This feature creates the actual Profile screen and its sub-screens.
- No actual camera, image picker, QR scanner, or wallet integration will be implemented. All interactive elements (camera badge, share icon, scan button) are no-op callbacks or show mock behavior.
- The avatar uses a placeholder/dummy network image URL or asset image. No real user data is fetched.
- The wallet amounts (12,450.50 SAR, 12,120. SAR) are hardcoded mock values and do not come from any payment or wallet service.
- The Profile Completion percentage (60%) is a static hardcoded value with no dynamic calculation.
- The QR code image is a static placeholder asset or a generated placeholder — no real QR encoding logic.
- The Appearance screen uses placeholder theme preview images and background thumbnails. These are either local assets or solid color containers mimicking the look.
- The chat color palette in the Appearance screen contains approximately 20 predefined colors matching the screenshot layout (3 rows of 7 + partial row).
- Arabic (`ar.json`) translations will be provided alongside English (`en.json`) for all new localization keys.
- The specific brand green used for buttons, badges, and accents is the app's existing `AppColors.primary` (approximately `Color(0xFF4CAF50)` or similar green shade).
- The typo "Sacn" visible in the reference screenshot is corrected to "Scan" in the implementation.
- The typo "This is how your chat wil look" visible in the reference screenshot is corrected to "This is how your chat will look" in the implementation.
