part of 'video_call_cubit.dart';

sealed class VideoCallState extends Equatable {
  const VideoCallState();

  @override
  List<Object?> get props => [];
}

class VideoCallInitial extends VideoCallState {
  const VideoCallInitial();
}

class VideoCallConnecting extends VideoCallState {
  const VideoCallConnecting();
}

class VideoCallConnected extends VideoCallState {
  final Room room;

  const VideoCallConnected(this.room);

  @override
  List<Object?> get props => [room];
}

class VideoCallDisconnected extends VideoCallState {
  const VideoCallDisconnected();
}

class VideoCallError extends VideoCallState {
  final String message;

  const VideoCallError(this.message);

  @override
  List<Object?> get props => [message];
}
