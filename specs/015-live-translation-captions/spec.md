# Feature Specification: Live Translation Captions Overlay (Frontend MVP)

**Feature Branch**: `015-live-translation-captions`

**Created**: 2026-06-11

**Status**: Draft

**Input**: User description: "The backend has already implemented Phase 1 to Phase 4 (Stream lifecycle, multi-language tracking, overlapping rotation, and unsubscribe gateways). Begin the frontend implementation for Ciro Chat: a listener can enable live translation for a speaker in a video call and see translated captions overlaid on that speaker's video tile, updating live (interim) and settling into a corrected line (final), without affecting call performance (30/60 FPS video grid)."

## Clarifications

### Session 2026-06-11

- Q: Is there a cap on how many speakers a listener can have live translation enabled for at the same time? → A: No artificial limit — a listener may enable translation for any number of speakers concurrently; performance validation covers all tiles visible in the grid at once.
- Q: When the listener's connection drops and reconnects mid-call, what happens to translations that were active before the drop? → A: Auto-resume — the client automatically re-enables translation (using each speaker's last-selected target language) for every speaker that was active or pending beforehand, without requiring the listener to redo their toggles.
- Q: When a listener enables translation for a speaker for the first time, how is the initial target language chosen? → A: Defaults to the listener's app/device language (if supported), pre-selected so one tap enables translation immediately; the listener can change it afterward via the language picker.
- Q: When a caption packet arrives for a speaker the listener has translation enabled for, should the client check that the packet's language matches the listener's currently-selected target language before displaying it? → A: Yes, defensively filter — silently ignore packets whose language doesn't match the listener's current selection for that speaker.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Listener sees live translated captions on the speaker's tile (Priority: P1)

A participant in a video call who does not understand the speaker's language enables live translation for that speaker and chooses the language they want to read in. As the speaker talks, translated captions appear directly on top of (or immediately below) that speaker's video tile — updating word-by-word while they're still talking, then settling into a clean corrected line once the sentence ends.

**Why this priority**: This is the entire value proposition of the feature for end users. Without visible, correctly-attributed captions, nothing else matters. It is the smallest slice that can be demoed and validated against the already-implemented backend pipeline.

**Independent Test**: Join a call where the backend translation pipeline is already running for a speaker (per existing backend Phases 1-4). Enable translation for that speaker on the client. Verify translated captions appear over that speaker's tile, update live while they talk, and resolve into a stable final line when they finish a sentence.

**Acceptance Scenarios**:

1. **Given** a listener has enabled translation for a speaking participant, **When** that participant speaks, **Then** an in-progress (interim) caption appears on/near that participant's video tile and updates as more speech is recognized.
2. **Given** an interim caption is showing for a participant, **When** the speaker finishes a sentence, **Then** the interim caption is replaced by a final, corrected caption attached to the same participant.
3. **Given** translation is enabled for a participant, **When** that participant stops talking, **Then** the last final caption remains visible (does not disappear or flicker) until the next utterance begins.
4. **Given** multiple participants are visible in the call grid, **When** a caption update is received for one specific participant, **Then** the caption is shown only on that participant's tile and not on any other participant's tile.

---

### User Story 2 - Captions never disrupt call performance (Priority: P1)

While captions are actively streaming and updating multiple times per second, the rest of the call screen — video tiles, layout, controls — continues to render smoothly with no visible stutter, freezing, or dropped video frames.

**Why this priority**: A captioning feature that causes the video grid to stutter or freeze would make the call experience worse, undermining the core call functionality the captions are meant to enhance. This must hold from the first release, not be addressed later.

**Independent Test**: With translation enabled for one or more speakers and captions updating at the maximum expected rate, observe the call screen during sustained caption activity and confirm video playback remains smooth and the rest of the UI (other tiles, call controls) continues to respond normally.

**Acceptance Scenarios**:

1. **Given** captions are updating multiple times per second for an active speaker, **When** observing the video grid, **Then** other participants' video tiles continue to play back smoothly with no visible stutter.
2. **Given** captions are actively updating, **When** the user interacts with call controls (e.g., mute, switch view, open menus), **Then** the controls respond without noticeable delay.
3. **Given** a caption update arrives, **When** it is rendered, **Then** only the caption area for the relevant speaker's tile updates — the rest of the call screen does not visibly redraw.

---

### User Story 3 - Listener turns translation on or off per speaker (Priority: P2)

A listener can enable or disable live translation for an individual speaker at any point during the call, and pick which language they want captions in. Turning it off for one speaker does not affect captions for any other speaker, and does not interrupt the call itself.

