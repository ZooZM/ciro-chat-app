# Phase 0 Research: Native VoIP CallKit Integration

All Technical Context unknowns are resolved below. Decisions are grounded in the existing codebase (feature 019 audio session, `CallCubit`, `voice_call_screen`, bottom-nav) and the package landscape.

## R1. Native call UI & call history mechanism

- **Decision**: Use `flutter_callkit_incoming` as a thin wrapper service (`CallKitService` in `core/services/`). On iOS it bridges to CallKit (`CXProvider`), giving the native incoming UI + Recents entry automatically. On Android it shows the package's full-screen incoming-call notification/activity. Drive it from `CallCubit` on incoming/outgoing/accept/reject/end.
- **Rationale**: Explicitly requested (FR-VoIP-01); de-facto standard for Flutter VoIP; integrates with FCM data pushes for wake-from-terminated (FR-VoIP-12). Avoids hand-writing platform channels for CallKit/ConnectionService.
- **Alternatives considered**: `callkeep` (less maintained, heavier API); raw platform channels (high cost, reinvents the package); notification-only (fails lock-screen + Recents requirement).

## R2. Scope to 1:1 only (group stays in-app)

- **Decision**: `CallKitService.showIncoming/startOutgoing` is invoked **only** for 1:1 calls (`isGroupCall == false`). Group call paths in `CallCubit` (`onIncomingGroupCall`, `startGroupCall`) keep the existing in-app `flutter_ringtone_player` + in-app screens, and only write a history row.
- **Rationale**: Clarification Q3. CallKit/ConnectionService model a single remote party; group semantics are awkward and platform-limited.
- **Alternatives**: All-native (rejected — poor group fit); voice-only-native (rejected — user chose 1:1 voice+video native).

## R3. Background audio persistence (platform capabilities)

- **Decision**:
  - **iOS** `Info.plist`: extend existing `UIBackgroundModes` array (currently `location`) to add `audio` and `voip`.
  - **Android** `AndroidManifest.xml`: add `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE` (Android 14+), and `BLUETOOTH_CONNECT`; rely on `flutter_callkit_incoming`'s call-style foreground service while a call is active. Keep the existing screen-share foreground service intact.
- **Rationale**: FR-VoIP-03/14. `voip` mode + CallKit keeps the audio session alive when backgrounded on iOS; a call-type foreground service does the same on Android. The audio session is already `playAndRecord` (019), so audio routing keeps working in background.
- **Alternatives**: `audio` mode only on iOS (rejected — `voip` needed for PushKit-style wake + CallKit); a custom Android foreground service (rejected — the package already provides one).

## R4. Audio-route control model (route picker, not toggle)

- **Decision**: New `AudioRouteService` (`core/services/`) wrapping LiveKit `Hardware.instance`:
  - `Hardware.instance.audioOutputs` / `getAudioOutputs()` → available routes (earpiece, speaker, Bluetooth devices).
  - `Hardware.instance.selectAudioOutput(device)` to switch; `setSpeakerphoneOn(bool)` for the earpiece↔speaker fast path.
  - Listen to `Hardware.instance` device-change notifications (or LiveKit `onDeviceChange`) to react to Bluetooth connect/disconnect (FR-VoIP-09).
  - Expose the active route + available routes as a stream the call screens render. The speaker button opens `audio_route_picker_sheet.dart` (bottom sheet listing all routes, active one checked).
