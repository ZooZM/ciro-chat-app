import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/network/socket_service.dart';

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

  const CallOutgoing({
    required this.targetUserId,
    required this.targetName,
    this.targetAvatarUrl = '',
  });

  @override
  List<Object?> get props => [targetUserId];
}

/// The remote is calling us — show IncomingCallScreen
class CallIncoming extends CallState {
  final String callerId;
  final String callerName;
  final String callerAvatarUrl;

  const CallIncoming({
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl = '',
  });

  @override
  List<Object?> get props => [callerId];
}

/// Both sides accepted – join the video room
class CallActive extends CallState {
  /// LiveKit room token delivered by the backend in callAccepted payload
  final String livekitToken;
  final String contactName;

  const CallActive({required this.livekitToken, required this.contactName});

  @override
  List<Object?> get props => [livekitToken];
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
  final FlutterRingtonePlayer _audioPlayer;

  CallCubit(this._socketService)
    : _audioPlayer = FlutterRingtonePlayer(),
      super(const CallIdle()) {
    _bindSocketListeners();
  }

  // ── Socket listener binding ───────────────────────────────────────────────

  void _bindSocketListeners() {
    // Remote is calling us
    _socketService.onIncomingCall = (data) async {
      emit(
        CallIncoming(
          callerId: data['callerId'] as String? ?? '',
          callerName: data['callerName'] as String? ?? 'Unknown',
          callerAvatarUrl: data['callerAvatarUrl'] as String? ?? '',
        ),
      );

      // CRITICAL: Play ringtone continuously in a LOOP natively!
      _audioPlayer.playRingtone(looping: true);
    };

    // Remote accepted our call → both enter room
    _socketService.onCallAccepted = (data) {
      _stopRinging();
      final incoming = state;
      final contactName = incoming is CallOutgoing
          ? incoming.targetName
          : 'Caller';
      emit(
        CallActive(
          livekitToken: data['token'] as String? ?? '',
          contactName: contactName,
        ),
      );
    };

    // Remote rejected our call
    _socketService.onCallRejected = (_) {
      _stopRinging();
      emit(const CallEnded(reason: 'rejected'));
    };
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// Caller taps the video icon → emits requestCall
  void initiateCall({
    required String targetUserId,
    required String targetName,
    String targetAvatarUrl = '',
  }) async {
    _socketService.requestCall(targetUserId: targetUserId, isVideo: true);
    emit(
      CallOutgoing(
        targetUserId: targetUserId,
        targetName: targetName,
        targetAvatarUrl: targetAvatarUrl,
      ),
    );

    // CRITICAL: Play dialing sound continuously in a LOOP
    _audioPlayer.play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.electronic,
      looping: true,
      volume: 0.5,
    );
  }

  /// Receiver taps Accept → emits acceptCall
  void acceptCall() {
    final s = state;
    if (s is! CallIncoming) return;
    _stopRinging();
    _socketService.acceptCall(callerId: s.callerId);

    // Transition to active immediately on receiver side.
    emit(CallActive(livekitToken: '', contactName: s.callerName));
  }

  /// Receiver taps Decline → emits rejectCall
  void rejectCall() {
    final s = state;
    if (s is! CallIncoming) return;
    _stopRinging();
    _socketService.rejectCall(callerId: s.callerId);
    emit(const CallEnded(reason: 'rejected'));
  }

  /// Either side ends the active call
  void endCall() {
    _stopRinging();
    _socketService.endCall();
    emit(const CallIdle());
  }

  /// Reset to idle (e.g., after navigating away from ended call)
  void reset() {
    _stopRinging();
    emit(const CallIdle());
  }

  void _stopRinging() {
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _stopRinging();
    _audioPlayer.stop();
    return super.close();
  }
}
