# Feature Specification: Calls Tab UI

**Feature Branch**: `021-calls-tab-ui`  
**Created**: 2026-07-04  
**Status**: Draft  
**Input**: User description: "Calls tab and its related sub-screens — Calls History, Call Information, Select Contact (empty & selected states), and Dialpad — all UI-only with mock data and easy_localization."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse Call History (Priority: P1)

A user navigates to the "Calls" tab in the bottom navigation and sees a list of their most recent calls. Each call entry displays the contact's avatar (initials on a colored circle), the contact name (in red if the call was missed), a directional arrow icon with the call timestamp, and a trailing icon indicating whether it was a voice or video call. A search bar at the top allows filtering calls by name. A floating action button (green phone icon with a "+" badge) lets the user initiate a new call.

**Why this priority**: The call history list is the primary landing screen for the Calls tab. It is the entry point for every other screen in this feature.

**Independent Test**: Can be fully tested by viewing the Calls tab with hardcoded mock call records. Delivers value as a standalone browsable call log.

**Acceptance Scenarios**:

1. **Given** the user is on the home screen, **When** they tap the "Calls" tab in the bottom navigation, **Then** the Calls History screen appears showing a large "Calls" title, a search bar, a "Recent" section heading, and a scrollable list of call entries.
2. **Given** call history entries exist, **When** the screen renders, **Then** each entry shows: a circular avatar (color-coded initials or profile image), contact name (red for missed calls, black otherwise), a subtitle with direction arrow and timestamp, and a trailing voice/video call icon.
3. **Given** the user types in the search bar, **When** the query matches a contact name, **Then** only matching entries are shown.
4. **Given** the user taps the green FAB, **When** the screen navigates, **Then** the Select Contact screen opens.

---

### User Story 2 - View Call Information Details (Priority: P1)

A user taps on a call history entry to view detailed information about that call. The Call Information screen displays a large centered avatar and the contact's name, followed by an action row with three large square cards: "Messaging", "Video call", and "Voice call". Below the action row, a date-grouped call log section (e.g., "Today") lists individual call records showing direction ("Outgoing"/"Incoming"), time, and status (e.g., "Not answer").

**Why this priority**: Viewing call details and having quick-action buttons for messaging and re-calling is the natural next step after browsing call history.

**Independent Test**: Can be tested by navigating from any call history tile to the Call Information screen and verifying the layout, avatar, action cards, and call log section render correctly with mock data.

**Acceptance Scenarios**:

1. **Given** the user is on the Calls History screen, **When** they tap a call entry, **Then** the Call Information screen appears with a back arrow and "Call information" title in the AppBar.
2. **Given** the Call Information screen loads, **When** the screen renders, **Then** a large centered circular avatar with the contact's initials and their full name is displayed.
3. **Given** the Call Information screen loads, **When** the action row renders, **Then** three square cards are shown: "Messaging" (chat icon), "Video call" (video icon), and "Voice call" (phone icon), each with a green icon and a label below.
4. **Given** the call log section renders, **When** there are call records for today, **Then** a "Today" date header is shown followed by individual call entries with a phone icon, direction label, time, and status text.

---

### User Story 3 - Select Contact for New Call (Priority: P2)

A user taps the FAB on the Calls History screen and is taken to the Select Contact screen. This screen has an AppBar with "Select a contact" title, a contact count subtitle (e.g., "261 contacts"), and a search icon. Below the AppBar, two special list items appear: "New contact" and "Call a number", both with green circular leading icons. The contact list is divided into "Frequently contacted" and "contact" sections, with each entry having a circular avatar and an empty radio button on the trailing side.

**Why this priority**: Selecting a contact is a required step to initiate a new call, but comes after the core history browsing experience.

**Independent Test**: Can be tested by navigating to the Select Contact screen, verifying the layout with mock contacts, and checking that radio buttons are displayed but unselected (empty state).

**Acceptance Scenarios**:

