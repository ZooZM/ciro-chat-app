# Feature Specification: Call Audio Enhancement & Noise Cancellation (Frontend)

**Feature Branch**: `019-call-audio-enhancement`

**Created**: 2026-06-25

**Status**: Draft

**Input**: User description: "Add native Audio Enhancement and Noise Cancellation to improve Google STT translation accuracy and call clarity using a zero-cost, zero-latency approach, avoiding aggressive third-party AI SDKs that might over-filter and degrade STT accuracy. Configure the native OS audio session for voice communication before joining the call, enable the built-in WebRTC filters (noise suppression, echo cancellation, automatic gain control) on the local audio track, and rely strictly on WebRTC + OS-level hardware cancellation with no paid third-party SDKs."

## Clarifications

### Session 2026-06-25

- Q: Should the built-in OS AI voice-isolation modes (e.g., Apple Voice Isolation, enabled by default in the SDK) and typing-noise detection be enabled, disabled, or runtime-configurable? → A: Explicitly disable OS AI voice isolation and typing-noise detection; rely only on standard WebRTC noise suppression, echo cancellation, and AGC to strictly protect STT accuracy.
- Q: What measurable threshold defines "translation accuracy remains high / no lower" (SC-002)? → A: Enhancement-on Word Error Rate (WER) must be within ≤2% absolute of enhancement-off on a fixed phrase set in a quiet room.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clear, noise-free speech for accurate translation (Priority: P1)

A user joins a real-time call from a noisy environment (café, street, room with an echo). Without taking any manual action, their captured audio has background noise, echo, and volume swings suppressed before it is sent to the other participants and the translation pipeline. As a result, other participants hear them clearly and the live-translation captions transcribe and translate their speech accurately.

**Why this priority**: This is the entire value of the feature. Poor input audio is the largest controllable factor degrading both call clarity and speech-to-text (STT) translation accuracy. Without it, the translation feature (015) produces garbled captions and participants struggle to hear each other. It is the smallest slice that delivers measurable value.

**Independent Test**: Join a call from a noisy/echo-prone environment with audio enhancement enabled and speak normally. Verify other participants hear clean speech and that translated captions accurately reflect what was said, with no manual configuration required.

**Acceptance Scenarios**:

1. **Given** a user is about to join a call, **When** the call connection is established, **Then** the device's audio session has already been configured for voice communication (not media playback) before the local microphone track is published.
2. **Given** the user is in a noisy room, **When** they speak, **Then** other participants hear their voice with steady-state background noise audibly suppressed.
3. **Given** the user is using the device speaker (not headphones), **When** remote audio plays while they speak, **Then** echo of the remote audio is cancelled and is not re-transmitted back to the call.
4. **Given** the user speaks softly and then loudly, **When** their audio is captured, **Then** the perceived loudness is automatically leveled so they remain audible without clipping.

---

### User Story 2 - Enhancement preserves translation fidelity (no over-filtering) (Priority: P1)

A bilingual user speaks in a language rich in soft consonants and sibilants. The audio enhancement removes noise and echo but does not aggressively strip speech detail, so the STT/translation engine still receives intelligible speech and does not drop consonants or whole words.

**Why this priority**: Aggressive AI denoising can improve perceived clarity to a human ear while *degrading* machine transcription by removing high-frequency speech components. Avoiding this regression is a hard constraint of the feature — clarity must not come at the cost of translation accuracy.

**Independent Test**: Record/transcribe a standardized phrase set spoken in a controlled quiet environment with enhancement on vs. off, and compare translation accuracy. Verify enhancement does not reduce word/consonant accuracy.

**Acceptance Scenarios**:

1. **Given** enhancement is enabled, **When** a user speaks a phrase with soft consonants in a quiet room, **Then** STT translation accuracy is no worse than with enhancement disabled.
2. **Given** the feature is enabled, **When** the audio pipeline is inspected, **Then** only built-in WebRTC filters and OS-level hardware cancellation are in use — no third-party AI/paid denoising SDK is present in the path.

---

### User Story 3 - Consistent behavior across iOS and Android (Priority: P2)

A user on iOS and a user on Android join the same call. Both have the OS audio session configured for voice communication and the same set of WebRTC filters applied, so neither platform exhibits echo, clipping, or unsuppressed background noise relative to the other.

**Why this priority**: The product targets both platforms; an enhancement that only works on one platform leaves half the user base with degraded clarity and translation quality. It builds on US1 but is a follow-on rather than the minimal slice.

**Independent Test**: Run the same noisy-environment test on an iOS device and an Android device and confirm equivalent suppression behavior on both.

**Acceptance Scenarios**:

1. **Given** an iOS device, **When** a call starts, **Then** the audio session is configured in a voice-communication mode.
2. **Given** an Android device, **When** a call starts, **Then** the audio session uses a voice-communication usage profile.
3. **Given** either platform, **When** the local audio track is published, **Then** noise suppression, echo cancellation, and automatic gain control are all enabled.

---

### Edge Cases