**Why this priority**: Without a way to start/stop translation, User Story 1 cannot be triggered by a real user. This is the minimal control surface needed to make the feature usable end-to-end, building directly on Story 1.

**Independent Test**: During an active call, enable translation for Speaker A and confirm captions begin appearing for them. Disable translation for Speaker A and confirm captions stop appearing for them, while the call continues uninterrupted and any captions for Speaker B (if enabled) are unaffected.

**Acceptance Scenarios**:

1. **Given** a listener is in a call, **When** they enable translation for a specific speaker (defaulting to their app/device language as the target), **Then** captions for that speaker begin appearing within a few seconds.
2. **Given** a listener has translation enabled for a speaker, **When** they open the language picker and choose a different target language, **Then** subsequent captions for that speaker appear in the newly selected language.
3. **Given** translation is enabled for a speaker, **When** the listener disables it, **Then** captions for that speaker stop appearing and the call continues without interruption.
4. **Given** translation is enabled for two different speakers with different target languages, **When** the listener disables translation for one of them, **Then** captions for the other speaker continue unaffected.
5. **Given** a listener has translation enabled for a speaker, **When** that speaker leaves the call, **Then** the caption overlay for that speaker is removed along with their video tile.

---

### Edge Cases

- **Speaker's tile not currently visible**: When a caption arrives for a speaker whose video tile is off-screen (e.g., scrolled out of a large grid) or who has their camera off, the caption is not silently lost — it is shown via a reasonable fallback (e.g., a name-attributed caption strip) without disrupting the layout.
- **Long captions**: When a caption's text is too long to fit within or near the speaker's tile on one line, it wraps or truncates gracefully without growing the tile, covering controls, or shifting the layout of other tiles.
- **Out-of-order or stale updates**: When caption updates for the same utterance arrive out of order (e.g., an older interim arrives after a final), the display does not regress to showing older/stale text.
- **Rapid speaker switching**: When multiple enabled speakers talk in quick succession, each caption remains correctly attached to the participant who produced it, with no cross-attribution or "stuck" captions on the wrong tile.
- **Translation temporarily unavailable**: When the backend reports that translation is unavailable for a speaker (e.g., unsupported/undetected language or a service outage), the listener sees a clear, unobtrusive indication on that speaker's tile instead of a frozen or blank caption area, and the call audio/video is unaffected.
- **Listener reconnects mid-call**: If the listener's connection drops and reconnects, missed interim captions are not retransmitted; the caption area resumes showing new updates as they arrive without showing an error state. Any speaker for whom translation was active or pending before the drop is automatically re-enabled (using the listener's last-selected target language for that speaker) without requiring the listener to manually re-toggle it.
- **Leaving/ending the call**: When the listener leaves the call or the call ends, any active caption overlays are cleaned up along with the rest of the call UI.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The call screen MUST allow a listener to enable live translation for an individual speaking participant with a single action, defaulting the target language to the listener's app/device language (if supported), and MUST allow the listener to change the target language for that speaker afterward.
- **FR-002**: The call screen MUST allow a listener to disable live translation for a participant they previously enabled it for, independently of any other participant's translation state.
- **FR-003**: The system MUST receive and interpret incoming caption updates, determining for each update: which participant produced it, the caption text, whether it is an in-progress (interim) or finished (final) update, and the language it is in.
- **FR-004**: The system MUST display each caption update positioned on or immediately adjacent to the video tile of the participant who produced it, so the speaker and their caption are visually associated.
- **FR-005**: The system MUST update an in-progress caption in place as new interim text arrives for the same utterance, without creating duplicate or stacked caption lines for that utterance.
- **FR-006**: The system MUST replace an in-progress caption with the final corrected caption when the final update for that utterance arrives, and MUST keep that final caption visible until a new utterance begins.
- **FR-007**: The system MUST update only the caption display area for the affected participant's tile in response to a caption update, without causing the rest of the call screen (other video tiles, layout, controls) to re-render.
- **FR-008**: The system MUST continue to render video for all participants smoothly (no visible stutter or dropped frames attributable to caption updates) while one or more captions are actively updating.
- **FR-009**: The system MUST visually distinguish between an in-progress caption and a finished caption (e.g., styling that conveys "still being corrected" vs. "settled").
- **FR-010**: When a caption update is received for a participant whose video tile is not currently visible on screen, the system MUST still surface that caption to the listener via a fallback location rather than discarding it.
- **FR-011**: The system MUST handle long caption text by wrapping or truncating within a bounded display area, without resizing the underlying video tile or obscuring call controls.
- **FR-012**: The system MUST discard caption updates that are out of date relative to what is currently displayed for that utterance (e.g., an older in-progress update arriving after a newer or final one), so the displayed caption never regresses to older text. The system MUST also silently discard any caption update whose language does not match the listener's currently-selected target language for that speaker.
- **FR-013**: The system MUST remove a participant's caption overlay when that participant leaves the call or their video tile is removed from the call screen.
- **FR-014**: The system MUST clearly indicate to the listener, on the affected participant's tile, when translation becomes temporarily unavailable for that participant, without affecting the underlying call audio/video.
- **FR-015**: All caption-related state and updates introduced by this feature MUST be isolated from the call screen's overall state so that enabling, disabling, or updating captions does not trigger a rebuild of the video grid or other unrelated call UI.
- **FR-016**: When the listener's real-time connection drops and reconnects during a call, the system MUST automatically restore translation for every speaker whose translation was active or pending before the drop, using that speaker's last-selected target language, without requiring the listener to manually re-enable it.