1. **Given** the user taps the FAB from Calls History, **When** the Select Contact screen opens, **Then** the AppBar shows a back arrow, "Select a contact" title, a subtitle with contact count, and a search icon.
2. **Given** the screen loads, **When** the top action items render, **Then** "New contact" and "Call a number" entries appear with green circular leading icons (person-add icon and dialpad icon respectively).
3. **Given** contacts are available, **When** the list renders, **Then** contacts are grouped under "Frequently contacted" and "contact" section headers with circular avatars and trailing empty radio buttons.

---

### User Story 4 - Select Contact and Initiate Call (Priority: P2)

When the user taps on a contact in the Select Contact list, the contact becomes selected: the radio button fills green with a checkmark, and a new selection bar appears at the top of the list showing the selected contact as a "chip" (circular avatar with a small "×" cancel badge) and their truncated name below. To the right of the chip, voice call and video call action icons appear. The user can tap one of these icons to initiate a call.

**Why this priority**: This completes the "select and call" flow and is tightly coupled with User Story 3.

**Independent Test**: Can be tested by tapping a contact in the list and verifying the chip, action icons, and green-filled radio button render correctly.

**Acceptance Scenarios**:

1. **Given** the user is on the Select Contact screen (empty state), **When** they tap on a contact entry, **Then** the contact's radio button changes from empty to green with a checkmark.
2. **Given** a contact is selected, **When** the selection bar appears at the top, **Then** it shows the contact's avatar as a chip with a small "×" cancel badge, the contact's truncated name below it, and trailing voice call and video call icons.
3. **Given** a contact is selected with the chip visible, **When** the user taps the "×" badge on the chip, **Then** the contact is deselected, the chip disappears, and the radio button reverts to empty.
4. **Given** a contact is selected, **When** the user taps the voice or video call icon in the selection bar, **Then** the appropriate call action is triggered (no actual call logic — just callback invocation).

---

### User Story 5 - Use Dialpad to Call a Number (Priority: P3)

