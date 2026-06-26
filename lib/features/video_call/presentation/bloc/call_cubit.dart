import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/services/callkit_service.dart';
import '../../../../core/theme/app_constants.dart';
import '../../../call_history/domain/entities/call_history_record.dart';
import '../../../call_history/domain/repositories/call_history_repository.dart';
import '../../domain/entities/call_participant.dart';
import '../../domain/repositories/video_call_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIDE EVENTS (T011) — transient signals the UI consumes once (not persisted in state)
// ─────────────────────────────────────────────────────────────────────────────

sealed class CallSideEvent {}

/// Another participant is already sharing — show "X is already sharing" SnackBar.
class CallScreenShareConflict extends CallSideEvent {
  final String activeSharerName;
  CallScreenShareConflict(this.activeSharerName);
}

/// OS permission was denied or dismissed — show "Permission required" SnackBar.
class CallScreenShareDenied extends CallSideEvent {}

/// CallKit system controls toggled mute — the active call screen owns the
/// LiveKit Room, so it consumes this and calls `setMicrophoneEnabled` (C1).
class CallMuteRequested extends CallSideEvent {
  final bool muted;
  CallMuteRequested(this.muted);
}

// ─────────────────────────────────────────────────────────────────────────────
// STATES
// ─────────────────────────────────────────────────────────────────────────────

abstract class CallState extends Equatable {
  const CallState();
  @override
  List<Object?> get props => [];
}

/// No active call
class CallIdle extends CallState {
  const CallIdle();
}

/// We placed a call and are waiting for the remote to answer
class CallOutgoing extends CallState {
  final String targetUserId;
  final String targetName;
  final String targetAvatarUrl;
  final bool isVideo;
  final bool isGroupCall;
  final String chatRoomId;

  const CallOutgoing({
    required this.targetUserId,
    required this.targetName,
    this.targetAvatarUrl = '',
    this.isVideo = true,
    this.isGroupCall = false,
    this.chatRoomId = '',
  });

  @override
  List<Object?> get props => [targetUserId, isVideo, isGroupCall, chatRoomId];
}

/// The remote is calling us — show IncomingCallScreen
class CallIncoming extends CallState {
  final String callerId;
  final String callerName;
  final String callerAvatarUrl;
  final bool isVideo;
  // Group call extras (empty/false for 1-on-1 calls)
  final bool isGroupCall;
  final String chatRoomId;
  final String groupName;
  final int currentParticipantCount;

  const CallIncoming({
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl = '',
    this.isVideo = true,
    this.isGroupCall = false,
    this.chatRoomId = '',
    this.groupName = '',
    this.currentParticipantCount = 0,
  });

  @override
  List<Object?> get props => [callerId, isVideo, isGroupCall, chatRoomId];
}

/// Both sides accepted – join the video room
class CallActive extends CallState {
  final String livekitToken;
  final String livekitUrl;
  final String contactName;
  final bool isVideo;
  // Group call extras (empty/false for 1-on-1 calls)
  final bool isGroupCall;
  final String chatRoomId;
  final List<CallParticipant> participants;
  final RecordingState recordingState;
  // Screen share fields (T010)
  final bool isLocallySharingScreen;
  final bool localShareIncludesAudio;
  final String activeSharerUserId;    // empty = no one sharing
  final String activeSharerName;
  final bool activeSharerHasAudio;
  final Set<String> mutedScreenAudioBySharerId; // local-only, never broadcast

  const CallActive({
    required this.livekitToken,
    required this.livekitUrl,
    required this.contactName,
    this.isVideo = true,
    this.isGroupCall = false,
    this.chatRoomId = '',
    this.participants = const [],
    this.recordingState = RecordingState.inactive,
    this.isLocallySharingScreen = false,
    this.localShareIncludesAudio = false,
    this.activeSharerUserId = '',
    this.activeSharerName = '',
    this.activeSharerHasAudio = false,
    this.mutedScreenAudioBySharerId = const {},
  });

