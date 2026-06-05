import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/error/failures.dart';

abstract class VideoCallRepository {
  Future<Room> connect(String wsUrl, String token);
  Future<Room> joinRoomByApi(String roomId, String liveKitWsUrl);
  Future<void> disconnect();
  Future<void> toggleMic(bool enabled);
  Future<void> toggleCamera(bool enabled);

  /// Starts or stops the local screen share. When [withDeviceAudio] is true,
  /// an additional screen-audio track is also published. Returns
  /// Left(ScreenShareDeniedFailure) if the OS denies or the user dismisses.
  Future<Either<Failure, void>> setScreenShareEnabled(bool enabled, {bool withDeviceAudio = false});

  /// Returns the screen-share video track publication for [participantIdentity], or null.
  RemoteTrackPublication? screenShareVideoTrackOf(String participantIdentity);

  /// Returns the screen-share audio track publication for [participantIdentity], or null.
  RemoteTrackPublication? screenShareAudioTrackOf(String participantIdentity);

  /// Callback invoked by the repository when the OS ends the local screen share
  /// externally (iOS Broadcast banner stop / Android foreground-service STOP).
  set onLocalScreenShareEndedExternally(void Function()? callback);

  /// Registers an externally-created [Room] (owned by the call screen) so that
  /// screen-share and track-finder methods work on the correct room instance.
  void setExternalRoom(Room? room);

  /// Starts or stops the Android call foreground service. The service declares
  /// foregroundServiceType="microphone|camera" so Android keeps WebRTC alive
  /// while the screen is locked. No-op on iOS.
  Future<void> setCallServiceActive(bool active);
}
