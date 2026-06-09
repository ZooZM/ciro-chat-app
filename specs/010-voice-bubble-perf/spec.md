# Feature Specification: Voice-Message Waveform Stability (No Rebuild on New Message)

**Feature Branch**: `010-voice-bubble-perf`
**Created**: 2026-05-19
**Status**: Draft
**Input**: User description: "when i send a new message all recording waves rebuilding i need build it in first time only like whatsApp"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Voice waveforms render once and stay stable (Priority: P1)

A user is viewing a conversation that contains one or more voice messages. Each voice message displays a visual waveform of its audio. Other activity in the conversation (a new text message arriving, sending a new message, the typing indicator changing, scrolling, etc.) MUST NOT cause any of the already-rendered voice waveforms to re-compute or visibly re-draw. The waveform geometry for a given voice message is computed once when that message first appears on screen and is reused for the lifetime of that message bubble.

**Why this priority**: Today, every new message arriving in the conversation causes every visible voice waveform to be rebuilt from scratch. On lower-end devices this is visible as a flicker; on all devices it wastes CPU and battery. Users compare the experience unfavorably with mainstream messengers (WhatsApp, Telegram), where waveforms are clearly cached and stable.

**Independent Test**: Open a conversation containing at least three voice messages. Have another user send you ten text messages in quick succession. Observe that the voice waveforms remain perfectly stable — no flicker, no re-draw, no CPU spike — while only the new text bubbles appear at the bottom.

**Acceptance Scenarios**:

1. **Given** a conversation with three voice messages visible on screen, **When** a new text message arrives in the conversation, **Then** none of the three voice waveforms re-compute or re-draw; only the new text bubble appears.
2. **Given** a conversation with multiple voice messages visible, **When** the user starts typing (causing the typing indicator and input bar height to change), **Then** none of the visible voice waveforms re-compute or re-draw.
3. **Given** a voice message has been visible for some time with its waveform rendered, **When** the user scrolls it off screen and then scrolls it back into view, **Then** the waveform appears immediately (using cached geometry) without re-computing waveform samples.
4. **Given** a voice message is playing, **When** the playback progress indicator advances along the waveform, **Then** only the progress indicator updates; the underlying waveform geometry is NOT re-drawn from scratch on each progress tick.
5. **Given** a brand-new voice message is delivered to the user, **When** the message first appears in the list, **Then** the waveform IS computed for the first time and is then cached for the message's lifetime.

---

### User Story 2 - Playback state changes do not destroy waveform cache (Priority: P2)

Tapping play or pause on a voice message MUST NOT cause the waveform geometry to be re-computed. Playback is a layer above the waveform; the waveform itself is a static visual property of the message, computed once and never re-computed for the lifetime of that bubble in the message list.

**Why this priority**: Without this rule, every play/pause tap would re-trigger expensive waveform extraction and degrade the playback experience.

**Independent Test**: Tap play on a voice message; then tap pause; then tap play again. Confirm that the waveform geometry is computed exactly once (instrument or visual flicker test); only the progress indicator and play/pause icon update.

**Acceptance Scenarios**:

1. **Given** a voice message with its waveform already rendered, **When** the user taps the play button, **Then** the waveform geometry is NOT re-computed; the audio begins playing and the progress indicator starts advancing.
2. **Given** a voice message is currently playing, **When** the user taps pause, **Then** the waveform geometry is NOT re-computed; only the progress indicator and play/pause icon update.
3. **Given** a voice message has completed playback, **When** the user taps play again to listen a second time, **Then** the waveform geometry is NOT re-computed; playback resumes from the start.

---

### Edge Cases