  CallActive copyWith({
    String? livekitToken,
    String? livekitUrl,
    String? contactName,
    bool? isVideo,
    bool? isGroupCall,
    String? chatRoomId,
    List<CallParticipant>? participants,
    RecordingState? recordingState,
    bool? isLocallySharingScreen,
    bool? localShareIncludesAudio,
    String? activeSharerUserId,
    String? activeSharerName,
    bool? activeSharerHasAudio,
    Set<String>? mutedScreenAudioBySharerId,
  }) {
    return CallActive(
      livekitToken: livekitToken ?? this.livekitToken,
      livekitUrl: livekitUrl ?? this.livekitUrl,
      contactName: contactName ?? this.contactName,
      isVideo: isVideo ?? this.isVideo,
      isGroupCall: isGroupCall ?? this.isGroupCall,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      participants: participants ?? this.participants,
      recordingState: recordingState ?? this.recordingState,
      isLocallySharingScreen: isLocallySharingScreen ?? this.isLocallySharingScreen,
      localShareIncludesAudio: localShareIncludesAudio ?? this.localShareIncludesAudio,
      activeSharerUserId: activeSharerUserId ?? this.activeSharerUserId,
      activeSharerName: activeSharerName ?? this.activeSharerName,
      activeSharerHasAudio: activeSharerHasAudio ?? this.activeSharerHasAudio,
      mutedScreenAudioBySharerId: mutedScreenAudioBySharerId ?? this.mutedScreenAudioBySharerId,
    );
  }

  @override
  List<Object?> get props => [
    livekitToken,
    livekitUrl,
    isVideo,
    isGroupCall,
    participants,
    recordingState,
    isLocallySharingScreen,
    localShareIncludesAudio,
    activeSharerUserId,
    activeSharerName,
    activeSharerHasAudio,
    // Use sorted list for set equality in Equatable
    [...mutedScreenAudioBySharerId]..sort(),
  ];
}

/// Receiver accepts the call and waits for token authorization
class CallConnecting extends CallState {
  final String contactName;
  final bool isVideo;
  final String chatRoomId;

  const CallConnecting({
    required this.contactName,
    this.isVideo = true,
    this.chatRoomId = '',
  });

  @override
  List<Object?> get props => [contactName, isVideo, chatRoomId];
}

/// Call ended or rejected
class CallEnded extends CallState {
  final String reason; // 'rejected' | 'ended' | 'missed'
  const CallEnded({this.reason = 'ended'});

  @override
  List<Object?> get props => [reason];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

@lazySingleton
class CallCubit extends Cubit<CallState> {
  final SocketService _socketService;
  final VideoCallRepository _repo;
  final CallKitService _callKit;
  final CallHistoryRepository _historyRepo;
  final FlutterRingtonePlayer _audioPlayer;
  final _sideEventController = StreamController<CallSideEvent>.broadcast();

  static const _uuid = Uuid();

  /// Per-call metadata used to write the history row at the terminal transition.
  _CallContext? _ctx;

  StreamSubscription<CallKitAction>? _callKitSub;

  /// One-shot signals (conflict, denial, mute) that the UI consumes via StreamSubscription.
  Stream<CallSideEvent> get sideEvents => _sideEventController.stream;

  CallCubit(this._socketService, this._repo, this._callKit, this._historyRepo)
    : _audioPlayer = FlutterRingtonePlayer(),
      super(const CallIdle()) {
    _bindSocketListeners();
    _bindRepoListeners();
    _bindCallKitActions();
  }

  // ── Call-history context + CallKit bridging (020-native-voip-callkit) ───────

