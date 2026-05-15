import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_constants.dart';
import '../../domain/entities/call_participant.dart';

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

  const CallActive({
    required this.livekitToken,
    required this.livekitUrl,
    required this.contactName,
    this.isVideo = true,
    this.isGroupCall = false,
    this.chatRoomId = '',
    this.participants = const [],
    this.recordingState = RecordingState.inactive,
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
    );
  }

  @override
  List<Object?> get props => [livekitToken, livekitUrl, isVideo, isGroupCall, participants, recordingState];
}

/// Receiver accepts the call and waits for token authorization
class CallConnecting extends CallState {
  final String contactName;
  final bool isVideo;

  const CallConnecting({required this.contactName, this.isVideo = true});

  @override
  List<Object?> get props => [contactName, isVideo];
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
          isVideo:
              data['isVideo'] ==
              true, // Rely on backend, fallback to false if omitted
        ),
      );

      // CRITICAL: Play ringtone continuously in a LOOP natively!
      _audioPlayer.playRingtone(looping: true);
    };

    // Both sides accepted — enter the LiveKit room (1-on-1 AND group path).
    _socketService.onCallAccepted = (data) {
      _stopRinging();
      final s = state;

      // Group call path: caller gets token right away; acceptors get it via acceptGroupCall
      if (s is CallIncoming && s.isGroupCall ||
          s is CallConnecting && s.contactName == 'Group Call' ||
          s is CallOutgoing && s.isGroupCall) {
        final incoming = s is CallIncoming ? s : null;
        final outgoing = s is CallOutgoing ? s : null;
        final rawParticipants = data['currentParticipants'] as List<dynamic>? ?? [];
        final participants = rawParticipants
            .map((id) => CallParticipant(userId: id.toString(), phoneNumber: '', joinedAt: DateTime.now()))
            .toList();
        emit(CallActive(
          livekitToken: data['livekitToken'] as String? ?? '',
          livekitUrl: data['livekitUrl'] as String? ?? AppConstants.liveKitWsUrl,
          contactName: incoming != null && incoming.groupName.isNotEmpty
              ? incoming.groupName
              : (outgoing?.targetName ?? 'Group Call'),
          isVideo: s is CallIncoming ? s.isVideo : (s is CallOutgoing ? s.isVideo : (s as CallConnecting).isVideo),
          isGroupCall: true,
          chatRoomId: incoming?.chatRoomId ?? outgoing?.chatRoomId ?? data['chatRoomId'] as String? ?? '',
          participants: participants,
        ));
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
    };

    // Remote rejected our call
    _socketService.onCallRejected = (_) {
      _stopRinging();
      emit(const CallEnded(reason: 'rejected'));
    };

    // ── Group call socket events ───────────────────────────────────────────────

    _socketService.onIncomingGroupCall = (data) {
      _audioPlayer.playRingtone(looping: true);
      emit(CallIncoming(
        callerId: data['callerUserId'] as String? ?? '',
        callerName: data['callerName'] as String? ?? 'Unknown',
        isVideo: data['isVideo'] == true,
        isGroupCall: true,
        chatRoomId: data['chatRoomId'] as String? ?? '',
        groupName: data['groupName'] as String? ?? '',
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
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// Caller taps the video icon → emits requestCall
  void initiateCall({
    required String targetUserId,
    required String targetName,
    String targetAvatarUrl = '',
    bool isVideo = true,
  }) async {
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

  // ── Group call actions ────────────────────────────────────────────────────

  /// Initiates a group call. Backend fans out `incomingGroupCall` to room members.
  void startGroupCall({required String chatRoomId, required bool isVideo}) {
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
    emit(CallConnecting(contactName: s.groupName.isNotEmpty ? s.groupName : 'Group Call', isVideo: s.isVideo));
  }

  /// Declines an incoming group call.
  void declineGroupCall() {
    final s = state;
    if (s is! CallIncoming || !s.isGroupCall) return;
    _stopRinging();
    _socketService.declineGroupCall(chatRoomId: s.chatRoomId);
    emit(const CallEnded(reason: 'rejected'));
  }

  /// Leaves an active group call.
  void leaveGroupCall() {
    final s = state;
    if (s is! CallActive || !s.isGroupCall) return;
    _socketService.leaveGroupCall(chatRoomId: s.chatRoomId);
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