- The user receives a voice message that was sent without precomputed waveform data (older message, format mismatch): the receiving device computes the waveform once on first display, caches it for the bubble's lifetime, and uses the cached geometry from then on. If the user closes and reopens the conversation, the device can compute again (no requirement to persist across app restarts), but MUST NOT recompute repeatedly within one conversation session.
- The voice message is in a "pending upload" state (sender side, before the recording is fully uploaded): the bubble may show a placeholder waveform that resolves to the final waveform when upload completes. After that resolution, no further recomputation occurs.
- Very long voice messages (multi-minute): waveform computation still happens exactly once on first display. If first-display computation is slow, the bubble may show a loading state, but it MUST NOT block other bubbles from rendering or other conversation activity.
- The user scrolls quickly through a conversation with many voice messages: each waveform is computed at most once and reused thereafter for that bubble.
- A voice message is deleted by the user: its cache entry is released.
- The conversation contains many voice messages (10+): memory used by cached waveform geometry stays bounded — older off-screen entries can be released if memory pressure occurs, but if so, they MUST be recomputable on demand without causing visible jitter for currently-visible bubbles.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A voice message's waveform geometry MUST be computed at most once per occurrence of that message in the message list, on first display.
- **FR-002**: New messages arriving in the conversation (any type — text, image, video, voice, system) MUST NOT cause any other already-visible voice message's waveform to be re-computed or re-drawn.
- **FR-003**: Changes to the input bar (typing, expanding, recording-in-progress indicator, attachment preview) MUST NOT cause any visible voice waveform to be re-computed or re-drawn.
- **FR-004**: Scrolling, focus changes, and other view-level events MUST NOT cause already-rendered voice waveforms to be re-computed; the geometry is reused as long as the bubble is mounted in memory.
- **FR-005**: Voice-message playback events (play, pause, seek, complete) MUST NOT cause the waveform geometry to be re-computed; only the playback-progress overlay over the waveform updates.
- **FR-006**: The visual appearance of voice waveforms after this feature MUST be unchanged compared to the existing implementation; only the rendering-stability behavior changes.
- **FR-007**: When a voice message bubble first becomes visible and its waveform has not yet been computed, the system MUST compute the waveform asynchronously and update the bubble when the waveform is ready, WITHOUT blocking the rest of the message list from rendering.
- **FR-008**: When a voice message bubble is scrolled off screen and then back into view within the same conversation session, the waveform MUST display immediately from cache without recomputation.
- **FR-009**: The system MUST handle voice messages that carry precomputed waveform sample data from the sender (the normal case) by using those samples directly, with no local waveform extraction.
- **FR-010**: The system MUST handle voice messages that arrive without precomputed waveform sample data (older messages, format mismatches) by extracting waveform samples from the audio file on first display, caching the result, and proceeding per FR-001 to FR-008.
- **FR-011**: This change MUST NOT regress the behavior of the active-recording waveform shown in the input bar while the user is recording a new voice message; the input-bar live waveform is a separate concern and its current behavior is preserved.
- **FR-012**: This change applies to voice message bubbles in both 1-to-1 chats and group chats.

### Key Entities *(include if feature involves data)*

- **Voice Message Waveform Geometry**: The visual rendering data (sample magnitudes / bar heights) used to draw the waveform for a single voice message. Computed once per bubble lifetime; reused on every paint after that.
- **Voice Message Bubble**: A single voice message displayed in the conversation. Owns its own waveform geometry instance.
- **Waveform Cache** (per conversation session): An in-memory mapping from voice-message identifier to its waveform geometry, scoped to the lifetime of the open conversation. Bounded to avoid unbounded memory growth.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across 30 consecutive new messages arriving in a conversation that contains 5 visible voice messages, the visible voice waveforms re-draw 0 times (verified by instrumentation or video capture).
- **SC-002**: First-display rendering of a newly arrived voice message's waveform completes within 300 ms on mid-range devices for messages up to 60 seconds in duration.
- **SC-003**: Frame rate during incoming-message bursts (10 messages within 2 seconds) into a conversation with voice messages stays at or above 55 fps on mid-range reference devices.
- **SC-004**: CPU time spent rendering voice waveforms when no voice message is being added or playback-state-changed is at most 5% of CPU time spent rendering the equivalent conversation with no voice messages, measured over a 10-second window with active message activity.
- **SC-005**: User-perceived "flicker" reports related to voice waveforms drop to 0 in post-release qualitative feedback / app reviews compared to a baseline of pre-release reports.

## Assumptions

- The system already extracts and persists waveform sample data on the sender side when a voice message is recorded; receivers normally consume that data directly. This feature reuses that data path.
- The conversation message list is virtualized: only bubbles in or near the viewport are mounted. The waveform cache is scoped to mounted bubbles within an open conversation; it does not need to persist beyond the conversation being closed.
- "Mid-range device" for SC-002 and SC-003 means a 2022-era Android phone with 4 GB RAM and a mid-tier SoC, or an iPhone SE 2nd generation; the team will agree on specific reference devices during planning.
- There is no business need to persist waveform geometry to disk; recomputing on next session-open is acceptable as long as in-session reuse is guaranteed.
- The visual appearance of voice waveforms is governed by the existing design system and is not changing as part of this feature.
- The in-progress recording waveform inside the input bar is intentionally out of scope; that animation must remain live and is rebuilt per design.
