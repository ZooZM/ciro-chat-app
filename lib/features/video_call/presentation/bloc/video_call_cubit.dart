import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/video_call_repository.dart';

part 'video_call_state.dart';

@injectable
class VideoCallCubit extends Cubit<VideoCallState> {
  final VideoCallRepository _repository;

  VideoCallCubit(this._repository) : super(const VideoCallInitial());

  Future<void> joinRoom(String roomId) async {
    // Hardcoded LIVEKIT_WS_URL mapped to backend's valid instance
    const liveKitWsUrl = 'wss://ciro-chat-qc2pe2cz.livekit.cloud';
    emit(const VideoCallConnecting());
    try {
      final room = await _repository.joinRoomByApi(roomId, liveKitWsUrl);
      emit(VideoCallConnected(room));
    } catch (e) {
      emit(VideoCallError(e.toString()));
    }
  }

  Future<void> leaveRoom() async {
    try {
      await _repository.disconnect();
    } finally {
      emit(VideoCallDisconnected());
    }
  }

  Future<void> muteMic(bool mute) async {
    await _repository.toggleMic(!mute);
  }

  Future<void> disableCamera(bool disable) async {
    await _repository.toggleCamera(!disable);
  }
}
