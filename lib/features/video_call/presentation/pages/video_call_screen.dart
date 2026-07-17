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
import 'package:easy_localization/easy_localization.dart';
import '../widgets/audio_route_picker_sheet.dart';
import '../widgets/minimized_call.dart';
import '../widgets/call_more_options_sheet.dart';
import '../../../translation/domain/entities/supported_languages.dart';
import '../../../translation/domain/entities/translation_subscription.dart';
import '../../../translation/presentation/bloc/translation_cubit.dart';
import '../../../translation/presentation/widgets/translation_toggle_sheet.dart';
import '../../../translation/presentation/widgets/subtitle_overlay_widget.dart';

class VideoCallScreen extends StatefulWidget {
  final String contactName;
  final String livekitUrl;
  final String livekitToken;

  /// When a voice call is upgraded to video, the already-connected LiveKit
  /// [Room] is handed over here so we reuse the same session (same identity /
  /// tracks) instead of opening a second connection.
  final Room? externalRoom;

  /// Call start time, preserved across minimize/restore so the timer continues.
  final DateTime? callStartedAt;

  /// LiveKit room name (`call_<a>_<b>` for 1:1) — used as the room id for live
  /// translation and screen-share signaling.
  final String roomName;

  /// Voice calls reuse this screen with the camera off (audio-only). Enabling
  /// the camera from the control bar turns it into a normal video call.
  final bool startWithCamera;

