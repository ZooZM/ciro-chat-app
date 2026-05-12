# Feature Specification: Status Creation Flow

**Feature Branch**: `005-status-creation-flow`  
**Created**: May 12, 2026  
**Status**: Draft  
**Input**: User description: "Complete Status Creation Flow with Add Status bottom sheet, Text/Voice/Camera editors, Music selector, AI Image generator, privacy controls, background color picker, and status viewer."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open Add Status Bottom Sheet (Priority: P1)

A user wants to create a new status update. They tap the "+" button (Pencil FAB or Camera FAB) on the Updates screen, which launches a bottom sheet titled "Add Status". The bottom sheet displays a horizontal row of category chips (Text, Music, Voice, AI Image), a "Recently Used" label, a Camera quick-access tile, and a scrollable grid of the user's gallery photos/videos for quick selection.

**Why this priority**: This is the entry point to the entire status creation flow. Without it, no content can be created.

**Independent Test**: Can be tested by tapping the FAB on the Updates screen and verifying the bottom sheet appears with the correct layout, category chips, camera tile, and gallery thumbnails.

**Acceptance Scenarios**:

1. **Given** the user is on the Updates screen, **When** they tap the Pencil FAB or the "Add Status" tile, **Then** a draggable bottom sheet slides up with the title "Add Status", a close (×) button, category chips (Text, Music, Voice, AI Image), a "Recently Used" label, a Camera tile, and a grid of gallery images.
2. **Given** the bottom sheet is visible, **When** the user taps the "×" button, **Then** the bottom sheet dismisses and returns the user to the Updates screen.
3. **Given** the bottom sheet is visible, **When** the user taps a gallery image, **Then** the system navigates to an image/video preview editor where the user can add a caption and send the status.

---

### User Story 2 - Create Text Status (Priority: P1)

A user selects the "Text" chip from the bottom sheet (or switches to the "Text" mode from the full-screen editor). A full-screen colored canvas appears with a centered "Write Status" placeholder. The user types their message. A toolbar at the top provides a Color Palette button, a Font Style (Aa) button, and a Privacy/Mention (@) button. A bottom bar shows mode-switching pills: Video, Image, Text (active/highlighted), Voice. The user can change the background color using a grid of ~24 curated colors. They can set privacy (Public / Private / Show on Map) via a dropdown triggered from the @ button or a dedicated "Map" button. Once done, they tap "Done" to publish.

**Why this priority**: Text statuses are the most universally used and require no external media or permissions.

**Independent Test**: Open Text mode, type a message, change the background color, set privacy to Private, tap Done, and verify the status is published.

**Acceptance Scenarios**:

1. **Given** the user taps the "Text" chip or is on the Text tab, **When** the editor loads, **Then** a full-screen colored canvas appears with a centered text input placeholder "Write Status" and a toolbar with Color Palette, Font Style (Aa), and Privacy (@) buttons.
2. **Given** the text editor is open, **When** the user taps the Color Palette icon, **Then** a grid of ~24 background colors appears at the bottom of the screen, the user can select one, and the canvas background updates instantly.
3. **Given** the color picker is showing, **When** the user taps "Done" (top-right), **Then** the color picker closes or the status is submitted (depending on state).
4. **Given** the text editor is open, **When** the user taps the Privacy button (@ or Map icon), **Then** a dropdown appears with three options: "Public (All contacts)", "Private (Select contacts)", and "Show on Map".
5. **Given** the user selects "Private (Select contacts)", **When** the privacy is set, **Then** a contact picker should allow them to choose which contacts can view the status.
6. **Given** the user has typed text and configured settings, **When** they tap "Done", **Then** the status is uploaded to the server with the text content, background color, font style, and privacy setting.

---

### User Story 3 - Create Voice Status (Priority: P2)

