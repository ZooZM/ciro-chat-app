# Feature Specification: Group Call UI Update

**Feature Branch**: `[TBD]`  
**Created**: 2026-06-03  
**Status**: Draft  
**Input**: User requested UI refinements based on attached video call images, with strict localization integration and JSON generation.

## Clarifications

### Session 2026-06-03
- Q: The mockups show call controls including a "Magic Wand" icon. What should happen when the user taps the Magic Wand icon? → A: leave it for now doesnt do anything and add the recording button and share screen on this ui
- Q: The active call grid shows up to 10 participants. If there are more than 10 participants in the group call, how should the UI handle the overflow? → A: Only the 9 most active speakers are shown, plus a "+N others" tile.
- Q: In the incoming call screen, what is the expected behavior when the user taps "Ignore"? → A: The UI will simply dismiss the incoming call screen. All backend logic for declining calls is out of scope for this UI update.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Incoming Group Call (Priority: P1)

Users should see a clear, localized incoming call screen indicating who is calling and giving options to join or ignore.

**Why this priority**: It is the entry point for the group call feature.

**Independent Test**: Can be tested by triggering a mock incoming call state and verifying UI layout and localized text.

**Acceptance Scenarios**:

1. **Given** an incoming call from "Ahmed Khaled", **When** the screen is displayed, **Then** it shows "{name} is calling you", "Ignore", and "Join" buttons, fully localized.
2. **Given** the user is viewing the incoming call screen, **Then** they see their profile initial "Y" with the localized text "You".

---

### User Story 2 - Waiting for Others (Priority: P2)

When a user joins a call before others, they should see a waiting screen.

**Why this priority**: Handles the edge case of being the first participant.

**Independent Test**: Join a call with no other participants and verify the waiting state UI.

**Acceptance Scenarios**:

1. **Given** the user is alone in the call, **When** the UI renders, **Then** it shows the localized text "Waiting for other people to join..." and a profile placeholder.

---

### User Story 3 - Active Group Call Grid (Priority: P1)

Users in a group call should see a dynamic grid of participants with their names and call controls.

**Why this priority**: Core functionality of the group call experience.

**Independent Test**: Mock a call with 5-10 participants and verify the grid layout, participant counts, and controls.

**Acceptance Scenarios**:

1. **Given** an active call with 5 participants, **When** the user views the grid, **Then** the header shows the localized text "{count} participants".
2. **Given** the active call screen, **Then** the "End Call" button is visible and localized.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The UI MUST implement the updated visual layout for incoming calls, waiting state, and active grid as depicted in the reference images.
- **FR-002**: The UI MUST use `easy_localization` for ALL visible text strings. Hardcoded strings are strictly forbidden (e.g. `Text('call_action_join').tr()`).
- **FR-003**: The UI MUST use parameterized localization keys for dynamic content (e.g., caller names, participant counts).
- **FR-004**: The UI MUST support rendering participant grids dynamically. If there are more than 10 participants, the grid MUST show the 9 most active speakers and one "+N others" tile.
- **FR-005**: The UI MUST include call controls (mic, camera, speaker, add person, screen share, recording, magic wand) and an "End Call" button. (Note: The magic wand button is present in the UI but currently performs no action).
- **FR-006**: When the user taps "Ignore" on an incoming call, the UI MUST dismiss the incoming call screen. Note: All backend logic for declining calls (e.g., sending notifications) is explicitly out of scope for this UI update.

### Localization Integration (JSON Generation)

The following key-value pairs MUST be added to the project's translation files to satisfy the `easy_localization` requirement:

#### `assets/translations/en.json`
```json
{
  "call_group_call": "Group call",
  "call_you": "You",
  "call_is_calling_you": "{name} is calling you",
  "call_action_ignore": "Ignore",
  "call_action_join": "Join",
  "call_waiting_others": "Waiting for other people to join...",
  "call_participants_count": "{count} participants",
  "call_action_end": "End Call"
}
```

#### `assets/translations/ar.json`
```json
{
  "call_group_call": "مكالمة جماعية",
  "call_you": "أنت",
  "call_is_calling_you": "{name} يتصل بك",
  "call_action_ignore": "تجاهل",
  "call_action_join": "انضمام",
  "call_waiting_others": "في انتظار انضمام الآخرين...",
  "call_participants_count": "{count} مشاركين",
  "call_action_end": "إنهاء المكالمة"
}
```

### Key Entities *(include if feature involves data)*

- **CallSession**: Represents the active call context, including participant count and caller name.
- **Participant**: Represents an individual in the call, including their name, initial, and audio/video status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of visible static text in the call screens uses `easy_localization` keys.
- **SC-002**: UI grid renders correctly on device screens for both 5 and 10 participant scenarios without layout overflow errors.
- **SC-003**: Translation JSON files are successfully updated with the required keys for both English and Arabic.

## Assumptions

- Closed caption text (e.g. "Doing great! Are you free for the meeting tomorrow ?") is user-generated content or dynamic real-time output and does not require static localization keys.
- Group names (e.g., "Tech Team") and user names (e.g. "Ahmed Khaled", "Sara") are dynamic data provided by the backend and not static localized strings.
- Icons (mic, camera, etc.) do not require text labels but should maintain semantic accessibility labels if applicable.
