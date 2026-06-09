# Data Model: Screen Sharing in Calls (011)

No persistent storage entities are introduced. All state is in-memory on the
client (held in `CallActive`) plus a single ephemeral key in Redis on the
backend.

---

## Client: `CallActive` state extensions

```dart
class CallActive extends CallState {
  // ── existing fields ──
  final String livekitToken;
  final String livekitUrl;
  final String contactName;
  final bool   isVideo;
  final bool   isGroupCall;
  final String chatRoomId;
  final List<CallParticipant> participants;
  final RecordingState recordingState;

  // ── NEW: screen-share fields ──

  /// True when THIS device is currently publishing a screen-share video track.
  final bool isLocallySharingScreen;

  /// Reflects the audio toggle the user picked for the current local share.
  /// Meaningful only when [isLocallySharingScreen] is true.
  final bool localShareIncludesAudio;

  /// userId of the participant whose share is currently visible in the call.
  /// Empty string ('') means no one is sharing. Mirrors the backend Redis key.
  final String activeSharerUserId;

  /// Display name of the active sharer (for SnackBar text and tile label).
  final String activeSharerName;

  /// True if the active sharer published a screen-share-audio track.
  final bool activeSharerHasAudio;

  /// Per-receiver mute set: each entry is the userId of a sharer whose audio
  /// THIS client has muted locally. Local UI state only — never broadcast,
  /// never persisted, cleared when the share ends.
  final Set<String> mutedScreenAudioBySharerId;
}
```

**Equality**: `Set<String>` participates in `Equatable`'s `props` via
`UnmodifiableSetView` — when the set's contents change, `bloc_test` sees a new
state and rebuilds.

---

## Client: `CallScreenShareConflict` (transient side-event)

Not a state — emitted via a separate `Stream<CallSideEvent>` from `CallCubit`
that the UI listens to with `BlocListener`. The single field is the conflicting
sharer's display name; the UI shows `ScaffoldMessenger.of(context).showSnackBar`
with the message:

> **{name} is already sharing. Ask them to stop first.**

```dart
sealed class CallSideEvent {}
class CallScreenShareConflict extends CallSideEvent {
  final String activeSharerName;
  const CallScreenShareConflict(this.activeSharerName);
}
class CallScreenShareDenied extends CallSideEvent {
  const CallScreenShareDenied();
}
```

---

## Client: state transitions

```
                              (no one sharing)
                              activeSharerUserId == ''
                              isLocallySharingScreen == false
                                       │
              ┌────────────────────────┼──────────────────────────┐
              │                        │                          │
              ▼                        ▼                          ▼
   I tap share, sheet,    Someone else taps        I tap share but
   accept, OS grants:     share, backend           someone else is sharing:
   isLocallySharingScreen lock falls to them:      emit CallScreenShareConflict
   = true                 activeSharerUserId       (state unchanged)
   localShareIncludesAudio = otherUserId
   = chosen value         activeSharerName = ...
                          activeSharerHasAudio = ...
              │                        │
              ▼                        ▼
       (I stop OR I leave)       (they stop OR they leave)
              │                        │
              └────────────┬───────────┘
                           ▼
                  back to (no one sharing)
```

The Set<String> `mutedScreenAudioBySharerId` is entirely local — entries are
added on user mute-tap and removed on unmute-tap; the entire set is cleared
when a share session ends (so a re-share by the same person starts unmuted).

---

## Backend: Redis key (ephemeral)

| Key | Type | Value | TTL |
|---|---|---|---|
| `screenshare:active:{chatRoomId}` | string | `{userId}` of the current sharer | 6 hours (longer than any realistic call; auto-cleaned when room is destroyed) |

**Single-sharer enforcement**:
```ts
// In chat.gateway.ts:
// 1. SET NX (set-if-not-exists) to atomically grab the lock.
// 2. If SET NX returns 0, the key already exists with another userId → reject.
// 3. On client emitting isSharing=false, DEL the key.
// 4. On user disconnect from the call (existing leaveGroupCall / leaveCall flow), DEL the key as cleanup.
```

This guarantees that under concurrent taps from N clients, exactly one wins;
all others receive `screenShareRejected` and the UI shows the SnackBar.

---

## New exception (Flutter)

```dart
// lib/core/error/failures.dart
class ScreenShareDeniedFailure extends Failure {
  const ScreenShareDeniedFailure([super.message = 'Screen-share permission denied']);
}
```

Thrown by `LivekitVideoCallRepositoryImpl.setScreenShareEnabled` when the
OS-level picker returns denied/dismissed. Caught in `CallCubit` and converted
to a `CallScreenShareDenied` side-event.

---

## Existing entities unchanged

- `Room` (LiveKit) — same instance, additional track publications.
- `CallParticipant` — unchanged.
- `SocketService` — gains two new methods (`onScreenShareStateChanged`,
  `emitScreenShareStateChanged`) but its existing API is unchanged.
- `AuthLocalDataSource`, all message-related types — unaffected.