A user switches to the "Voice" tab from the bottom bar. The editor shows the same colored canvas with a voice recording UI at the center — an avatar circle (user's initials) with a microphone icon, and a waveform/dotted visualization bar. A dedicated microphone button appears next to the bottom mode-switching bar. The user taps and holds (or taps to toggle) the mic button to record. Once recorded, they can preview, re-record, or send.

**Why this priority**: Voice statuses add a personal, expressive medium and are increasingly popular in messaging apps.

**Independent Test**: Switch to Voice tab, record a voice clip, verify the waveform visualization renders, then submit the status and confirm it is uploaded.

**Acceptance Scenarios**:

1. **Given** the user taps the "Voice" pill in the bottom bar, **When** the voice editor loads, **Then** the canvas background persists, the top toolbar shows Color Palette and Privacy buttons (no Font Style since there is no text), and the center shows a voice recording UI with the user's avatar/initials and a waveform bar.
2. **Given** the voice editor is active, **When** the user taps the microphone button, **Then** recording begins, the waveform animates in real-time, and a timer or visual indicator shows recording progress.
3. **Given** a recording is complete, **When** the user releases the mic button or taps stop, **Then** the recorded audio is stored temporarily, a playback preview is available, and the user can submit or re-record.
4. **Given** the user submits the voice status, **When** uploaded, **Then** the status contains the audio file URL, background color, and privacy setting.

---

### User Story 4 - Select Music for Status (Priority: P2)

A user taps the "Music" chip from the Add Status bottom sheet. A new bottom sheet (Music Selector) slides up with a search bar at the top, filter chips (Suggestions, Mood, Type), and a scrollable list of songs. Each song row shows a thumbnail, song name, artist, duration, and a circular arrow/play button. The user taps a song to select it, which attaches it as the audio backdrop for their status.

**Why this priority**: Music integration enhances creative expression and makes the feature competitive with Instagram Stories and WhatsApp Status.

**Independent Test**: Tap Music chip, search for a song, tap a song row, verify it is selected and attached as the background audio for the next status.

**Acceptance Scenarios**:

1. **Given** the user taps the "Music" chip, **When** the Music Selector loads, **Then** a bottom sheet appears with a search bar, category chips (Suggestions, Mood, Type), and a list of available songs with thumbnails, names, artists, and durations.
2. **Given** the Music Selector is open, **When** the user types in the search bar, **Then** the song list filters in real-time to show matching results.
3. **Given** the user taps a song's play/preview button, **When** the action is triggered, **Then** a short preview of the song plays.
4. **Given** the user taps the arrow/select button on a song, **When** the song is selected, **Then** the user is navigated to the text/media editor with the selected song attached as background audio.

---

### User Story 5 - Generate AI Image for Status (Priority: P3)

A user taps the "AI Image" chip (partially visible, scrolled to reveal "Ai I…" on the Add Status sheet). A bottom sheet titled "Create any image" appears, showing a 2-column grid of pre-generated sample/inspiration images. At the bottom, there is a text input field with placeholder "Create image for...." and a microphone icon for voice-to-text input. The user types or speaks a prompt, and the system generates an AI image that can be used as a status.

**Why this priority**: AI image generation is a differentiating feature but is optional for MVP since it depends on an external AI image generation service.

**Independent Test**: Tap AI Image chip, type a prompt like "A sunset over the pyramids", submit, verify a generated image appears, and confirm the user can post it as a status.

**Acceptance Scenarios**:

1. **Given** the user taps the "AI Image" chip, **When** the AI Image Creator loads, **Then** a bottom sheet appears titled "Create any image" with a 2-column grid of sample/inspiration images and a text input at the bottom.
2. **Given** the AI Image Creator is open, **When** the user types a description and submits, **Then** the system sends the prompt to an AI generation service and displays a loading indicator.
3. **Given** the AI image is generated, **When** the result is returned, **Then** the generated image is displayed, and the user can choose to post it as a status or generate a new one.
4. **Given** the text input has a microphone icon, **When** the user taps it, **Then** voice-to-text is activated to convert speech to a text prompt.

---

### User Story 6 - View and Interact with a Status (Priority: P1)

A user views another contact's status in a full-screen viewer. The viewer shows the status content (image/text/video) full-screen, a linear progress bar at the top indicating multiple status segments, the author's name and avatar in the top-left, a timestamp ("Yesterday"), a caption at the bottom ("Good morning"), a "Reply" text input, and a heart/like icon. Users can tap to advance, swipe to skip to the next contact's status, or reply directly.

**Why this priority**: Consuming statuses is equal in importance to creating them — this is the core consumption experience.

**Independent Test**: Tap a status from the Updates screen, verify the full-screen viewer opens with the progress bar, author info, caption, reply field, and heart icon.

**Acceptance Scenarios**:

1. **Given** the user taps a status on the Updates screen, **When** the viewer opens, **Then** the status content fills the screen with a segmented progress bar at the top, author avatar and name in the top-left, timestamp below the name, content caption at the bottom, a "Reply" input field, and a heart icon.
2. **Given** the viewer is showing a status, **When** the user taps the right side of the screen, **Then** the viewer advances to the next status segment (progress bar updates).
3. **Given** the viewer is showing a status, **When** the user types in the "Reply" field and sends, **Then** a direct message reply is sent to the status author.
4. **Given** the viewer is showing a status, **When** the user taps the heart icon, **Then** a "like" reaction is sent to the status author.

---

### Edge Cases

- What happens when the user's device has no camera or denies camera permission? The Camera tile should show a disabled state or prompt the user to grant permission via system settings.
- What happens when the music catalog is empty or the server is unreachable? The Music Selector should show an empty state with a "No songs available" message and a retry option.
- What happens when the AI image generation fails or times out? The user should see an error message with an option to retry or modify their prompt.
- What happens if the user's internet drops mid-upload of a status? The status should be queued locally and retried automatically when connectivity is restored.
- What happens if the voice recording exceeds the maximum duration? Recording should auto-stop at the limit and the user should be notified of the maximum duration.
- What happens when the gallery permission is denied? The gallery grid should show an empty state with a prompt to grant storage/photo access.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST present an "Add Status" bottom sheet as the unified entry point for all status creation modes, triggered by the Pencil FAB, Camera FAB, or "Add Status" tile on the Updates screen.
- **FR-002**: The Add Status bottom sheet MUST display horizontally scrollable category chips: Text, Music, Voice, and AI Image.
- **FR-003**: The Add Status bottom sheet MUST display a "Camera" quick-access tile and a scrollable grid of the user's recent gallery photos/videos under a "Recently used" label.
- **FR-004**: The Text Status Editor MUST provide a full-screen colored canvas with centered text input, a top toolbar (Color Palette, Font Style, Privacy), and a bottom mode-switching bar (Video, Image, Text, Voice).
- **FR-005**: The Text Status Editor MUST support background color customization via a grid of at least 24 curated color swatches.
- **FR-006**: The Text Status Editor MUST support privacy controls with three options: Public (All contacts), Private (Select contacts), and Show on Map.
- **FR-007**: The Voice Status Editor MUST provide a recording interface with the user's avatar, a waveform/visualization bar, and a microphone action button.
- **FR-008**: The Voice Status Editor MUST show a real-time waveform animation during active recording.
- **FR-009**: The Music Selector MUST display a searchable, categorized list of songs sourced from the backend team's REST endpoint, showing thumbnails, song name, artist, duration, and a selection/play button.
- **FR-010**: The Music Selector MUST support filtering by category chips: Suggestions, Mood, and Type, with pagination support for large catalogs.
- **FR-011**: The AI Image Generator MUST accept text prompts (typed or via voice-to-text), send them to the backend proxy (which forwards to OpenAI DALL-E), and display the generated image in a preview before posting.
- **FR-012**: The AI Image Generator MUST show a grid of sample/inspiration images for user guidance.
- **FR-013**: The Status Viewer MUST display content full-screen with a segmented progress bar, author info (avatar, name, timestamp), caption, Reply input, and a heart/like button.
- **FR-014**: The Status Viewer MUST support tap-to-advance between status segments and swipe-to-skip between contacts.
- **FR-015**: System MUST support replying to a status, which sends a direct message to the status author.
- **FR-016**: System MUST queue failed status uploads locally and retry automatically when connectivity is restored.
- **FR-017**: The mode-switching bottom bar MUST allow seamless switching between Video, Image, Text, and Voice modes while preserving the selected background color and privacy settings.
- **FR-018**: The Video mode MUST support recording or selecting video clips up to 30 seconds in duration. Videos exceeding 30 seconds from the gallery MUST be rejected with a user-friendly message.
- **FR-019**: The Image mode MUST support capturing photos via camera or selecting from the device gallery.

### Key Entities

- **StatusDraft**: Represents an in-progress status being composed — includes content type (text/voice/image/video), text content, background color, font style, privacy setting, attached media URL, attached music track, and recording data.
- **MusicTrack**: Represents a selectable song — includes ID, name, artist, duration, thumbnail URL, and audio preview URL.
- **StatusPrivacy**: Represents the visibility configuration — includes privacy level (public/private/map) and an optional list of selected contact IDs for the "private" mode.
- **AIImagePrompt**: Represents a user request for AI image generation — includes the text prompt, generation status, and resulting image URL.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can open the Add Status bottom sheet and navigate to any creation mode (Text, Voice, Music, AI Image) within 2 seconds of tapping the trigger.
- **SC-002**: Users can compose and publish a text status with a custom background color in under 30 seconds.
- **SC-003**: The background color picker renders all 24+ color swatches and updates the canvas within 100ms of selection.
- **SC-004**: Voice recording starts within 500ms of tapping the microphone button with real-time waveform visualization.
- **SC-005**: The Music Selector search filters results as-you-type with no perceptible delay.
- **SC-006**: AI Image generation returns a result within 15 seconds of submitting a prompt (subject to network and service performance).
- **SC-007**: The Status Viewer loads and displays content within 1 second of tapping a status, with smooth progress bar animation.
- **SC-008**: 95% of status uploads complete successfully on the first attempt when the user has a stable connection.
- **SC-009**: Failed uploads are retried and succeed within 60 seconds of connectivity restoration.

## Assumptions

- The existing `SocketService` infrastructure supports status upload events and can be extended for new status types (voice, music-attached).
- The device camera and gallery access will use platform-standard permission request flows; no custom permission UI is required beyond fallback prompts.
- The backend team owns and provides a paginated REST endpoint for the music catalog (listing, search, category filtering). The client consumes this endpoint directly.
- AI image generation is powered by OpenAI DALL-E, proxied through the backend. The client sends a text prompt to the backend, which forwards it to DALL-E and returns the generated image URL.
- Video clips are capped at 30 seconds. No client-side trimming editor is required — clips from the gallery that exceed 30s are simply rejected.
- The voice recording duration limit follows the WhatsApp standard of approximately 30 seconds for status voice notes.
- The existing Clean Architecture pattern (Domain/Data/Presentation layers) and `flutter_bloc` state management from `specs/004-status-updates` will be extended, not replaced.
- The "Show on Map" privacy option leverages an existing or planned location/map feature; if unavailable, it can be stubbed for future implementation.
- Font style cycling (the "Aa" button) rotates through a predefined set of 3-5 font families already available in the app's typography system.