  void _startContext({
    required String callId,
    required String contactUserId,
    required String contactName,
    String? avatarUrl,
    required CallDirection direction,
    required CallType callType,
    required bool isGroup,
  }) {
    _ctx = _CallContext(
      callId: callId,
      contactUserId: contactUserId,
      contactName: contactName,
      avatarUrl: avatarUrl,
      direction: direction,
      callType: callType,
      isGroup: isGroup,
      startedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _markConnected() => _ctx?.connectedAt = DateTime.now().millisecondsSinceEpoch;

  /// Writes the history row exactly once for the current call, then clears ctx.
  Future<void> _recordHistory(CallOutcome outcome) async {
    final ctx = _ctx;
    if (ctx == null || ctx.recorded) return;
    ctx.recorded = true;
    final durationSeconds = (outcome == CallOutcome.answered && ctx.connectedAt != null)
        ? ((DateTime.now().millisecondsSinceEpoch - ctx.connectedAt!) ~/ 1000)
        : 0;
    await _historyRepo.add(CallHistoryRecord(
      id: ctx.callId,
      contactUserId: ctx.contactUserId,
      contactName: ctx.contactName,
      avatarUrl: ctx.avatarUrl,
      avatarColorSeed: ctx.contactName.hashCode,
      direction: ctx.direction,
      outcome: outcome,
      callType: ctx.callType,
      isGroup: ctx.isGroup,
      startedAt: ctx.startedAt,
      durationSeconds: durationSeconds,
    ));
    _ctx = null;
  }

  /// Maps native CallKit actions onto existing cubit actions (1:1 only, R10/C1).
  void _bindCallKitActions() {
    _callKitSub = _callKit.actions.listen((action) {
      switch (action) {
        case CallKitAccept():
          if (state is CallIncoming) acceptCall();
          break;
        case CallKitDecline():
          if (state is CallIncoming) rejectCall();
          break;
        case CallKitEnd():
          endCall();
          break;
        case CallKitTimeout():
          // Native ring timed out → missed.
          _recordHistory(CallOutcome.missed);
          emit(const CallEnded(reason: 'missed'));
          break;
        case CallKitMute(:final muted):
          // The active call screen owns the Room — forward the toggle (C1).
          _sideEventController.add(CallMuteRequested(muted));
          break;
      }
    });
  }

  // ── Socket listener binding ───────────────────────────────────────────────

  void _bindSocketListeners() {
    // Remote is calling us
    _socketService.onIncomingCall = (data) async {
      final callerId = data['callerId'] as String? ?? '';
      final callerName = data['callerName'] as String? ?? 'Unknown';
      final callerAvatarUrl = data['callerAvatarUrl'] as String? ?? '';
      final isVideo = data['isVideo'] == true;

      // 1:1 incoming → native CallKit UI (FR-VoIP-01/02). The backend may pass a
      // shared callId for cross-device correlation; otherwise generate one.
      final callId = data['callId'] as String? ?? _uuid.v4();
      _startContext(
        callId: callId,
        contactUserId: callerId,
        contactName: callerName,
        avatarUrl: callerAvatarUrl.isEmpty ? null : callerAvatarUrl,
        direction: CallDirection.incoming,
        callType: isVideo ? CallType.video : CallType.voice,
        isGroup: false,
      );
      _callKit.showIncoming(
        callId: callId,
        callerName: callerName,
        callerAvatarUrl: callerAvatarUrl.isEmpty ? null : callerAvatarUrl,
        isVideo: isVideo,
      );

      emit(
        CallIncoming(
          callerId: callerId,
          callerName: callerName,
          callerAvatarUrl: callerAvatarUrl,
          isVideo: isVideo,
        ),
      );
      // CallKit rings natively for 1:1 — no in-app ringtone to avoid double ring.
    };

    // Multi-device dedup (C2 — FR-VoIP-15): the call was answered/declined on
    // another of the user's devices → dismiss our native UI and DO NOT record
    // a missed call here.
    _socketService.onCallHandledElsewhere = (data) {
      _stopRinging();
      final ctx = _ctx;
      if (ctx != null) {
        ctx.recorded = true; // suppress the missed-record path
        _callKit.endCall(ctx.callId);
        _ctx = null;
      }
      emit(const CallIdle());
    };

    // Both sides accepted — enter the LiveKit room (1-on-1 AND group path).
    _socketService.onCallAccepted = (data) {
      _stopRinging();
      final s = state;

      // Group call path: caller gets token right away; acceptors get it via acceptGroupCall
      if (s is CallIncoming && s.isGroupCall ||
          s is CallConnecting && s.chatRoomId.isNotEmpty ||
          s is CallOutgoing && s.isGroupCall) {
        final incoming = s is CallIncoming ? s : null;
        final outgoing = s is CallOutgoing ? s : null;
        final connecting = s is CallConnecting ? s : null;
        final rawParticipants = data['currentParticipants'] as List<dynamic>? ?? [];
        final participants = rawParticipants
            .map((id) => CallParticipant(userId: id.toString(), phoneNumber: '', joinedAt: DateTime.now()))
            .toList();
        emit(CallActive(
          livekitToken: data['livekitToken'] as String? ?? '',
          livekitUrl: data['livekitUrl'] as String? ?? AppConstants.liveKitWsUrl,
          contactName: incoming != null && incoming.groupName.isNotEmpty
              ? incoming.groupName
              : (outgoing?.targetName ?? connecting?.contactName ?? 'Group Call'),
          isVideo: s is CallIncoming
              ? s.isVideo
              : s is CallOutgoing
                  ? s.isVideo
                  : (s as CallConnecting).isVideo,
          isGroupCall: true,
          chatRoomId: incoming?.chatRoomId ??
              outgoing?.chatRoomId ??
              connecting?.chatRoomId ??
              data['chatRoomId'] as String? ?? '',
          participants: participants,
        ));
        _markConnected(); // group: history duration only, no CallKit
        return;
      }

      // 1-on-1 path
      String contactName = 'Unknown';
      bool isVideo = true;
      if (s is CallOutgoing) {
        contactName = s.targetName;
        isVideo = s.isVideo;
      } else if (s is CallConnecting) {
        contactName = s.contactName;
        isVideo = s.isVideo;
      } else if (s is CallIncoming) {
        contactName = s.callerName;
        isVideo = s.isVideo;
      }
      emit(CallActive(
        livekitToken: data['livekitToken'] as String? ?? '',
        livekitUrl: data['livekitUrl'] as String? ?? AppConstants.liveKitWsUrl,
        contactName: contactName,
        isVideo: isVideo,
      ));
      // 1:1 connected → start the system call session so audio survives
      // backgrounding (FR-VoIP-03) and Recents duration begins (US2).
      _markConnected();
      if (_ctx != null) _callKit.setConnected(_ctx!.callId);
    };

    // Remote rejected our call
    _socketService.onCallRejected = (_) {
      _stopRinging();
      final callId = _ctx?.callId;
      _recordHistory(CallOutcome.declined); // outgoing declined by remote
      if (callId != null) _callKit.endCall(callId);
      emit(const CallEnded(reason: 'rejected'));
    };

    // ── Group call socket events ───────────────────────────────────────────────

    _socketService.onIncomingGroupCall = (data) {
      _audioPlayer.playRingtone(looping: true); // group: in-app ringtone (no CallKit)
      final chatRoomId = data['chatRoomId'] as String? ?? '';
      final groupName = data['groupName'] as String? ?? '';
      final isVideo = data['isVideo'] == true;
      _startContext(
        callId: _uuid.v4(),
        contactUserId: chatRoomId,
        contactName: groupName.isNotEmpty ? groupName : 'Group Call',
        direction: CallDirection.incoming,
        callType: isVideo ? CallType.video : CallType.voice,
        isGroup: true,
      );
      emit(CallIncoming(
        callerId: data['callerUserId'] as String? ?? '',
        callerName: data['callerName'] as String? ?? 'Unknown',
        isVideo: isVideo,
        isGroupCall: true,
        chatRoomId: chatRoomId,
        groupName: groupName,
        currentParticipantCount: (data['currentParticipantCount'] as int?) ?? 1,
      ));
    };

    _socketService.onGroupCallParticipantJoined = (data) {
      final s = state;
      if (s is! CallActive || !s.isGroupCall) return;
      final userId = data['userId'] as String? ?? '';
      final phone = data['phoneNumber'] as String? ?? '';
      if (userId.isEmpty || s.participants.any((p) => p.userId == userId)) return;
      final updated = [...s.participants, CallParticipant(userId: userId, phoneNumber: phone, joinedAt: DateTime.now())];
      emit(s.copyWith(participants: updated));
    };

    _socketService.onGroupCallParticipantLeft = (data) {
      final s = state;
      if (s is! CallActive || !s.isGroupCall) return;
      final userId = data['userId'] as String? ?? '';
      final updated = s.participants.where((p) => p.userId != userId).toList();
      emit(s.copyWith(participants: updated));
    };

    _socketService.onGroupCallRecordingStateChanged = (data) {
      final s = state;
      if (s is! CallActive || !s.isGroupCall) return;
      emit(s.copyWith(
        recordingState: RecordingState(
          isRecording: data['isRecording'] == true,
          recorderId: data['recorderId'] as String?,
        ),
      ));
    };

    // ── Screen share socket listeners (T017, T022) ────────────────────────────

    // T017: Backend rejected our share attempt — another user holds the lock.
    _socketService.onScreenShareRejected = (chatRoomId, activeSharerUserId, activeSharerName, reason) {
      _sideEventController.add(CallScreenShareConflict(activeSharerName));
    };

    // T022: A remote participant started or stopped sharing.
    _socketService.onScreenShareStateChanged = (chatRoomId, userId, userName, isSharing, withAudio) {
      final s = state;
      if (s is! CallActive || s.chatRoomId != chatRoomId) return;
      // Ignore events about ourselves — our own state is already updated locally.
      // We compare against the local sharer in the state (set during startScreenShare).
      if (isSharing) {
        emit(s.copyWith(
          activeSharerUserId: userId,
          activeSharerName: userName,
          activeSharerHasAudio: withAudio,
        ));
      } else if (s.activeSharerUserId == userId) {
        emit(s.copyWith(
          activeSharerUserId: '',
          activeSharerName: '',
          activeSharerHasAudio: false,
          mutedScreenAudioBySharerId: Set.from(
            s.mutedScreenAudioBySharerId.where((id) => id != userId),
          ),
        ));
      }
    };
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// Caller taps the video icon → emits requestCall
  void initiateCall({
    required String targetUserId,
    required String targetName,
    String targetAvatarUrl = '',
    bool isVideo = true,
  }) async {
    final callId = _uuid.v4();
    _startContext(
      callId: callId,
      contactUserId: targetUserId,
      contactName: targetName,
      avatarUrl: targetAvatarUrl.isEmpty ? null : targetAvatarUrl,
      direction: CallDirection.outgoing,
      callType: isVideo ? CallType.video : CallType.voice,
      isGroup: false,
    );
    _callKit.startOutgoing(callId: callId, calleeName: targetName, isVideo: isVideo);

    _socketService.requestCall(targetUserId: targetUserId, isVideo: isVideo);
    emit(
      CallOutgoing(
        targetUserId: targetUserId,
        targetName: targetName,
        targetAvatarUrl: targetAvatarUrl,
        isVideo: isVideo,
      ),
    );

    // CRITICAL: Play dialing sound continuously in a LOOP
    Future.delayed(Duration.zero, () {
      _audioPlayer.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 0.5,
      );
    });
  }

  /// Receiver taps Accept → emits acceptCall
  void acceptCall() {
    final s = state;
    if (s is! CallIncoming) return;
    _stopRinging();
    _socketService.acceptCall(callerId: s.callerId);

    // Transition to connecting state until server broadcasts callAccepted with tokens
    emit(CallConnecting(contactName: s.callerName, isVideo: s.isVideo));
  }

  /// Receiver taps Decline → emits rejectCall
  void rejectCall() {
    final s = state;
    if (s is! CallIncoming) return;
    _stopRinging();
    final callId = _ctx?.callId;
    _recordHistory(CallOutcome.declined); // incoming declined locally
    if (callId != null) _callKit.endCall(callId);
    _socketService.rejectCall(callerId: s.callerId);
    emit(const CallEnded(reason: 'rejected'));
  }

  /// T034 — Stops a local screen share (if any) before tearing down the call.
  /// Uses activeSharer fields stored in CallActive since those ARE the local user
  /// when isLocallySharingScreen is true.
  Future<void> _tearDownLocalScreenShare() async {
    final s = state;
    if (s is! CallActive || !s.isLocallySharingScreen) return;
    await _repo.setScreenShareEnabled(false).then(
      (_) {},
      onError: (e) => debugPrint('[CallCubit] teardown screen-share error (ignored): $e'),
    );
    _socketService.emitScreenShareStateChanged(
      chatRoomId: s.chatRoomId,
      userId: s.activeSharerUserId,
      userName: s.activeSharerName,
      isSharing: false,
      withAudio: false,
    );
  }

  /// In-app mute toggle → mirror onto the native call session (C1, bidirectional).
  void reportLocalMute(bool muted) {
    final callId = _ctx?.callId;
    if (callId != null) _callKit.reportMute(callId, muted);
  }

  /// Either side ends the active call
  Future<void> endCall() async {
    await _tearDownLocalScreenShare();
    _stopRinging();
    // Connected → answered; otherwise it never connected → missed.
    final ctx = _ctx;
    final callId = ctx?.callId;
    await _recordHistory(
      ctx?.connectedAt != null ? CallOutcome.answered : CallOutcome.missed,
    );
    if (callId != null) await _callKit.endCall(callId);
    _socketService.endCall();
    emit(const CallIdle());
  }

  /// Reset to idle (e.g., after navigating away from ended call, and on logout)
  Future<void> reset() async {
    await _tearDownLocalScreenShare();
    _stopRinging();
    // §V-A logout teardown / FR-VoIP-13: never leave a ghost native call.
    await _callKit.endAllCalls();
    _ctx = null;
    emit(const CallIdle());
  }

  // ── Group call actions ────────────────────────────────────────────────────

  /// Initiates a group call. Backend fans out `incomingGroupCall` to room members.
  void startGroupCall({required String chatRoomId, required bool isVideo}) {
    _startContext(
      callId: _uuid.v4(),
      contactUserId: chatRoomId,
      contactName: 'Group Call',
      direction: CallDirection.outgoing,
      callType: isVideo ? CallType.video : CallType.voice,
      isGroup: true,
    );
    _socketService.requestGroupCall(chatRoomId: chatRoomId, isVideo: isVideo);
    emit(CallOutgoing(
      targetUserId: chatRoomId,
      targetName: 'Group Call',
      isVideo: isVideo,
      isGroupCall: true,
      chatRoomId: chatRoomId,
    ));
    Future.delayed(Duration.zero, () {
      _audioPlayer.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 0.5,
      );
    });
  }

  /// Accepts an incoming group call. Server responds with `callAccepted` + LiveKit token.
  void acceptGroupCall() {
    final s = state;
    if (s is! CallIncoming || !s.isGroupCall) return;
    _stopRinging();
    _socketService.acceptGroupCall(chatRoomId: s.chatRoomId);
    emit(CallConnecting(
      contactName: s.groupName.isNotEmpty ? s.groupName : 'Group Call',
      isVideo: s.isVideo,
      chatRoomId: s.chatRoomId,
    ));
  }

  /// Declines an incoming group call.
  void declineGroupCall() {
    final s = state;
    if (s is! CallIncoming || !s.isGroupCall) return;
    _stopRinging();
    _recordHistory(CallOutcome.declined);
    _socketService.declineGroupCall(chatRoomId: s.chatRoomId);
    emit(const CallEnded(reason: 'rejected'));
  }

  /// Leaves an active group call.
  Future<void> leaveGroupCall() async {
    final s = state;
    if (s is! CallActive || !s.isGroupCall) return;
    await _tearDownLocalScreenShare();
    await _recordHistory(
      _ctx?.connectedAt != null ? CallOutcome.answered : CallOutcome.missed,
    );
    _socketService.leaveGroupCall(chatRoomId: s.chatRoomId);
    emit(const CallIdle());
  }

  /// Joins an ongoing group call from the group chat screen (no prior incoming
  /// event). Emits [CallConnecting] so [CallOverlay] shows a banner while
  /// waiting for the LiveKit token from the server's [callAccepted] response.
  void joinActiveGroupCall({required String roomId, required bool isVideo}) {
    _socketService.acceptGroupCall(chatRoomId: roomId);
    emit(CallConnecting(
      contactName: 'Group Call',
      isVideo: isVideo,
      chatRoomId: roomId,
    ));
  }

  // ── Screen share actions (T015–T017, T022–T023) ──────────────────────────

  /// T012a — Binds the repo callback so OS-level stops (iOS banner / Android STOP)
  /// are handled the same as an explicit in-app stop.
  void _bindRepoListeners({String localUserId = '', String localUserName = ''}) {
    _repo.onLocalScreenShareEndedExternally = () {
      _handleExternalScreenShareStop(localUserId, localUserName);
    };
  }

  /// Called when the OS tears down the broadcast without an explicit in-app tap.
  /// Mirrors stopScreenShare but skips the redundant setScreenShareEnabled(false).
  void _handleExternalScreenShareStop(String localUserId, String localUserName) {
    final s = state;
    if (s is! CallActive || !s.isLocallySharingScreen) return;
    _socketService.emitScreenShareStateChanged(
      chatRoomId: s.chatRoomId,
      userId: localUserId,
      userName: localUserName,
      isSharing: false,
      withAudio: false,
    );
    emit(s.copyWith(
      isLocallySharingScreen: false,
      localShareIncludesAudio: false,
      activeSharerUserId: '',
      activeSharerName: '',
      activeSharerHasAudio: false,
      mutedScreenAudioBySharerId: const {},
    ));
  }

  /// T015 — Initiates a screen share after the user chose their audio mode.
  Future<void> startScreenShare({
    required bool withDeviceAudio,
    required String localUserId,
    required String localUserName,
  }) async {
    final s = state;
    if (s is! CallActive) return;

    // FR-012: another user is already sharing
    if (s.activeSharerUserId.isNotEmpty && s.activeSharerUserId != localUserId) {
      _sideEventController.add(CallScreenShareConflict(s.activeSharerName));
      return;
    }

    // Already sharing locally — no-op
    if (s.isLocallySharingScreen) return;

    // Wire external-stop callback with the current user context
    _bindRepoListeners(localUserId: localUserId, localUserName: localUserName);

    final result = await _repo.setScreenShareEnabled(true, withDeviceAudio: withDeviceAudio);
    result.fold(
      (_) => _sideEventController.add(CallScreenShareDenied()),
      (_) {
        _socketService.emitScreenShareStateChanged(
          chatRoomId: s.chatRoomId,
          userId: localUserId,
          userName: localUserName,
          isSharing: true,
          withAudio: withDeviceAudio,
        );
        emit(s.copyWith(
          isLocallySharingScreen: true,
          localShareIncludesAudio: withDeviceAudio,
          activeSharerUserId: localUserId,
          activeSharerName: localUserName,
          activeSharerHasAudio: withDeviceAudio,
        ));
      },
    );
  }

  /// T016 — Stops the local screen share.
  Future<void> stopScreenShare({
    required String localUserId,
    required String localUserName,
  }) async {
    final s = state;
    if (s is! CallActive || !s.isLocallySharingScreen) return;

    // Errors from setScreenShareEnabled(false) are swallowed — stopping should never fail loudly
    await _repo.setScreenShareEnabled(false).then(
      (_) {},
      onError: (e) => debugPrint('[CallCubit] stopScreenShare error (ignored): $e'),
    );

    _socketService.emitScreenShareStateChanged(
      chatRoomId: s.chatRoomId,
      userId: localUserId,
      userName: localUserName,
      isSharing: false,
      withAudio: false,
    );
    emit(s.copyWith(
      isLocallySharingScreen: false,
      localShareIncludesAudio: false,
      activeSharerUserId: '',
      activeSharerName: '',
      activeSharerHasAudio: false,
      mutedScreenAudioBySharerId: const {},
    ));
  }

  /// T023 — Toggles per-receiver mute for a remote participant's screen-share audio.
  /// Uses setSubscribed(bool) — the LiveKit API for locally enabling/disabling a track.
  Future<void> toggleReceivedScreenShareAudioMute(String sharerUserId) async {
    final s = state;
    if (s is! CallActive) return;

    final isMuted = s.mutedScreenAudioBySharerId.contains(sharerUserId);
    final pub = _repo.screenShareAudioTrackOf(sharerUserId);
    if (pub != null) {
      // isMuted=true → currently muted → unmute → enable() (resume delivery)
      // isMuted=false → currently unmuted → mute → disable() (pause delivery)
      try {
        if (isMuted) {
          await pub.enable();
        } else {
          await pub.disable();
        }
      } catch (e) {
        debugPrint('[CallCubit] toggleReceivedScreenShareAudioMute error: $e');
      }
    }

    final updated = Set<String>.from(s.mutedScreenAudioBySharerId);
    if (isMuted) {
      updated.remove(sharerUserId);
    } else {
      updated.add(sharerUserId);
    }
    emit(s.copyWith(mutedScreenAudioBySharerId: updated));
  }

  void _stopRinging() {
    _audioPlayer.stop().ignore();
  }

  @override
  Future<void> close() {
    _stopRinging();
    _callKitSub?.cancel();
    _sideEventController.close();
    return super.close();
  }
}

/// Mutable per-call metadata captured at call start and finalized into a
/// [CallHistoryRecord] at the terminal transition (data-model.md).
class _CallContext {
  final String callId;
  final String contactUserId;
  final String contactName;
  final String? avatarUrl;
  final CallDirection direction;
  final CallType callType;
  final bool isGroup;
  final int startedAt;
  int? connectedAt;
  bool recorded = false;

  _CallContext({
    required this.callId,
    required this.contactUserId,
    required this.contactName,
    this.avatarUrl,
    required this.direction,
    required this.callType,
    required this.isGroup,
    required this.startedAt,
  });
}
