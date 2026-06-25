# Phase 1 Data Model: Call Audio Enhancement

This feature persists **no data** (no SQLite/SharedPreferences/SecureStorage). The
"entities" are ephemeral, in-memory configuration value objects supplied to the LiveKit
SDK at call-connect time. They are documented here for completeness.

## Value Object: Local Audio Capture Options

The WebRTC filter flags attached to the local microphone track at publish time.
Backed by `livekit_client`'s `AudioCaptureOptions`.

| Field | Value | Source / Rationale |
|-------|-------|--------------------|
| `noiseSuppression` | `true` | FR-Audio-02 |
| `echoCancellation` | `true` | FR-Audio-02 |
| `autoGainControl` | `true` | FR-Audio-02 |
| `voiceIsolation` | `false` | SC-002 — disable Apple AI voice isolation to avoid over-filtering / dropped consonants (R1) |
| `typingNoiseDetection` | `false` | SC-002 — avoid extra aggressive gating of speech |

**Validation rule**: the three FR-Audio-02 flags MUST all be `true`; `voiceIsolation`
MUST be `false`. Enforced by a unit test on `CallAudioConfig`.

**Lifecycle**: immutable `const`; constructed once and reused across all call surfaces.

## Value Object: Voice-Communication Audio Session Configuration

The platform-level audio session profile applied before joining a room. Backed by the
`audio_session` package's `AudioSessionConfiguration`.

| Platform | Field | Value |
|----------|-------|-------|
| iOS | category | `playAndRecord` |
| iOS | mode | `voiceChat` (FR-Audio-01) |
| iOS | options | allow Bluetooth / default-to-speaker as appropriate for call routing |
| Android | usage | `voiceCommunication` (FR-Audio-01) |
| Android | content type | `speech` |

**State transitions** (managed by `CallAudioSessionService`):

```
idle ──configureForCall()──▶ active (voice-comm)
active ──OS interruption begins──▶ interrupted
interrupted ──interruption ends──▶ active (re-asserted)
active ──call ends / deactivate()──▶ idle
```

**Lifecycle**: activated before `room.connect()`; re-asserted on interruption-end and on
reconnect; deactivated on call teardown (Constitution §V).

## Relationships

```
CallAudioConfig
  ├── exposes: AudioCaptureOptions (const)        → RoomOptions.defaultAudioCaptureOptions
  └── exposes: RoomOptions factory                → Room(roomOptions: …) at all 4 connect sites

CallAudioSessionService (core singleton)
  ├── configureForCall()  → audio_session AudioSessionConfiguration   (before connect)
  ├── interruptionSub     → re-assert on interruption end
  └── deactivate()        → on call teardown
```

No database schema, no migrations.