- **Headphones / Bluetooth headset connected**: Hardware echo cancellation may be unnecessary; the WebRTC software filters must remain enabled and must not introduce artifacts when the OS already handles echo. Behavior should remain stable across mid-call audio-route changes (wired → speaker → Bluetooth).
- **Interruption by another app**: If a phone call, voice assistant, or another audio app interrupts and the OS audio session is deactivated and later reactivated, the voice-communication configuration must be restored when the call resumes.
- **Permission not yet granted**: If microphone permission is granted late or revoked mid-call, audio-session configuration and filter application must not crash; enhancement applies once capture resumes.
- **Switching between call types** (1:1, group, avatar, screen-share-with-audio): Enhancement settings must apply consistently regardless of call surface that publishes a local microphone track.
- **Device without hardware AEC/NS**: When the OS provides no hardware cancellation, the WebRTC software filters alone must still be applied and active.
- **Reconnect mid-call**: After a connection drop and reconnect, republished audio tracks must retain the same enhancement options.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-Audio-01 (OS Audio Session)**: Before connecting to the call room, the app MUST configure the native OS audio session optimized for voice communication — on iOS using a voice-chat audio session mode (`AVAudioSessionMode.voiceChat`), and on Android using a voice-communication audio usage profile (`AndroidAudioUsage.voiceCommunication`).
- **FR-Audio-02 (WebRTC Filters)**: When publishing the local audio track / connecting to the call room, the app MUST explicitly enable the built-in WebRTC filters by passing audio-capture options with `noiseSuppression: true`, `echoCancellation: true`, and `autoGainControl: true`.
- **FR-Audio-02a (No aggressive AI gating)**: The app MUST explicitly **disable** the OS-level AI voice-isolation mode (e.g., Apple Voice Isolation) and typing-noise detection (i.e., `voiceIsolation: false`, `typingNoiseDetection: false`), even though they are enabled by default in the SDK. Only the standard WebRTC noise suppression, echo cancellation, and AGC from FR-Audio-02 may filter the captured audio, so high-frequency consonants are preserved for STT.
- **FR-Audio-03 (Zero-Cost Constraint)**: The implementation MUST rely strictly on WebRTC and OS-level hardware cancellation. No third-party paid or AI denoising SDK (e.g., Krisp) may be integrated into the audio path.
- **FR-Audio-04 (Zero-Latency Constraint)**: The enhancement MUST add no perceptible additional latency to the call beyond what the built-in WebRTC/OS processing already incurs — no extra buffering or external processing stage is introduced.
- **FR-Audio-05 (Applies to all microphone-publishing surfaces)**: The audio-session configuration and capture options MUST be applied consistently on every call surface that publishes a local microphone track (1:1, group, avatar, and screen-share-with-audio calls).
- **FR-Audio-06 (Resilience to audio-route & interruption changes)**: The voice-communication audio-session configuration MUST be (re)established when the call starts, when the session is reactivated after an OS interruption, and when the call reconnects after a network drop.
- **FR-Audio-07 (No manual setup)**: Enhancement MUST be applied automatically when a call starts; it MUST NOT require the user to toggle a setting for it to take effect.

### Key Entities

- **Call audio session configuration**: The platform-level voice-communication profile applied to the device before joining a call (mode/usage, category). Lifecycle is bound to the call: established on join, restored on interruption/reconnect.
- **Local audio capture options**: The set of WebRTC filter flags attached to the local microphone track at publish time — noise suppression, echo cancellation, and automatic gain control enabled; OS AI voice isolation and typing-noise detection explicitly disabled (FR-Audio-02a).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With enhancement enabled, the microphone captures audio with echo cancellation, background-noise suppression, and automatic gain control audibly applied, verified by listener evaluation in a noisy/echo-prone environment.
- **SC-002**: On a fixed, standardized phrase set spoken in a quiet room, the **Word Error Rate (WER)** of the resulting transcription with enhancement enabled is within **≤2% absolute** of the WER with enhancement disabled — i.e., no meaningful drop in word/consonant recognition attributable to over-aggressive filtering.
- **SC-003**: 100% of calls that publish a local microphone track have the voice-communication audio session configured **before** the local track is published.
- **SC-004**: In a controlled echo scenario (device speaker + active remote audio), perceivable echo returned to the call is eliminated, as confirmed by participant evaluation.
- **SC-005**: No third-party paid/AI denoising SDK appears in the audio path; enhancement is delivered solely via built-in WebRTC filters and OS-level cancellation (verifiable by dependency/audit review).
- **SC-006**: Enhancement adds no perceptible end-to-end audio latency relative to a baseline call without the explicit configuration.
- **SC-007**: Behavior is equivalent across iOS and Android for the same noisy-environment test (no platform shows unsuppressed noise, clipping, or echo the other does not).

## Assumptions

- The app already uses a WebRTC-based real-time media stack (LiveKit) for calls; this feature configures that stack rather than introducing a new media transport.
- The Google STT-based live translation pipeline (feature 015) already exists and consumes the published call audio; this feature improves the *input* quality feeding that pipeline and does not change the translation/caption UI.
- Microphone permission handling already exists in the call flow; this feature assumes capture is available when configuring options.
- "Zero-cost" refers to no paid third-party SDK and no additional licensing — only the already-bundled WebRTC and OS-native capabilities are used.
- A platform audio-session capability (e.g., an `audio_session`-style mechanism) is available to set voice-communication mode/usage on both iOS and Android.
- Out of scope: a user-facing toggle/settings UI for enhancement, custom/AI noise models, recording-side post-processing, and any backend STT/translation changes.
