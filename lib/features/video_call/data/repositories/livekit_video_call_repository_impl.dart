import 'package:livekit_client/livekit_client.dart';
import 'package:injectable/injectable.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../datasources/video_call_remote_data_source.dart';

@LazySingleton(as: VideoCallRepository)
class LivekitVideoCallRepositoryImpl implements VideoCallRepository {
  final VideoCallRemoteDataSource _remoteDataSource;
  Room? _room;

  LivekitVideoCallRepositoryImpl(this._remoteDataSource);

  @override
  Future<Room> joinRoomByApi(String roomId, String liveKitWsUrl) async {
    final token = await _remoteDataSource.fetchLiveKitToken(roomId);
    return connect(liveKitWsUrl, token);
  }

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

    // CRITICAL: Publish local media tracks immediately after connecting.
    // Without this, the local participant has no camera/mic tracks, causing
    // the ICE agent to find no media to negotiate and timing out when a peer joins.
    await _room!.localParticipant?.setCameraEnabled(true);
    await _room!.localParticipant?.setMicrophoneEnabled(true);

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
