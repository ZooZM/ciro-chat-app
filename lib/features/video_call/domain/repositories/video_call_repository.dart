import 'package:livekit_client/livekit_client.dart';

abstract class VideoCallRepository {
  Future<Room> connect(String wsUrl, String token);
  Future<Room> joinRoomByApi(String roomId, String liveKitWsUrl);
  Future<void> disconnect();
  Future<void> toggleMic(bool enabled);
  Future<void> toggleCamera(bool enabled);
}
