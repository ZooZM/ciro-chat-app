import 'dart:async';
import 'dart:ui' as ui;
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:ciro_chat_app/core/services/audio_route_service.dart';
import 'package:ciro_chat_app/core/services/call_audio_config.dart';
import 'package:ciro_chat_app/core/services/call_audio_session_service.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../bloc/call_cubit.dart';
import '../widgets/audio_route_picker_sheet.dart';
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
  EventsListener<RoomEvent>? _roomEventsListener;
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
  late final AudioRouteService _audioRoute = getIt<AudioRouteService>();
  StreamSubscription<AudioRouteState>? _routeSub;
  AudioRouteState _routeState = const AudioRouteState();

  // Timer
  late final Stopwatch _callTimer;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _callTimer = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Resolve local user identity for screen share metadata
    final authState = getIt<AuthCubit>().state;
    if (authState is Authenticated) {
      // verifyOtp returns the user under a nested 'user' map (MongoDB
      // convention: '_id'). Fall back to the top-level map and to 'id' for
      // safety if the backend shape ever flattens.
      final user =
          (authState.userData?['user'] as Map<String, dynamic>?) ??
          authState.userData;
      _localUserId =
          (user?['_id'] ?? user?['id'])?.toString() ?? '';
      _localUserName = user?['phoneNumber']?.toString() ?? '';
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
        } else if (event is CallMuteRequested) {
          // C1 — native CallKit mute toggle reflected onto the LiveKit track.
          _room?.localParticipant?.setMicrophoneEnabled(!event.muted);
          if (mounted) setState(() => _isMicMuted = event.muted);
        }
      });
      _routeSub = _audioRoute.routeStream.listen((s) {
        if (mounted) setState(() => _routeState = s);
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
      // Configure the OS voice-communication audio session BEFORE connecting
      // (FR-Audio-01, SC-003).
      await getIt<CallAudioSessionService>().configureForCall();

      // useiOSBroadcastExtension routes flutter_webrtc to FlutterBroadcastScreenCapturer (socket) not FlutterRPScreenRecorder.
      _room = Room(roomOptions: CallAudioConfig.roomOptions());

      // Listen to peer connection events native to the LiveKit Room!
      _room!.addListener(_onRoomUpdate);

      // Local track publish/unpublish and remote subscribe events don't always
      // fire the Room ChangeNotifier — listen explicitly so the UI rebuilds
      // when the iOS broadcast extension publishes the screen share track
      // asynchronously after the user picks it in the system picker.
      _roomEventsListener = _room!.createListener();
      _roomEventsListener!
        ..on<LocalTrackPublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<LocalTrackUnpublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackSubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        });

      await _room!.connect(widget.livekitUrl, widget.livekitToken);

      // Register the room with the repository so screen-share cubit actions work
      getIt<VideoCallRepository>().setExternalRoom(_room!);

      // Start the Android call foreground service so the OS doesn't suspend
      // mic/camera when the screen locks. No-op on iOS.
      getIt<VideoCallRepository>().setCallServiceActive(true);

      // Publish local media tracks immediately upon connecting
      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // Video calls default to speakerphone; BT takes precedence (FR-VoIP-10).
      // Output-only — never touches the 019 audio session.
      await _audioRoute.start();
      await _audioRoute.applyDefaultForCall(isVideo: true);

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
    _uiTimer?.cancel();
    _callTimer.stop();
    _sideEventSub?.cancel();
    _callStateSub?.cancel();
    _routeSub?.cancel();
    _roomEventsListener?.dispose();
    getIt<VideoCallRepository>().setCallServiceActive(false);
    getIt<VideoCallRepository>().setExternalRoom(null);
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    getIt<CallAudioSessionService>().deactivate();
    _audioRoute.stop();
    super.dispose();
  }

  String get _elapsedLabel {
    final s = _callTimer.elapsed;
    final mm = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting || _room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFEA4071),
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
        backgroundColor: const Color(0xFFEA4071), // Solid dark pink background
        body: BlocBuilder<CallCubit, CallState>(
          builder: (context, callState) {
            final isSharing = callState is CallActive && callState.isLocallySharingScreen;

            String remoteSharerUserId = '';
            String remoteSharerName = '';
            VideoTrack? remoteShareTrack;
            bool remoteSharerHasAudio = false;
            if (_room != null) {
              for (final p in _room!.remoteParticipants.values) {
                final videoPub = p.videoTrackPublications
                    .where((pub) => pub.source == TrackSource.screenShareVideo)
                    .firstOrNull;
                if (videoPub != null) {
                  remoteSharerUserId = p.identity;
                  remoteSharerName = p.name.isNotEmpty ? p.name : p.identity;
                  final t = videoPub.track;
                  if (t is VideoTrack) remoteShareTrack = t;
                  remoteSharerHasAudio = p.audioTrackPublications
                      .any((a) => a.source == TrackSource.screenShareAudio);
                  break;
                }
              }
            }
            final showRemoteTile = remoteSharerUserId.isNotEmpty;
            final isMutedLocally = callState is CallActive &&
                callState.mutedScreenAudioBySharerId.contains(remoteSharerUserId);

            VideoTrack? localShareTrack;
            if (isSharing) {
              final local = _room?.localParticipant;
              if (local != null) {
                var pub = local.videoTrackPublications
                    .where((p) => p.source == TrackSource.screenShareVideo)
                    .firstOrNull;
                pub ??= local.videoTrackPublications
                    .where((p) => p.source != TrackSource.camera)
                    .firstOrNull;
                final t = pub?.track;
                if (t is VideoTrack) localShareTrack = t;
              }
            }

            return SafeArea(
              child: Stack(
                children: [
                  // Top Bar
                  Positioned(
                    top: 16.resH,
                    left: 16.resW,
                    right: 16.resW,
                    child: Container(
                      height: 72.resH,
                      padding: EdgeInsets.symmetric(horizontal: 12.resW),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(40.resR),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Checkmark
                          GestureDetector(
                            onTap: () async {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Container(
                              width: 44.resR,
                              height: 44.resR,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5395A), // Solid dark red
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 26.resR,
                              ),
                            ),
                          ),
                          
                          // Right: Info and Avatar
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.chevron_left,
                                        color: Colors.white,
                                        size: 20.resR,
                                      ),
                                      SizedBox(width: 4.resW),
                                      Text(
                                        widget.contactName,
                                        style: AppTypography.subtitle1.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18.resSp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _elapsedLabel,
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white70,
                                      fontSize: 13.resSp,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 12.resW),
                              CircleAvatar(
                                radius: 20.resR,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                                  style: AppTypography.subtitle2.copyWith(
                                    color: Colors.white,
                                    fontSize: 14.resSp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4.resW),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 24.resR,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Screen share per-receiver audio mute (top-right under the pill)
                  if (showRemoteTile && remoteSharerHasAudio)
                    Positioned(
                      top: 70,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => context
                            .read<CallCubit>()
                            .toggleReceivedScreenShareAudioMute(remoteSharerUserId),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isMutedLocally ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                  // PIP Avatar (Left)
                  Positioned(
                    left: 16.resW,
                    top: 110.resH,
                    child: Container(
                      width: 100.resR,
                      height: 170.resR,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF35C8D),
                        borderRadius: BorderRadius.circular(24.resR),
                      ),
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      child: isSharing
                        ? (localShareTrack != null
                            ? VideoTrackRenderer(localShareTrack)
                            : Container(
                                color: Colors.black87,
                                child: const Center(
                                  child: Icon(Icons.screen_share, color: Colors.white),
                                ),
                              ))
                        : _ParticipantVideoView(
                          participant: localParticipant,
                          isLocal: true,
                          name: 'Me',
                        ),
                    ),
                  ),

                  // Large Center Avatar
                  Center(
                    child: Container(
                      width: 280.resR,
                      height: 280.resR,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.12),
                      ),
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      child: showRemoteTile
                          ? (remoteShareTrack != null
                              ? VideoTrackRenderer(remoteShareTrack)
                              : Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white54),
                                  ),
                                ))
                          : _ParticipantVideoView(
                              participant: remoteParticipant,
                              name: widget.contactName,
                            ),
                    ),
                  ),

                  // Bottom White Circle
                  Positioned(
                    bottom: 150.resH,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 80.resR,
                        height: 80.resR,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4.5.resR),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Control Bar
                  Positioned(
                    bottom: 24.resH,
                    left: 16.resW,
                    right: 16.resW,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40.resR),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.resH, horizontal: 16.resW),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildIconBtn(
                                  icon: isSharing ? Icons.stop_screen_share : Icons.arrow_upward_rounded,
                                  isActive: isSharing,
                                  onTap: () => _onScreenShareTap(context),
                                ),
                                _buildIconBtn(
                                  icon: Icons.sentiment_satisfied_alt,
                                  onTap: () {
                                    // Smiley face action (could be reactions or audio route picker)
                                    AudioRoutePickerSheet.show(context);
                                  },
                                ),
                                _buildIconBtn(
                                  icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                                  isActive: _isMicMuted,
                                  onTap: () async {
                                    try {
                                      final targetMuted = !_isMicMuted;
                                      await _room!.localParticipant?.setMicrophoneEnabled(!targetMuted);
                                      if (!mounted) return;
                                      context.read<CallCubit>().reportLocalMute(targetMuted);
                                      setState(() => _isMicMuted = targetMuted);
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                    }
                                  },
                                ),
                                _buildIconBtn(
                                  icon: Icons.sync,
                                  onTap: () async {
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
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                    }
                                  },
                                ),
                                // End call button
                                GestureDetector(
                                  onTap: () async {
                                    await context.read<CallCubit>().endCall();
                                    await _room?.disconnect();
                                    if (context.mounted) context.go(AppRouterName.home);
                                  },
                                  child: Container(
                                    width: 52.resR,
                                    height: 52.resR,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.videocam_off, color: const Color(0xFFE33451), size: 26.resR),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconBtn({required IconData icon, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52.resR,
        height: 52.resR,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24.resR),
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
