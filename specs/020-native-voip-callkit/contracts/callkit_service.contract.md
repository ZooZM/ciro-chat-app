# Contract: CallKitService (core/services/callkit_service.dart)

Thin wrapper over `flutter_callkit_incoming`. Best-effort; failures logged, never thrown (matches `CallAudioSessionService`). Used for **1:1 calls only**.

```dart
abstract interface class CallKitService {
  /// Show the native incoming-call UI (lock screen + Recents on iOS).
  /// [callId] is the correlation UUID shared with signaling/push payload.
  Future<void> showIncoming({
    required String callId,
    required String callerName,
    String? callerAvatarUrl,
    required bool isVideo,
  });

  /// Register an outgoing call as a native/system call session.
  Future<void> startOutgoing({
    required String callId,
    required String calleeName,
    required bool isVideo,
  });

  /// Mark a call connected (starts the system call timer / Recents duration).
  Future<void> setConnected(String callId);

  /// Dismiss the native call UI and end the system session (FR-VoIP-13).
  Future<void> endCall(String callId);

  /// End every active native call (used in logout/reset teardown, §V-A).
  Future<void> endAllCalls();

  /// Broadcast stream of native user actions. CallCubit subscribes and maps
  /// each to an existing action (accept/decline/end/mute).
  Stream<CallKitAction> get actions;
}

sealed class CallKitAction {
  final String callId;
  const CallKitAction(this.callId);
}
class CallKitAccept  extends CallKitAction { const CallKitAccept(super.id); }
class CallKitDecline extends CallKitAction { const CallKitDecline(super.id); }
class CallKitEnd     extends CallKitAction { const CallKitEnd(super.id); }
class CallKitMute    extends CallKitAction { final bool muted; const CallKitMute(super.id, this.muted); }
class CallKitTimeout extends CallKitAction { const CallKitTimeout(super.id); } // → missed
```

### Behavioural contract

1. `showIncoming` MUST render within the native incoming UI on a locked device (SC-001).
2. `actions` MUST emit exactly one terminal action per call (`Accept`/`Decline`/`End`/`Timeout`).
3. After `endCall`/`endAllCalls`, no native ongoing-call indicator remains (SC-007).
4. All methods are no-ops + `debugPrint` on platform failure; they MUST NOT throw into `CallCubit`.
5. Registered as `@lazySingleton`; `actions` subscription cancelled in teardown.
