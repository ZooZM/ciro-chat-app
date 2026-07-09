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
import 'package:flutter_webrtc/flutter_webrtc.dart';
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

  // PIP offset
  Offset _pipOffset = const Offset(16, 110);

  bool _isEmojiOpen = false;
  int _selectedFilterIndex = 0;
  late PageController _filterPageController;

  @override
  void initState() {
    super.initState();
    _filterPageController = PageController(viewportFraction: 0.22);
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
      // Request permissions before connecting
      await [Permission.camera, Permission.microphone].request();

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
        })
        ..on<TrackMutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnmutedEvent>((_) {
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
    _filterPageController.dispose();
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
        backgroundColor: const Color(0xFF000000), // Darker background
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
        backgroundColor: const Color(0xFF000000),
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

            return Stack(
              children: [
                // Fullscreen Background Video
                Positioned.fill(
                  child: showRemoteTile
                      ? (remoteShareTrack != null
                          ? VideoTrackRenderer(
                              remoteShareTrack,
                              fit: VideoViewFit.cover,
                            )
                          : Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white54),
                              ),
                            ))
                      : _ParticipantVideoView(
                          participant: remoteParticipant,
                          name: widget.contactName,
                          isFullScreen: true,
                        ),
                ),
                SafeArea(
                  child: Stack(
                    children: [
                      // Top Bar
                      Positioned(
                        top: 16.resH,
                        left: 16.resW,
                        right: 16.resW,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 12.resH),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                   if (context.canPop()) context.pop();
                                },
                                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                              ),
                              SizedBox(width: 8.resW),
                              
                              // Avatar
                              CircleAvatar(
                                radius: 20.resW,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?', 
                                  style: const TextStyle(color: Colors.white)
                                ),
                              ),
                              
                              SizedBox(width: 12.resW),
                              
                              // Name & Timer
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.contactName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.resSp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _elapsedLabel, 
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13.resSp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Speaker Button
                              GestureDetector(
                                onTap: () => AudioRoutePickerSheet.show(context),
                                child: Container(
                                  width: 44.resW,
                                  height: 44.resW,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _routeState.activeRoute == AudioOutputRoute.speaker ? Icons.volume_up : Icons.volume_down,
                                    color: Colors.white,
                                    size: 22.resW,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.resW),
                              
                              // End Call Button
                              GestureDetector(
                                onTap: () async {
                                  await context.read<CallCubit>().endCall();
                                  await _room?.disconnect();
                                  if (context.mounted) context.go(AppRouterName.home);
                                },
                                child: Container(
                                  width: 44.resW,
                                  height: 44.resW,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.call_end,
                                    color: Colors.white,
                                    size: 22.resW,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        left: _pipOffset.dx,
                        top: _pipOffset.dy,
                        child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      final size = MediaQuery.of(context).size;
                      double newX = _pipOffset.dx + details.delta.dx;
                      double newY = _pipOffset.dy + details.delta.dy;
                      
                      final maxX = (size.width - 100.resR) > 0.0 ? (size.width - 100.resR) : 0.0;
                      final maxY = (size.height - 170.resR) > 0.0 ? (size.height - 170.resR) : 0.0;
                      
                      newX = newX.clamp(0.0, maxX);
                      newY = newY.clamp(0.0, maxY);
                      
                      _pipOffset = Offset(newX, newY);
                    });
                  },
                  child: AbsorbPointer(
                    child: Container(
                              width: 100.resR,
                              height: 170.resR,
                              decoration: BoxDecoration(
                                color: Colors.transparent, 
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
                        ),
                      ),

                      // Bottom Controls & Filters
                      Positioned(
                        bottom: 24.resH,
                        left: 16.resW,
                        right: 16.resW,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Horizontal Filter Selection List
                            if (_isEmojiOpen)
                              Container(
                                height: 90.resR,
                                margin: EdgeInsets.only(bottom: 16.resH),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PageView.builder(
                                      controller: _filterPageController,
                                      onPageChanged: (index) {
                                        setState(() {
                                          _selectedFilterIndex = index;
                                        });
                                      },
                                      itemCount: 10,
                                      itemBuilder: (context, index) {
                                        final isSelected = _selectedFilterIndex == index;
                                        // The image fits inside the ring
                                        final size = isSelected ? 65.resR : 55.resR;

                                        if (index == 0) {
                                          // Empty state (no filter)
                                          return const SizedBox();
                                        }

                                        return Center(
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: size,
                                            height: size,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: DecorationImage(
                                                image: NetworkImage('https://picsum.photos/seed/${index + 40}/100/100'),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    
                                    // Fixed White Ring in the center
                                    IgnorePointer(
                                      child: Container(
                                        width: 75.resR,
                                        height: 75.resR,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white, 
                                            width: 4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                            // Pre-join status text
                            Text(
                              'Friends can see you before joining',
                              style: TextStyle(color: Colors.white, fontSize: 13.resSp),
                            ),
                            SizedBox(height: 16.resH),

                            // Bottom Glassmorphism Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(40.resR),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12.resH, horizontal: 16.resW),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildIconBtn(
                                        icon: _isCameraDisabled ? Icons.videocam_off : Icons.videocam_outlined,
                                        isActive: _isCameraDisabled,
                                        onTap: () async {
                                          try {
                                            final targetDisabled = !_isCameraDisabled;
                                            await _room!.localParticipant?.setCameraEnabled(!targetDisabled);
                                            setState(() => _isCameraDisabled = targetDisabled);
                                          } catch (e) {
                                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                          }
                                        },
                                      ),
                                      _buildIconBtn(
                                        icon: Icons.cameraswitch_outlined,
                                        isActive: false,
                                        onTap: () async {
                                          try {
                                            final track = _room!.localParticipant?.videoTrackPublications
                                                .where((p) => p.source == TrackSource.camera)
                                                .firstOrNull?.track as LocalVideoTrack?;
                                            if (track != null) {
                                              await Helper.switchCamera(track.mediaStreamTrack);
                                              setState(() => _isFrontCamera = !_isFrontCamera);
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
                                      _buildIconBtn(
                                        icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
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
                                        icon: Icons.emoji_emotions_outlined,
                                        isActive: _isEmojiOpen,
                                        activeBgColor: Colors.white,
                                        activeIconColor: Colors.black,
                                        onTap: () {
                                          setState(() => _isEmojiOpen = !_isEmojiOpen);
                                        },
                                      ),
                                      _buildIconBtn(
                                        icon: Icons.menu,
                                        isActive: false,
                                        onTap: () {},
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon, 
    required VoidCallback onTap, 
    bool isActive = false,
    Color? activeBgColor,
    Color? activeIconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52.resR,
        height: 52.resR,
        decoration: BoxDecoration(
          color: isActive 
            ? (activeBgColor ?? Colors.white.withOpacity(0.4)) 
            : Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon, 
          color: isActive ? (activeIconColor ?? Colors.white) : Colors.white, 
          size: 26.resR,
        ),
      ),
    );
  }
}

class _ParticipantVideoView extends StatelessWidget {
  final Participant? participant;
  final bool isLocal;
  final String name;
  final bool isFullScreen;

  const _ParticipantVideoView({
    super.key,
    this.participant, 
    this.isLocal = false,
    required this.name,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (participant == null) {
      return Container(
        color: isFullScreen ? Colors.transparent : Colors.grey[900],
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
      return VideoTrackRenderer(
        videoTrack,
        fit: isFullScreen ? VideoViewFit.cover : VideoViewFit.contain,
      );
    }

    return Container(
      color: isFullScreen ? Colors.transparent : Colors.grey[900],
      child: Center(
        child: CircleAvatar(
          radius: isLocal ? 40 : (isFullScreen ? 100 : 80),
          backgroundColor: Colors.purple.withOpacity(0.6),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.white, 
              fontSize: isLocal ? 32 : (isFullScreen ? 80 : 64),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
