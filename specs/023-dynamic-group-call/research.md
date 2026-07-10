# Research: Dynamic Group Call Screen

**Feature**: 023-dynamic-group-call  
**Date**: 2026-07-09  

## Research Tasks

### RT-01: Existing Group Call Layout Patterns

**Decision**: Re-use the 2-column grid pattern from `group_call_screen.dart` (lines 677–743), but adapt it for mock-data-only usage without LiveKit or real `RemoteParticipant` objects.

**Rationale**: The existing `_buildCompactGrid` and `_buildScrollableGrid` methods in `group_call_screen.dart` already implement a 2-column layout with centered-odd-tile handling. The new dynamic screen will replicate this visual structure using a mock `CallParticipant` model instead of LiveKit's `RemoteParticipant`.

**Alternatives considered**:
- `GridView.builder` with `crossAxisCount: 2` — simpler but lacks the centered-odd-tile behavior needed for 3 and 5 participants. Rejected.
- Flutter `Wrap` widget — does not guarantee even column distribution. Rejected.

### RT-02: P2P Layout Re-use

**Decision**: For 2-participant mode, replicate the visual layout of `video_call_screen.dart` (full-screen remote + floating PIP local) but with mock containers instead of `VideoTrackRenderer`.

**Rationale**: The user explicitly requested re-using the 1-on-1 call layout. The existing `VideoCallScreen` uses a `Stack` with `Positioned.fill` for the remote feed and a small draggable `Positioned` widget for the local PIP. This pattern is straightforward to reproduce with mock containers.

**Alternatives considered**:
- Importing and wrapping `VideoCallScreen` itself — rejected because it depends on LiveKit, which violates the "no live calling logic" constraint.

### RT-03: Participant Cell Design

**Decision**: Create a new `_MockParticipantTile` widget modeled after the existing `_ParticipantTile` (lines 1230–1378 in `group_call_screen.dart`) but without LiveKit dependencies. The tile will show either a colored container with a centered avatar image or a placeholder "video" container.

**Rationale**: The existing `_ParticipantTile` uses `VideoTrack`, `ValueListenable<Caption?>`, and `TranslationStatus` — all LiveKit-specific types. The mock version replaces these with simple boolean flags (`isVideoOn`, `isMuted`, `isSpeaking`).

**Alternatives considered**:
- Making `_ParticipantTile` generic enough to work with both LiveKit and mock data — rejected as it would couple the mock UI to LiveKit imports unnecessarily.

### RT-04: State Management for Layout Switching

**Decision**: Use a simple `StatefulWidget` with `int _participantCount` and `List<CallParticipant> _mockParticipants`. No Cubit/Bloc needed.

**Rationale**: The spec explicitly says "SIMULATE DYNAMIC STATE" with a simple state variable. Adding a full Cubit would be over-engineering for a mock-data-only UI screen. The Constitution (Section II) permits `StatefulWidget` for simple toggles.

**Alternatives considered**:
- Using a `GroupCallDemoCubit` — rejected as unnecessarily complex for a mock screen with no business logic.

### RT-05: Translation Key Reuse

**Decision**: Reuse existing keys (`call_you`, `call_waiting_to_join`, `call_participants_count`) where they match, and add only new keys specific to the dynamic group call screen.

**Rationale**: The translation files already contain `call_you`, `call_waiting_others`, `call_waiting_to_join`, and `call_participants_count`. No need to duplicate.

**Alternatives considered**: None — key reuse is the obvious approach.

### RT-06: Routing

**Decision**: Add a new route `dynamicGroupCall` (path `/dynamic_group_call`) in `AppRouterName` and `AppRouter`. The screen takes no parameters since all data is mock.

**Rationale**: The screen is self-contained with mock data. No `roomId` or other external parameters needed.

**Alternatives considered**:
- Accepting a `participantCount` query parameter — rejected because the screen should manage this internally via state variable.
