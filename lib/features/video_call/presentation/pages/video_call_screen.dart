import 'dart:async';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../bloc/call_cubit.dart';
import '../widgets/screen_share_tile.dart';
import '../widgets/screen_share_toggle_sheet.dart';

class VideoCallScreen extends StatefulWidget {
  final String contactName;
  final String livekitUrl;
  final String livekitToken;

  const VideoCallScreen({
    super.key,
    required this.contactName,
    required this.livekitUrl,
    required this.livekitToken,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Room? _room;
  bool _isConnecting = true;
  bool _isMicMuted = false;
  bool _isCameraDisabled = false;
  bool _hasRemoteParticipantJoined = false;
  bool _isFrontCamera = true;
  // Screen share
  StreamSubscription<CallSideEvent>? _sideEventSub;
  StreamSubscription<CallState>? _callStateSub;
  String _localUserId = '';
  String _localUserName = '';
  String _prevSharerUserId = '';

  @override
  void initState() {
    super.initState();
    // Resolve local user identity for screen share metadata
    final authState = getIt<AuthCubit>().state;
    if (authState is Authenticated) {
      _localUserId = authState.userData?['id']?.toString() ?? '';
      _localUserName = authState.userData?['phoneNumber']?.toString() ?? '';
    }

    if (widget.livekitToken.trim().isEmpty || widget.livekitUrl.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<CallCubit>();
      _sideEventSub = cubit.sideEvents.listen((event) {
        if (!mounted) return;
        if (event is CallScreenShareConflict) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${event.activeSharerName} is already sharing. Ask them to stop first.'),
          ));
        } else if (event is CallScreenShareDenied) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
              'Permission required to share your screen. Enable it in device settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ));
        }
      });
      // T027 — notify when a remote participant starts sharing (FR-011)
      _callStateSub = cubit.stream.listen((state) {
        if (!mounted) return;
        final newId = state is CallActive ? state.activeSharerUserId : '';
        if (newId.isNotEmpty && newId != _localUserId && _prevSharerUserId.isEmpty) {
          final name = state is CallActive ? state.activeSharerName : '';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$name started sharing their screen'),
            duration: const Duration(seconds: 2),
          ));
        }
        _prevSharerUserId = newId;
      });
    });

    _connectToRoom();
  }

  Future<void> _onScreenShareTap(BuildContext ctx) async {
    final cubit = ctx.read<CallCubit>();
    final s = cubit.state;
    if (s is CallActive && s.isLocallySharingScreen) {
      await cubit.stopScreenShare(localUserId: _localUserId, localUserName: _localUserName);
      return;
    }
    final withAudio = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => const ScreenShareToggleSheet(),
    );
    if (withAudio == null) return; // cancelled
    await cubit.startScreenShare(
      withDeviceAudio: withAudio,
      localUserId: _localUserId,
      localUserName: _localUserName,
    );
  }

  Future<void> _connectToRoom() async {
    try {
      // useiOSBroadcastExtension routes flutter_webrtc to FlutterBroadcastScreenCapturer (socket) not FlutterRPScreenRecorder.
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultScreenShareCaptureOptions:
              ScreenShareCaptureOptions(useiOSBroadcastExtension: true),
        ),
      );

      // Listen to peer connection events native to the LiveKit Room!
      _room!.addListener(_onRoomUpdate);

      await _room!.connect(widget.livekitUrl, widget.livekitToken);

      // Register the room with the repository so screen-share cubit actions work
      getIt<VideoCallRepository>().setExternalRoom(_room!);

      // Publish local media tracks immediately upon connecting
      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // Video calls should always default to speakerphone
      try {
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('Failed to set speakerphone: $e');
      }

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onRoomUpdate() {
    if (mounted) {
      // Track if they joined at least once
      if (_room != null && _room!.remoteParticipants.isNotEmpty) {
        _hasRemoteParticipantJoined = true;
      }

      final isDisconnected = _room?.connectionState == ConnectionState.disconnected;

      if (_room != null && !_isConnecting) {
        // Disconnect and pop ONLY if:
        // 1. The remote participant was here and left (isEmpty + joined flag) OR
        // 2. The entire room connection itself dropped.
        if ((_room!.remoteParticipants.isEmpty && _hasRemoteParticipantJoined) || isDisconnected) {
          _room?.disconnect();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          return;
        }
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sideEventSub?.cancel();
    _callStateSub?.cancel();
    getIt<VideoCallRepository>().setExternalRoom(null);
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting || _room == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text('Connecting to ${widget.contactName}...', style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final localParticipant = _room!.localParticipant;
    final remoteParticipant = _room!.remoteParticipants.values.firstOrNull;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _room?.disconnect();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<CallCubit, CallState>(
          builder: (context, callState) {
            final isSharing = callState is CallActive && callState.isLocallySharingScreen;
            final remoteSharerUserId = callState is CallActive ? callState.activeSharerUserId : '';
            final remoteSharerName = callState is CallActive ? callState.activeSharerName : '';
            final remoteSharerHasAudio = callState is CallActive && callState.activeSharerHasAudio;
            final isMutedLocally = callState is CallActive &&
                callState.mutedScreenAudioBySharerId.contains(remoteSharerUserId);
            final showRemoteTile = remoteSharerUserId.isNotEmpty && remoteSharerUserId != _localUserId;

            // Resolve remote screen-share video track at screen level (Constitution II)
            VideoTrack? remoteShareTrack;
            if (showRemoteTile) {
              final pub = getIt<VideoCallRepository>().screenShareVideoTrackOf(remoteSharerUserId);
              remoteShareTrack = pub?.track as VideoTrack?;
            }

            return Stack(
              children: [
                // Background - Remote VideoTrack
                Positioned.fill(
                  child: _ParticipantVideoView(
                    participant: remoteParticipant,
                    name: widget.contactName,
                  ),
                ),

                // T025 — Remote screen-share tile (shown as additional grid cell)
                if (showRemoteTile)
                  Positioned(
                    top: 60,
                    left: 20,
                    width: 120,
                    height: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ScreenShareTile(
                        videoTrack: remoteShareTrack,
                        participantName: remoteSharerName,
                        hasAudio: remoteSharerHasAudio,
                        isMutedLocally: isMutedLocally,
                        onMuteToggle: () => context
                            .read<CallCubit>()
                            .toggleReceivedScreenShareAudioMute(remoteSharerUserId),
                      ),
                    ),
                  ),

                // PiP - Local VideoTrack
                Positioned(
                  top: 60,
                  right: 20,
                  width: 120,
                  height: 180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _ParticipantVideoView(
                      participant: localParticipant,
                      isLocal: true,
                      name: 'Me',
                    ),
                  ),
                ),

                // T019 — "You are sharing" banner
                if (isSharing)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Material(
                      color: AppColors.primary,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.screen_share, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'You are sharing your screen',
                                  style: TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.read<CallCubit>().stopScreenShare(
                                      localUserId: _localUserId,
                                      localUserName: _localUserName,
                                    ),
                                child: const Text('Stop', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Control Bar
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isMicMuted ? Icons.mic_off : Icons.mic,
                            color: _isMicMuted ? Colors.red : Colors.white,
                          ),
                          onPressed: () async {
                            try {
                              final targetMuted = !_isMicMuted;
                              await _room!.localParticipant?.setMicrophoneEnabled(!targetMuted);
                              setState(() => _isMicMuted = targetMuted);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to toggle microphone: $e')),
                                );
                              }
                            }
                          },
                        ),
                        // T018 — Screen share icon
                        IconButton(
                          icon: Icon(
                            isSharing ? Icons.stop_screen_share : Icons.screen_share_outlined,
                            color: isSharing ? AppColors.primary : Colors.white,
                          ),
                          onPressed: () => _onScreenShareTap(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                          style: IconButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                            await context.read<CallCubit>().endCall();
                            await _room?.disconnect();
                            if (context.mounted) context.go(AppRouterName.home);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isCameraDisabled ? Icons.videocam_off : Icons.videocam,
                            color: _isCameraDisabled ? Colors.red : Colors.white,
                          ),
                          onPressed: () async {
                            try {
                              final targetDisabled = !_isCameraDisabled;
                              await _room!.localParticipant?.setCameraEnabled(!targetDisabled);
                              setState(() => _isCameraDisabled = targetDisabled);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to toggle camera: $e')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                          onPressed: () async {
                            try {
                              final track = _room!.localParticipant?.videoTrackPublications.firstOrNull?.track;
                              if (track is LocalVideoTrack) {
                                _isFrontCamera = !_isFrontCamera;
                                final options = CameraCaptureOptions(
                                  cameraPosition: _isFrontCamera ? CameraPosition.front : CameraPosition.back,
                                );
                                await track.restartTrack(options);
                                setState(() {});
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to switch camera: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ParticipantVideoView extends StatelessWidget {
  final Participant? participant;
  final bool isLocal;
  final String name;

  const _ParticipantVideoView({
    this.participant, 
    this.isLocal = false,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    if (participant == null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Text(
            isLocal ? 'Starting camera...' : 'Waiting for remote...',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final videoTrack = participant!.videoTrackPublications
        .where((pub) => pub.source == TrackSource.camera && pub.track is VideoTrack)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    if (videoTrack != null && !videoTrack.muted) {
      return VideoTrackRenderer(videoTrack);
    }

    return Container(
      color: Colors.grey[900],
      child: Center(
        child: CircleAvatar(
          radius: isLocal ? 40 : 80,
          backgroundColor: Colors.purple.withOpacity(0.6),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.white, 
              fontSize: isLocal ? 32 : 64,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
