import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

// ------------------------------------------------------------
// Core Base States for Call Management
// ------------------------------------------------------------
abstract class CallState {}

class CallIdle extends CallState {}

class CallIncoming extends CallState {
  final String callerId;
  final String callerName;
  CallIncoming(this.callerId, this.callerName);
}

class CallOutgoing extends CallState {
  final String calleeName;
  CallOutgoing(this.calleeName);
}

class CallAccepted extends CallState {
  final String livekitUrl;
  final String livekitToken;
  CallAccepted({required this.livekitUrl, required this.livekitToken});
}

class CallDisconnected extends CallState {}

// ------------------------------------------------------------
// CallCubit: Manages the Ringtone Audioplayer & Call Flags
// ------------------------------------------------------------
class CallCubit extends Cubit<CallState> {
  final FlutterRingtonePlayer _audioPlayer;

  CallCubit() : _audioPlayer = FlutterRingtonePlayer(), super(CallIdle());

  /// Triggers when the 'callIncoming' WebSocket event hits the backend.
  Future<void> handleIncomingCall(String callerId, String callerName) async {
    emit(CallIncoming(callerId, callerName));

    // CRITICAL: Play ringtone continuously in a LOOP natively!
    _audioPlayer.playRingtone(looping: true);
  }

  /// Triggers when you dial outwards.
  Future<void> handleOutgoingCall(String calleeName) async {
    emit(CallOutgoing(calleeName));

    // CRITICAL: Play dialing sound continuously in a LOOP
    _audioPlayer.play(
      android: AndroidSounds.notification,
      ios: IosSounds.electronic,
      looping: true,
      volume: 0.5,
    );
  }

  /// Triggers when the 'callAccepted' WebSocket payload yields credentials.
  void acceptCall(String livekitUrl, String livekitToken) {
    // CRITICAL: Must halt the audioplayer memory immediately prior to transition!
    _stopRinging();
    emit(CallAccepted(livekitUrl: livekitUrl, livekitToken: livekitToken));
  }

  /// Ends ringing gracefully whenever the session naturally terminates or rejects.
  void rejectOrDisconnect() {
    _stopRinging();
    emit(CallDisconnected());
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
