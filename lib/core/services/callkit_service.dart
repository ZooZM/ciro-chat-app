import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:injectable/injectable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Native action stream — CallCubit consumes these once and maps to its actions.
// ─────────────────────────────────────────────────────────────────────────────

sealed class CallKitAction {
  final String callId;
  const CallKitAction(this.callId);
}

class CallKitAccept extends CallKitAction {
  const CallKitAccept(super.callId);
}

class CallKitDecline extends CallKitAction {
  const CallKitDecline(super.callId);
}

class CallKitEnd extends CallKitAction {
  const CallKitEnd(super.callId);
}

class CallKitMute extends CallKitAction {
  final bool muted;
  const CallKitMute(super.callId, this.muted);
}

class CallKitTimeout extends CallKitAction {
  const CallKitTimeout(super.callId);
}

abstract class CallKitService {
  Future<void> showIncoming({
    required String callId,
    required String callerName,
    String? callerAvatarUrl,
    required bool isVideo,
  });

  Future<void> startOutgoing({
    required String callId,
    required String calleeName,
    required bool isVideo,
  });

  Future<void> setConnected(String callId);
  Future<void> endCall(String callId);
  Future<void> endAllCalls();

  /// Mirrors an in-app mute toggle onto the native call session (C1, bidirectional).
  Future<void> reportMute(String callId, bool muted);

  Stream<CallKitAction> get actions;
}

/// Wraps `flutter_callkit_incoming` for native 1:1 call presentation
/// (FR-VoIP-01/02/12/13). Best-effort: every call is wrapped so a platform
/// failure logs and is swallowed — it MUST NOT crash or block a call
/// (Constitution §VII, mirrors [CallAudioSessionService]).
@LazySingleton(as: CallKitService)
class CallKitServiceImpl implements CallKitService {
  final _controller = StreamController<CallKitAction>.broadcast();
  StreamSubscription<CallEvent?>? _eventSub;

  /// callIds for which a native incoming UI is currently shown — guards against
  /// duplicate/retried signals stacking two screens (E2 — FR idempotency).
  final Set<String> _activeIncoming = {};

  /// CallKit is non-functional on the iOS Simulator: `showCallkitIncoming`
  /// immediately fires a spurious `CallEventActionCallDecline` (no user action),
  /// which would reject the call and tear it down on the caller too. Gate all
  /// native calls behind "is this a physical device" so the app falls back to
  /// its in-app call UI on the simulator. Resolved once, cached.
  late final Future<bool> _callKitSupported = _resolveCallKitSupported();