A user taps "Call a number" on the Select Contact screen and is taken to the Dialpad screen. This screen has a back arrow in the AppBar, a large numeric keypad grid arranged in a 4×3 layout (1-9, *, 0, #) using circular grey buttons, and a large green circular call button at the bottom center. The user can enter digits and press the call button.

**Why this priority**: The dialpad is an alternative path for initiating calls and is less commonly used than contact-based calling.

**Independent Test**: Can be tested independently by navigating to the Dialpad screen and verifying the keypad grid layout, button styling, and call button appearance.

**Acceptance Scenarios**:

1. **Given** the user taps "Call a number" on the Select Contact screen, **When** the Dialpad screen opens, **Then** the AppBar shows only a back arrow (no title text).
2. **Given** the Dialpad screen loads, **When** the keypad renders, **Then** 12 circular grey buttons are arranged in a 4×3 grid displaying 1, 2, 3, 4, 5, 6, 7, 8, 9, *, 0, # with large dark text.
3. **Given** the keypad is visible, **When** the user looks below the grid, **Then** a large green circular button with a white phone icon is displayed at the bottom center.
4. **Given** the user taps number buttons, **When** digits are entered, **Then** the entered number is displayed above the keypad (text display area).

---

### Edge Cases

- What happens when the call history list is empty? → An empty-state message ("No calls yet") is displayed.
- What happens when search returns no results? → The list shows no entries (empty list view).
- What happens when the user deselects the only selected contact? → The selection bar and action icons disappear, reverting to the empty state.
- What happens on very long contact names? → Names are truncated with ellipsis in the chip and list tiles.
- What happens when the dialpad number overflows the display area? → The number text scrolls horizontally or truncates from the left.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a "Calls" tab in the bottom navigation bar with a phone icon, navigating to the Calls History screen.
- **FR-002**: The Calls History screen MUST show a large "Calls" title, a rounded search bar with a search icon, and a "Recent" section heading.
- **FR-003**: Each call history entry MUST display a leading circular avatar (colored initials or profile image), a contact name (red for missed calls, black otherwise), a subtitle with a direction arrow (↗ for outgoing green, ↙ for incoming green, ↙ red for missed) and timestamp, and a trailing voice or video call icon.
- **FR-004**: The Calls History screen MUST include a green floating action button with a phone-plus icon that navigates to the Select Contact screen.
- **FR-005**: Tapping a call history entry MUST navigate to the Call Information screen for that contact.
- **FR-006**: The Call Information screen MUST display a back arrow AppBar with "Call information" title, a large centered avatar, the contact name, and three action cards ("Messaging", "Video call", "Voice call") with green icons.
- **FR-007**: The Call Information screen MUST show a date-grouped call log section below the action cards, with each entry showing a phone icon, direction label ("Outgoing"/"Incoming"), timestamp, and status ("Not answer" for missed calls).
- **FR-008**: The Select Contact screen MUST display an AppBar with back arrow, "Select a contact" title, contact count subtitle, and a search icon.
- **FR-009**: The Select Contact screen MUST show "New contact" and "Call a number" as the first two list items with green circular leading icons.
- **FR-010**: The Select Contact screen MUST group contacts under "Frequently contacted" and "contact" section headers, with each entry showing a circular avatar and a trailing radio button.
- **FR-011**: When a contact is selected, the system MUST show a green-checked radio button, a selection bar at the top with the contact's avatar chip (with "×" cancel badge), truncated name, and trailing voice/video call action icons.
- **FR-012**: The Dialpad screen MUST display a 4×3 numeric keypad grid (1–9, *, 0, #) using large circular grey buttons, a number display area above the grid, and a large green circular call button below.
- **FR-013**: All user-facing text strings MUST use `easy_localization` keys. No hardcoded strings in the UI layer.
- **FR-014**: All screens MUST use hardcoded mock data (no backend integration, no WebRTC, no device contacts API).
- **FR-015**: The UI MUST match the exact layout, colors, spacing, and typography shown in the provided reference screenshots.

### Key Entities

- **CallHistoryRecord**: Represents a single call log entry — includes contact identifier, contact name, avatar URL, call direction (incoming/outgoing), call outcome (answered/missed/declined), call type (voice/video), timestamp, and duration. Already exists in the codebase.
- **ContactEntry**: Represents a selectable contact in the contact picker — includes name, avatar URL/initials, avatar color seed, and selection state. Used as mock data for the Select Contact screen.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 5 screens (Calls History, Call Information, Select Contact empty, Select Contact selected, Dialpad) render correctly and match the provided reference screenshots in layout, colors, and typography.
- **SC-002**: The Calls History screen displays at least 8 mock call entries with varied avatars, names, directions, times, and call types without any layout overflow or clipping.
- **SC-003**: Navigation flows work end-to-end: Calls tab → History → Call Info (via tap), History → Select Contact (via FAB) → Dialpad (via "Call a number").
- **SC-004**: All user-facing text is localized — replacing the locale correctly swaps all visible strings.
- **SC-005**: The Select Contact screen correctly toggles between empty state and selected state when a contact is tapped, with the chip bar appearing and disappearing as expected.
- **SC-006**: The Dialpad screen renders a complete 4×3 keypad with correctly styled buttons and a functional-looking green call button.
- **SC-007**: The app renders all screens at 60fps with no jank or layout warnings during scrolling.

## Assumptions

- The existing `CallHistoryRecord` entity and `CallHistoryCubit` will be reused for the Calls History screen, supplemented with mock data when the repository returns empty results during development.
- The "Calls" tab already exists in the bottom navigation bar (route `AppRouterName.calls` is defined). This feature updates the screens navigated to from that tab.
- No actual call initiation, WebRTC, or device contacts permission logic will be wired. Callback handlers will accept `VoidCallback` parameters for future integration.
- The avatar color palette follows the existing `_avatarPalette` pattern in `CallHistoryTile`.
- "New contact" item navigates to a placeholder or is a no-op callback for now; "Call a number" navigates to the Dialpad screen.
- The specific green used for the call button and action icons is approximately `Color(0xFF4CAF50)` / `Colors.green`, matching the existing app convention.
- Arabic (`ar.json`) translations will be provided alongside English (`en.json`) for all new localization keys.
