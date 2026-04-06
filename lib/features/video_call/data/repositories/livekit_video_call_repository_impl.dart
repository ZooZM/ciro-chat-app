import 'package:livekit_client/livekit_client.dart';
import 'package:injectable/injectable.dart';
import '../../domain/repositories/video_call_repository.dart';

@LazySingleton(as: VideoCallRepository)
class LivekitVideoCallRepositoryImpl implements VideoCallRepository {
  Room? _room;

  @override
  Future<Room> connect(String wsUrl, String token) async {
    const roomOptions = RoomOptions(
      adaptiveStream: true,
      dynacast: true,
    );
    
    _room = Room(roomOptions: roomOptions);
    
    await _room!.connect(
      wsUrl,
      token,
    );

    return _room!;
  }

  @override
  Future<void> disconnect() async {
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }
  }

  @override
  Future<void> toggleMic(bool enabled) async {
    if (_room != null && _room!.localParticipant != null) {
      await _room!.localParticipant!.setMicrophoneEnabled(enabled);
    }
  }

  @override
  Future<void> toggleCamera(bool enabled) async {
    if (_room != null && _room!.localParticipant != null) {
      await _room!.localParticipant!.setCameraEnabled(enabled);
    }
  }
}