  Future<bool> _resolveCallKitSupported() async {
    // Android emulators handle CallKit fine; only iOS simulators are broken.
    if (!Platform.isIOS) return true;
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      if (!info.isPhysicalDevice) {
        debugPrint('[CallKitService] iOS Simulator detected — CallKit disabled, using in-app UI.');
      }
      return info.isPhysicalDevice;
    } catch (e) {
      debugPrint('[CallKitService] device check failed, assuming CallKit supported: $e');
      return true;
    }
  }

  CallKitServiceImpl() {
    _bindEvents();
  }

  @override
  Stream<CallKitAction> get actions => _controller.stream;

  void _bindEvents() {
    _eventSub = FlutterCallkitIncoming.onEvent.listen((event) {
      debugPrint('[CallKitService] onEvent ${event.runtimeType}');
      switch (event) {
        case CallEventActionCallAccept(:final callKitParams):
          _controller.add(CallKitAccept(callKitParams.id));
          break;
        case CallEventActionCallDecline(:final callKitParams):
          _activeIncoming.remove(callKitParams.id);
          _controller.add(CallKitDecline(callKitParams.id));
          break;
        case CallEventActionCallEnded(:final callKitParams):
          _activeIncoming.remove(callKitParams.id);
          _controller.add(CallKitEnd(callKitParams.id));
          break;
        case CallEventActionCallTimeout(:final id):
          _activeIncoming.remove(id);
          _controller.add(CallKitTimeout(id));
          break;
        case CallEventActionCallToggleMute(:final id, :final isMuted):
          _controller.add(CallKitMute(id, isMuted));
          break;
        default:
          break;
      }
    },
      // flutter_callkit_incoming 3.1.3 throws a FormatException while decoding
      // some native events (notably ACTION_CALL_TOGGLE_AUDIO_SESSION, whose
      // `isActive` arrives null on iOS — the package even mislabels it "id is
      // null"). Without this handler the throw surfaces as an unhandled zone
      // exception on every call. We don't consume that event, so swallow &
      // log — best-effort, never crash a call (Constitution §VII).
      onError: (Object e, StackTrace st) {
        debugPrint('[CallKitService] onEvent decode error (ignored): $e');
      },
    );
  }

  @override
  Future<void> showIncoming({
    required String callId,
    required String callerName,
    String? callerAvatarUrl,
    required bool isVideo,
  }) async {
    if (!await _callKitSupported) return;
    // E2: a repeated event for an already-shown call is a no-op.
    if (_activeIncoming.contains(callId)) return;
    _activeIncoming.add(callId);
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(
        buildCallKitParams(callId: callId, name: callerName, avatar: callerAvatarUrl, isVideo: isVideo),
      );
    } catch (e) {
      _activeIncoming.remove(callId);
      debugPrint('[CallKitService] showIncoming failed: $e');
    }
  }

  @override
  Future<void> startOutgoing({
    required String callId,
    required String calleeName,
    required bool isVideo,
  }) async {
    if (!await _callKitSupported) return;
    try {
      await FlutterCallkitIncoming.startCall(
        buildCallKitParams(callId: callId, name: calleeName, isVideo: isVideo),
      );
    } catch (e) {
      debugPrint('[CallKitService] startOutgoing failed: $e');
    }
  }

  @override
  Future<void> setConnected(String callId) async {
    if (!await _callKitSupported) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (e) {
      debugPrint('[CallKitService] setConnected failed: $e');
    }
  }

  @override
  Future<void> endCall(String callId) async {
    _activeIncoming.remove(callId);
    if (!await _callKitSupported) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[CallKitService] endCall failed: $e');
    }
  }

  @override
  Future<void> reportMute(String callId, bool muted) async {
    if (!await _callKitSupported) return;
    try {
      await FlutterCallkitIncoming.muteCall(callId, isMuted: muted);
    } catch (e) {
      debugPrint('[CallKitService] reportMute failed: $e');
    }
  }

  @override
  Future<void> endAllCalls() async {
    _activeIncoming.clear();
    if (!await _callKitSupported) return;
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallKitService] endAllCalls failed: $e');
    }
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _controller.close();
  }
}

/// Builds the canonical [CallKitParams] for a Ciro call. Top-level so it can be
/// reused by the FCM background isolate (U1) without DI.
CallKitParams buildCallKitParams({
  required String callId,
  required String name,
  String? avatar,
  required bool isVideo,
}) =>
    CallKitParams(
      id: callId,
      nameCaller: name,
      appName: 'Ciro',
      avatar: avatar,
      handle: name,
      type: isVideo ? 1 : 0,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        isShowCallID: false,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        supportsDTMF: false,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        // 1:1 calls also surface in the iOS Phone app's Recents (revises the
        // original in-app-only Q2 decision). Android still does NOT write to
        // the native call log — that requires the sensitive WRITE_CALL_LOG
        // permission and Play Store justification (FR-VoIP-05 stays in-app
        // on Android only).
        includesCallsInRecents: true,
      ),
    );

/// Shows the native incoming-call UI directly from FCM `call`-type data. Safe to
/// call from the terminated/background isolate — uses no DI singletons (U1).
Future<void> showCallkitIncomingFromData(Map<String, dynamic> data) async {
  final callId = data['callId']?.toString();
  if (callId == null || callId.isEmpty) return;
  try {
    await FlutterCallkitIncoming.showCallkitIncoming(buildCallKitParams(
      callId: callId,
      name: data['callerName']?.toString() ?? 'Unknown',
      avatar: data['callerAvatarUrl']?.toString(),
      isVideo: data['isVideo']?.toString() == 'true',
    ));
  } catch (e) {
    debugPrint('[CallKit] background showIncoming failed: $e');
  }
}