- **Rationale**: Clarification Q1 (picker). Reuses the same `Hardware.instance` already used in `voice_call_screen.dart:73` and `video_call_screen.dart:177`, so it sits on top of the existing audio session — **does not touch `CallAudioSessionService` config**, satisfying FR-VoIP-11. The existing session already sets `allowBluetooth`, so Bluetooth routes are available without re-configuring.
- **Alternatives**: Direct `audio_session`/AVAudioSession route override (rejected — would risk re-configuring the 019 session and bypassing LiveKit's track routing); simple boolean toggle (rejected per clarification).

## R5. Default route on connect

- **Decision**: In `AudioRouteService.applyDefaultForCall(isVideo)`: if a Bluetooth output is present, select it; else `setSpeakerphoneOn(isVideo)` — video → speaker, voice → earpiece. Replaces the current hardcoded `_isSpeakerOn` defaults in the call screens.
- **Rationale**: FR-VoIP-10 / clarification Q4. Matches phone conventions.
- **Alternatives**: Always earpiece / always speaker (rejected per clarification).

## R6. Noise-cancellation compatibility (the hard constraint)

- **Decision**: Routing is performed **only** via `Hardware.instance` output selection. `CallAudioConfig.captureOptions` (NS/EC/AGC on; voiceIsolation/typingNoiseDetection off) and `CallAudioSessionService`'s `voiceChat`/`playAndRecord`/`allowBluetooth` configuration are left untouched. `AudioRouteService` never calls `AudioSession.configure`. A regression test asserts capture options are unchanged after a route switch.
- **Rationale**: FR-VoIP-11 + Constraint. Output-device selection does not change capture-side WebRTC filters, so NS is preserved. The 019 interruption re-assert logic continues to own the session.
- **Alternatives**: Re-configuring the session per route (rejected — exactly the regression the constraint forbids).

## R7. In-app call history persistence

- **Decision**: New `call_history` sqflite table written by `CallCubit` at terminal transitions (answered→ended, missed, rejected, outgoing-no-answer) for **all** calls (1:1 + group). `CallHistoryLocalDataSource` exposes a `watchAll()`/stream + `search(query)`; `CallHistoryCubit` renders it. No OS call-log writes on either platform (clarification Q2 — avoids Android `WRITE_CALL_LOG`).
- **Rationale**: FR-VoIP-04/05/15, Constitution §III. Contact display (name, initials, avatar color) derived from existing contacts data.
- **Alternatives**: OS-native call log (rejected — sensitive permission + store policy); in-memory only (rejected — not durable/offline).

## R8. Wake-from-terminated (1:1)

- **Decision**: Reuse the existing FCM data-message path in `push_notification_service.dart`; on a `call`-type data push, the background handler calls `CallKitService.showIncoming(...)`. Accept/decline events from CallKit route into `CallCubit` (accept → join LiveKit room, decline → reject + history row). PushKit/VoIP-push provisioning is assumed available (spec Assumptions).
- **Rationale**: FR-VoIP-12; the app already has FCM + a background handler.
- **Alternatives**: Persistent socket only (rejected — unreliable when app killed, especially iOS).

## R9. Calls bottom-nav tab wiring

- **Decision**: The "Calls" tab already exists at index 3 in `chat_list_screen.dart` (`Icons.call_outlined`/`nav_calls`). Add an index-3 branch in `_buildBody` returning `const CallsHistoryScreen()`. No nav-bar item changes needed.
- **Rationale**: FR-VoIP-04; minimal, matches the existing Updates(1)/Map(2) pattern.
- **Alternatives**: Separate route via `go_router` (rejected — the screen is a tab body, consistent with Updates/Map).

## R10. CallKit ↔ in-app state synchronization

- **Decision**: `CallKitService` exposes a broadcast stream of native actions (accept/decline/end/mute/timeout). `CallCubit` subscribes and maps them to existing actions (`acceptCall`, `rejectCall`, `endCall`). When the app ends a call in-app, `CallCubit` calls `CallKitService.endCall(id)` to dismiss the native UI — preventing ghost calls (FR-VoIP-13). A single `callId` (UUID per call) is the correlation key, generated by the caller and carried in the call signaling/push payload.
- **Rationale**: FR-VoIP-06/13; avoids double UIs and stuck sessions.
- **Alternatives**: Polling native state (rejected — racy).

## Resolved unknowns summary

| Unknown | Resolution |
|---|---|
| Native UI package | `flutter_callkit_incoming` |
| Group calls | In-app only; history row written |
| iOS background | `UIBackgroundModes += audio, voip` |
| Android background | call-type foreground service + FOREGROUND_SERVICE(_MICROPHONE), BLUETOOTH_CONNECT |
| Routing API | LiveKit `Hardware.instance` (outputs + select + device-change) |
| Default route | BT > (video→speaker / voice→earpiece) |
| NS safety | route via Hardware only; never re-configure 019 session |
| History store | new `call_history` sqflite table; no OS call log |
| Wake when killed | FCM data push → `CallKitService.showIncoming` |
| Tab wiring | `_buildBody` index 3 → `CallsHistoryScreen` |