  const VideoCallScreen({
    super.key,
    required this.contactName,
    required this.livekitUrl,
    required this.livekitToken,
    this.externalRoom,
    this.callStartedAt,
    this.roomName = '',
    this.startWithCamera = true,
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
  // True while handing the room off to the floating minimized window — dispose
  // must NOT disconnect the room in that case.
  bool _isMinimizing = false;

  // Guards against disconnecting the LiveKit room twice (PopScope + dispose both
  // fire when the peer ends the call), which double-completes the SDK's internal
  // completer → "Bad state: Future already completed".
  bool _roomDisconnected = false;
  void _disconnectRoom() {
    if (_roomDisconnected) return;
    _roomDisconnected = true;
    _room?.disconnect();
  }
  // Live translation (reuses the group-call subsystem for the 1:1 remote party).
  late final TranslationCubit _translationCubit = getIt<TranslationCubit>();
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
  late final DateTime _callStartedAt;
  Timer? _uiTimer;

  // PIP offset
  Offset _pipOffset = const Offset(16, 110);

  // Immersive mode: tap the screen to hide the top bar + bottom controls.
  bool _controlsVisible = true;

  static const double _pipW = 100;
  static const double _pipH = 170;

  void _toggleControls() =>
      setState(() => _controlsVisible = !_controlsVisible);

  /// Snaps the PIP to whichever of the four corners it is nearest, clear of the
  /// top bar and bottom control bar. [c] is the Stack's real size.
  void _snapPipToCorner(BoxConstraints c) {
    final w = _pipW.resR;
    final h = _pipH.resR;
    final margin = 16.resW;
    final leftX = margin;
    final rightX = c.maxWidth - w - margin;
    final topY = 100.resH; // below the top bar
    final bottomY = c.maxHeight - h - 110.resH; // above the control bar
    final centerX = _pipOffset.dx + w / 2;
    final centerY = _pipOffset.dy + h / 2;
    setState(() {
      _pipOffset = Offset(
        centerX < c.maxWidth / 2 ? leftX : rightX,
        centerY < c.maxHeight / 2 ? topY : bottomY,
      );
    });
  }

  bool _isEmojiOpen = false;
  int _selectedFilterIndex = 0;
  late PageController _filterPageController;

  @override
  void initState() {
    super.initState();
    _filterPageController = PageController(viewportFraction: 0.22);
    _callStartedAt = widget.callStartedAt ?? DateTime.now();
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
    // Only one participant may share at a time.
    if (s is CallActive &&
        s.activeSharerUserId.isNotEmpty &&
        s.activeSharerUserId != _localUserId) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${s.activeSharerName} is already sharing')),
        );
      }
      return;
    }
    // Start immediately, no audio (no toggle sheet).
    await cubit.startScreenShare(
      withDeviceAudio: false,
      localUserId: _localUserId,
      localUserName: _localUserName,
    );
  }

  /// The ≡ More menu — Share Screen + Translate.
  void _showMoreOptions() {
    final s = context.read<CallCubit>().state;
    final isSharing = s is CallActive && s.isLocallySharingScreen;
    final isTranslating = _translationCubit.state.subscriptions.values
        .any((x) => x.status != TranslationStatus.off);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => CallMoreOptionsSheet(
        title: widget.contactName,
        isSharing: isSharing,
        isTranslating: isTranslating,
        onShareScreen: () {
          Navigator.pop(sheetCtx);
          _onScreenShareTap(context);
        },
        onTranslate: () {
          Navigator.pop(sheetCtx);
          _onTapTranslate();
        },
      ),
    );
  }

  /// Opens [TranslationToggleSheet] for the 1:1 remote participant and applies
  /// subscribe / changeLanguage / unsubscribe — same flow as group calls.
  Future<void> _onTapTranslate() async {
    final remote = _room?.remoteParticipants.values.firstOrNull;
    if (remote == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No one to translate yet')),
        );
      }
      return;
    }
    final speakerId = remote.identity;
    final sub = _translationCubit.state.subscriptions[speakerId];
    final isEnabled = sub != null && sub.status != TranslationStatus.off;
    final initialLanguage = _translationCubit.resolveTargetLanguage(
      speakerId,
      deviceLanguageCode: context.locale.languageCode,
      supportedLanguages: kSupportedTranslationLanguages,
    );
    final result = await showModalBottomSheet<TranslationToggleResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TranslationToggleSheet(
        isEnabled: isEnabled,
        initialLanguage: initialLanguage,
      ),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case TranslationToggleOn(targetLanguage: final lang):
        if (!isEnabled) {
          _translationCubit.subscribe(speakerId: speakerId, targetLanguage: lang);
        } else if (sub.targetLanguage != lang) {
          _translationCubit.changeLanguage(
              speakerId: speakerId, targetLanguage: lang);
        }
      case TranslationToggleOff():
        if (isEnabled) _translationCubit.unsubscribe(speakerId);
    }
  }

  Future<void> _connectToRoom() async {
    try {
      // Upgrade path: reuse the voice call's already-connected room. The audio
      // session + mic are already live from the voice screen, so only the
      // camera permission is needed here.
      final reusing = widget.externalRoom != null;

      if (reusing) {
        _room = widget.externalRoom;
        // Preserve the mic + camera state carried over from the reused session.
        _isMicMuted = !(_room!.localParticipant?.isMicrophoneEnabled() ?? true);
        _isCameraDisabled =
            !(_room!.localParticipant?.isCameraEnabled() ?? false);
      } else {
        // Request only what this call needs: camera+mic for video, mic-only for
        // a voice call (camera can be enabled later from the control bar).
        await (widget.startWithCamera
                ? [Permission.camera, Permission.microphone]
                : [Permission.microphone])
            .request();

        // Configure the OS voice-communication audio session BEFORE connecting
        // (FR-Audio-01, SC-003).
        await getIt<CallAudioSessionService>().configureForCall();

        // useiOSBroadcastExtension routes flutter_webrtc to FlutterBroadcastScreenCapturer (socket) not FlutterRPScreenRecorder.
        _room = Room(roomOptions: CallAudioConfig.roomOptions());
      }

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

      // Skip connect when reusing the voice call's already-connected room.
      if (!reusing) {
        await _room!.connect(widget.livekitUrl, widget.livekitToken);
      }

      // Register the room with the repository so screen-share cubit actions work
      getIt<VideoCallRepository>().setExternalRoom(_room!);

      // Attach live translation to this room (no-op until the user enables it
      // from the ≡ More menu). roomName is the 1:1 LiveKit room id.
      if (widget.roomName.isNotEmpty) {
        _translationCubit.attachRoom(_room!, roomId: widget.roomName);
      }

      // Start the Android call foreground service so the OS doesn't suspend
      // mic/camera when the screen locks. No-op on iOS.
      getIt<VideoCallRepository>().setCallServiceActive(true);

      // Publish local media for a fresh call. When reusing, the tracks are
      // already published — leave them (camera state preserved above).
      if (!reusing) {
        if (widget.startWithCamera) {
          await _room!.localParticipant?.setCameraEnabled(true);
          _isCameraDisabled = false;
        } else {
          _isCameraDisabled = true; // voice call — camera off
        }
        await _room!.localParticipant?.setMicrophoneEnabled(true);
      }

      // Video → speakerphone, voice → earpiece; BT takes precedence (FR-VoIP-10).
      // Output-only — never touches the 019 audio session.
      await _audioRoute.start();
      await _audioRoute.applyDefaultForCall(isVideo: !_isCameraDisabled);

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
          _disconnectRoom();
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
    _sideEventSub?.cancel();
    _callStateSub?.cancel();
    _routeSub?.cancel();
    _roomEventsListener?.dispose();
    _translationCubit.detachRoom();
    _translationCubit.close();
    _room?.removeListener(_onRoomUpdate);
    // Keep the room alive when handing it to the floating minimized window.
    if (!_isMinimizing) {
      getIt<VideoCallRepository>().setCallServiceActive(false);
      getIt<VideoCallRepository>().setExternalRoom(null);
      _disconnectRoom();
      getIt<CallAudioSessionService>().deactivate();
      _audioRoute.stop();
    }
    super.dispose();
  }

  /// Collapses the call into the floating minimized window and leaves this
  /// screen. dispose() keeps the room alive via [_isMinimizing].
  void _minimizeCall() {
    final room = _room;
    if (room == null) return;
    setState(() => _isMinimizing = true);
    MinimizedCallController.instance.minimize(
      room: room,
      contactName: widget.contactName,
      isVideo: true,
      livekitUrl: widget.livekitUrl,
      livekitToken: widget.livekitToken,
      startedAt: _callStartedAt,
    );
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  String get _elapsedLabel {
    final s = DateTime.now().difference(_callStartedAt);
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
        // Skip while minimizing — the room must stay alive for the floating window.
        if (didPop || _isMinimizing) return;
        _disconnectRoom();
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
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                    children: [
                      // Tap empty space to toggle immersive controls (child
                      // buttons/PIP claim their own taps).
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _toggleControls,
                          behavior: HitTestBehavior.opaque,
                        ),
                      ),
                      // Top Bar
                      Positioned(
                        top: 16.resH,
                        left: 16.resW,
                        right: 16.resW,
                        child: IgnorePointer(
                          ignoring: !_controlsVisible,
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 12.resH),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                // Minimize the call into the floating window.
                                onTap: _minimizeCall,
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
                                  _disconnectRoom();
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
                        ),
                      ),

                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        left: _pipOffset.dx,
                        top: _pipOffset.dy,
                        child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanEnd: (_) => _snapPipToCorner(constraints),
                  onPanUpdate: (details) {
                    setState(() {
                      double newX = _pipOffset.dx + details.delta.dx;
                      double newY = _pipOffset.dy + details.delta.dy;

                      final maxX = (constraints.maxWidth - _pipW.resR) > 0.0
                          ? (constraints.maxWidth - _pipW.resR)
                          : 0.0;
                      final maxY = (constraints.maxHeight - _pipH.resR) > 0.0
                          ? (constraints.maxHeight - _pipH.resR)
                          : 0.0;

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

                      // Live translation captions (subscribed via ≡ → Translate)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 130.resH,
                        child: IgnorePointer(
                          child: SubtitleOverlayWidget(
                            transcript: _translationCubit.transcriptList,
                            participants:
                                _room?.remoteParticipants.values.toList() ??
                                    const [],
                          ),
                        ),
                      ),

                      // Bottom Controls & Filters
                      Positioned(
                        bottom: 24.resH,
                        left: 16.resW,
                        right: 16.resW,
                        child: IgnorePointer(
                          ignoring: !_controlsVisible,
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1 : 0,
                            duration: const Duration(milliseconds: 220),
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
                                            // Enabling from a voice call: ensure camera permission,
                                            // then switch output to speaker (video default).
                                            if (!targetDisabled) {
                                              await [Permission.camera].request();
                                            }
                                            await _room!.localParticipant?.setCameraEnabled(!targetDisabled);
                                            await _audioRoute.applyDefaultForCall(isVideo: !targetDisabled);
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
                                        onTap: _showMoreOptions,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                          ),
                        ),
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
