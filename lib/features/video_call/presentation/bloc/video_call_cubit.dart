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

  Future<void> joinRoom(String wsUrl, String token) async {
    emit(VideoCallConnecting());
    try {
      final room = await _repository.connect(wsUrl, token);
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
