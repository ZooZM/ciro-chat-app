import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../datasources/video_call_remote_data_source.dart';

@LazySingleton(as: VideoCallRepository)
class LivekitVideoCallRepositoryImpl implements VideoCallRepository {
  static const _screenShareChannel =
      MethodChannel('com.example.ciro_chat_app/screen_share_service');

  final VideoCallRemoteDataSource _remoteDataSource;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  void Function()? _onLocalScreenShareEndedExternally;
  bool _androidServiceRunning = false;
  bool _callServiceRunning = false;

  LivekitVideoCallRepositoryImpl(this._remoteDataSource);

  @override
  set onLocalScreenShareEndedExternally(void Function()? callback) {
    _onLocalScreenShareEndedExternally = callback;
  }

  /// T012a — Registers the room created by the call screen so screen-share methods
  /// work on the same room the screen is displaying.
  @override
  void setExternalRoom(Room? room) {
    _roomListener?.dispose();
    _roomListener = null;
    _room = room;
    if (room == null) return;

    _roomListener = room.createListener();
    _roomListener!.on<LocalTrackUnpublishedEvent>((event) {
      if (event.publication.source == TrackSource.screenShareVideo) {
        debugPrint('[LivekitRepo] External screen-share stop via LocalTrackUnpublishedEvent');
        _onLocalScreenShareEndedExternally?.call();
      }
    });

    if (defaultTargetPlatform == TargetPlatform.android) {
      _screenShareChannel.setMethodCallHandler((call) async {
        if (call.method == 'onStopFromNotification') {
          debugPrint('[LivekitRepo] Android STOP from notification');
          _androidServiceRunning = false;
          final local = _room?.localParticipant;
          if (local != null) {
            try {
              await local.setScreenShareEnabled(false);
            } catch (_) {}
          }
        }
      });
    }
  }

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
      defaultScreenShareCaptureOptions:
          ScreenShareCaptureOptions(useiOSBroadcastExtension: true),
    );

    _room = Room(roomOptions: roomOptions);

    await _room!.connect(wsUrl, token);

    // CRITICAL: Publish local media tracks immediately after connecting.
    // Without this, the local participant has no camera/mic tracks, causing
    // the ICE agent to find no media to negotiate and timing out when a peer joins.
    await _room!.localParticipant?.setCameraEnabled(true);
    await _room!.localParticipant?.setMicrophoneEnabled(true);

    // T012a: Listen for external screen-share stop (iOS banner / Android STOP action).
    // LiveKit fires LocalTrackUnpublishedEvent when the OS tears down the broadcast.
    _roomListener = _room!.createListener();
    _roomListener!.on<LocalTrackUnpublishedEvent>((event) {
      if (event.publication.source == TrackSource.screenShareVideo) {
        debugPrint('[LivekitRepo] External screen-share stop detected via LocalTrackUnpublishedEvent');
        _onLocalScreenShareEndedExternally?.call();
      }
    });

    return _room!;
  }

  @override
  Future<void> disconnect() async {
    _roomListener?.dispose();
    _roomListener = null;
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

  /// T012 — Starts or stops the local screen share, with optional device audio.
  @override
  Future<Either<Failure, void>> setScreenShareEnabled(bool enabled, {bool withDeviceAudio = false}) async {
    final local = _room?.localParticipant;
    if (local == null) return Left(ScreenShareDeniedFailure('No active call'));

    try {
      if (enabled) {
        // Android: arm the native side BEFORE flutter_webrtc shows the system
        // consent dialog. The "start" call doesn't actually start the FGS — it
        // sets a flag in MainActivity. MainActivity.onActivityResult then
        // starts the FGS the moment RESULT_OK arrives from the consent dialog,
        // BEFORE flutter_webrtc's fragment calls getMediaProjection (which on
        // Android 14 requires the FGS to already be running with type
        // mediaProjection). See MainActivity.kt for the timing details.
        //
        // useiOSBroadcastExtension: true routes the iOS track to the broadcast
        // extension socket reader. Passing explicit options here overrides
        // Room defaults, so the flag must be set on this object.
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _screenShareChannel.invokeMethod('start');
          _androidServiceRunning = true;
        }
        await local.setScreenShareEnabled(
          true,
          screenShareCaptureOptions: ScreenShareCaptureOptions(
            useiOSBroadcastExtension: true,
            captureScreenAudio: withDeviceAudio,
          ),
        );
      } else {
        await local.setScreenShareEnabled(false);
        if (defaultTargetPlatform == TargetPlatform.android && _androidServiceRunning) {
          _androidServiceRunning = false;
          await _screenShareChannel.invokeMethod('stop');
        }
      }
      return const Right(null);
    } catch (e) {
      if (defaultTargetPlatform == TargetPlatform.android && _androidServiceRunning) {
        _androidServiceRunning = false;
        try { await _screenShareChannel.invokeMethod('stop'); } catch (_) {}
      }
      debugPrint('[LivekitRepo] setScreenShareEnabled($enabled) error: $e');
      final msg = e.toString().toLowerCase();
      final label = msg.contains('cancel') ? 'cancelled' : 'denied';
      return Left(ScreenShareDeniedFailure(label));
    }
  }

  /// Starts/stops the Android call foreground service so the OS doesn't
  /// suspend mic/camera access when the screen locks. No-op on iOS — iOS
  /// CallKit / VoIP push handles backgrounding separately.
  @override
  Future<void> setCallServiceActive(bool active) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (active == _callServiceRunning) return;
    try {
      await _screenShareChannel.invokeMethod(active ? 'startCallService' : 'stopCallService');
      _callServiceRunning = active;
    } catch (e) {
      debugPrint('[LivekitRepo] setCallServiceActive($active) error: $e');
    }
  }

  /// T021 — Returns the screen-share video track publication for a remote participant.
  @override
  RemoteTrackPublication? screenShareVideoTrackOf(String participantIdentity) {
    final participant = _room?.remoteParticipants[participantIdentity];
    if (participant == null) return null;
    try {
      return participant.videoTrackPublications
          .firstWhere((pub) => pub.source == TrackSource.screenShareVideo);
    } catch (_) {
      return null;
    }
  }

  /// T021 — Returns the screen-share audio track publication for a remote participant.
  @override
  RemoteTrackPublication? screenShareAudioTrackOf(String participantIdentity) {
    final participant = _room?.remoteParticipants[participantIdentity];
    if (participant == null) return null;
    try {
      return participant.audioTrackPublications
          .firstWhere((pub) => pub.source == TrackSource.screenShareAudio);
    } catch (_) {
      return null;
    }
  }
}