### Key Entities *(include if feature involves data)*

- **Caption**: A unit of translated (or transcribed) text shown to a listener; has stability (in-progress vs. finished), the text content, the language it's in, and is grouped into one displayed line per utterance.
- **Speaker Attribution**: The link between a caption and the participant/video tile that produced the underlying speech; used to route each caption to the correct on-screen location.
- **Translation Toggle**: A listener's per-speaker choice of whether translation is on or off and which target language is selected; independent per speaker and per listener.
- **Caption Display Region**: The on-screen area associated with a participant's video tile (or a fallback location) where that participant's current caption is rendered.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A translated in-progress caption appears on the correct speaker's tile within 1 second of that speaker starting to talk, for at least 95% of utterances under normal network conditions.
- **SC-002**: A finished caption replaces the in-progress caption within 2 seconds of the speaker completing a sentence, for at least 95% of utterances.
- **SC-003**: During sustained caption activity (multiple updates per second, across however many speakers the listener has translation enabled for — up to all tiles visible in the grid), the video grid maintains smooth playback (30+ FPS, target 60 FPS) for 100% of observed sessions, with zero user-reported stutter tied to caption updates.
- **SC-004**: 100% of displayed captions are visually attached to the correct speaking participant's tile, with no cross-attribution observed across at least 50 consecutive utterances in a multi-participant call.
- **SC-005**: A listener can enable translation for a speaker and see their first caption within 5 seconds, in at least 95% of attempts.
- **SC-006**: Disabling translation for a speaker removes their captions within 1 second and does not interrupt the ongoing call for any participant.
- **SC-007**: 0% of caption updates cause a visible re-render/flicker of video tiles or controls outside the affected speaker's caption area.

## Assumptions

- **Backend contract is the source of truth**: The frontend consumes the caption updates and subscribe/unsubscribe/change-language signaling exactly as already implemented and documented by the backend (Phases 1-4). Where the requesting stakeholder's example payload differs from the existing backend contract (e.g., field names, presence of a stable utterance/segment identifier, speaker display name), the existing backend contract is treated as authoritative; any additional display information not provided by the backend (such as a speaker's display name) is resolved client-side from data the call screen already has about its participants.
- **Single target language per listener per speaker (MVP)**: This MVP covers one active target language per listener per speaker at a time (matching backend Phases 1-4); a listener changing language mid-call for a given speaker is in scope. There is no cap on the number of *different* speakers a listener may have translation enabled for simultaneously — each (listener, speaker) pair is independent, matching the backend's per-speaker subscription model.
- **Premium credits / billing notifications are out of scope for this MVP**: Low-balance and exhaustion notifications are not covered by this slice and will be addressed once the corresponding backend billing phase is available; this MVP assumes translation access is otherwise permitted.
- **Existing call screen and video tiles**: This feature builds on the existing group/1:1 video call screen and its video tile components; it does not redesign the call layout, only adds a caption overlay and per-speaker translation controls to it.
- **Connectivity**: Listeners have a live connection to the call's real-time data channel for the duration of translation; brief reconnect gaps may cause missed interim captions, which is acceptable per the edge cases above.
- **Supported languages**: The set of selectable target languages matches whatever the backend currently supports/exposes; this feature does not introduce new language support. If the listener's app/device language (FR-001 default) is not in the supported set, the system falls back to a fixed configured default language (e.g., English) as the pre-selected target.
