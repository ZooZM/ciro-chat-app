import 'dart:async';
import 'dart:ui' as ui;
import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/services/call_audio_config.dart';
import 'package:ciro_chat_app/core/services/call_audio_session_service.dart';
import 'package:ciro_chat_app/core/services/audio_route_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/call_cubit.dart';
import '../widgets/audio_route_picker_sheet.dart';
import '../widgets/minimized_call.dart';

class VoiceCallScreen extends StatefulWidget {
  final String contactName;
  final String avatarInitials;
  final String livekitUrl;
  final String livekitToken;
  final bool initialMicMuted;
  final bool initialSpeakerOn;

  /// When restoring a minimized call, the already-connected room is handed back
  /// here so we reuse the same session instead of opening a new one.
  final Room? externalRoom;

  /// The moment the call actually started, preserved across minimize/restore so
  /// the timer keeps counting instead of resetting to 00:00.
  final DateTime? callStartedAt;

  /// LiveKit room name (`call_<a>_<b>` for 1:1) — used as the room id for live
  /// translation and screen-share signaling.
  final String roomName;

  const VoiceCallScreen({
    Key? key,
    required this.contactName,
    required this.avatarInitials,
    required this.livekitUrl,
    required this.livekitToken,
    this.initialMicMuted = false,
    this.initialSpeakerOn = false,
    this.externalRoom,
    this.callStartedAt,
    this.roomName = '',
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _roomEventsListener;
  bool _isConnecting = true;
  late bool _isMicMuted;
  bool _hasRemoteParticipantJoined = false;
  bool _isUpgrading = false;
  // True while handing the room off to the floating minimized window — dispose
  // must NOT disconnect the room in that case (mirrors _isUpgrading).
  bool _isMinimizing = false;
  late final AudioRouteService _audioRoute = getIt<AudioRouteService>();
  StreamSubscription<AudioRouteState>? _routeSub;
  AudioRouteState _routeState = const AudioRouteState();

  late final DateTime _callStartedAt;
  Timer? _uiTimer;

  // PIP offset (top-left corner by default)
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

  @override
  void initState() {
    super.initState();
    _callStartedAt = widget.callStartedAt ?? DateTime.now();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _isMicMuted = widget.initialMicMuted;
    _routeSub = _audioRoute.routeStream.listen((s) {
      if (mounted) setState(() => _routeState = s);
    });

    if (widget.externalRoom == null &&
        (widget.livekitToken.trim().isEmpty ||
            widget.livekitUrl.trim().isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _connectToRoom();
  }

  /// Collapses the call into the floating minimized window and leaves this
  /// screen. dispose() keeps the room alive (via [_isMinimizing]); the
  /// controller owns it until restored or ended.
  void _minimizeCall() {
    final room = _room;
    if (room == null) return;
    setState(() => _isMinimizing = true);
    MinimizedCallController.instance.minimize(
      room: room,
      contactName: widget.contactName,
      isVideo: false,
      livekitUrl: widget.livekitUrl,
      livekitToken: widget.livekitToken,
      startedAt: _callStartedAt,
    );
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _connectToRoom() async {
    try {
      // Restore path: reuse the still-connected room handed back from the
      // minimized floating window (audio + mic already live).
      final reusing = widget.externalRoom != null;
      if (reusing) {
        _room = widget.externalRoom;
        _isMicMuted =
            !(_room!.localParticipant?.isMicrophoneEnabled() ?? true);
      } else {
        await getIt<CallAudioSessionService>().configureForCall();
        _room = Room(roomOptions: CallAudioConfig.roomOptions());
      }
      _room!.addListener(_onRoomUpdate);

      if (!reusing) {
        await _room!.connect(widget.livekitUrl, widget.livekitToken);
      }

      // If the remote turns on their camera, follow them into the video UI so
      // both sides see video (the Room ChangeNotifier doesn't reliably fire on
      // remote track subscription, so listen explicitly).
      _roomEventsListener = _room!.createListener();
      _roomEventsListener!
        ..on<TrackSubscribedEvent>((e) {
          if (e.publication.source == TrackSource.camera) _upgradeToVideo();
        })
        ..on<TrackUnmutedEvent>((e) {
          if (e.publication.source == TrackSource.camera &&
              e.participant is RemoteParticipant) {
            _upgradeToVideo();
          }
        });

      // Publish local audio with initial state (already published when reusing).
      if (!reusing) {
        await _room!.localParticipant?.setMicrophoneEnabled(!_isMicMuted);
      }

      // Default audio route: voice calls → earpiece, BT takes precedence
      // (FR-VoIP-10). Output-only — never touches the 019 audio session.
      await _audioRoute.start();
      await _audioRoute.applyDefaultForCall(isVideo: false);

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Upgrades this voice call to the full video UI, reusing the live LiveKit
  /// [Room]. `dispose()` checks [_isUpgrading] and skips disconnecting so the
  /// session (and audio) survives the screen swap; the video screen enables the
  /// camera. Safe to call repeatedly — guarded by [_isUpgrading].
  Future<void> _upgradeToVideo() async {
    if (_isUpgrading || _room == null || _isConnecting) return;
    setState(() => _isUpgrading = true);
    try {
      await [Permission.camera].request();
    } catch (_) {}
    if (!mounted) return;
    context.pushReplacement(
      AppRouterName.videoCall,
      extra: {
        'contactName': widget.contactName,
        'livekitUrl': widget.livekitUrl,
        'livekitToken': widget.livekitToken,
        'externalRoom': _room,
        'callStartedAt': _callStartedAt,
      },
    );
  }

  void _onRoomUpdate() {
    if (mounted) {
      if (_room != null && _room!.remoteParticipants.isNotEmpty) {
        _hasRemoteParticipantJoined = true;
      }

      final isDisconnected =
          _room?.connectionState == ConnectionState.disconnected;

      if (_room != null && !_isConnecting) {
        if ((_room!.remoteParticipants.isEmpty &&
                _hasRemoteParticipantJoined) ||
            isDisconnected) {
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
    _room?.removeListener(_onRoomUpdate);
    _roomEventsListener?.dispose();
    _routeSub?.cancel();
    // Keep the room alive when handing it to the video screen (upgrade) or the
    // floating minimized window; otherwise tear it down.
    if (!_isUpgrading && !_isMinimizing) {
      _room?.disconnect();
      getIt<CallAudioSessionService>().deactivate();
      _audioRoute.stop();
    }
    super.dispose();
  }

  String get _elapsedLabel {
    final s = DateTime.now().difference(_callStartedAt);
    final mm = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null && !_isConnecting) {
      return const Scaffold(backgroundColor: Color(0xFFEA4071));
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await context.read<CallCubit>().endCall();
        await _room?.disconnect();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEA4071), // Solid dark pink background
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              // Tap empty space to toggle immersive mode. Child controls (buttons,
              // PIP) claim their own taps, so only background taps reach this.
              onTap: _toggleControls,
              behavior: HitTestBehavior.opaque,
              child: Stack(
            children: [
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
                          // Minimize the call into the floating window.
                          GestureDetector(
                            onTap: _minimizeCall,
                            behavior: HitTestBehavior.opaque,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 24.resR,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                    ),
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
                  child: CircleAvatar(
                    radius: 110.resR,
                    backgroundColor: Colors.transparent,
                    child: Text(
                      widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                      style: AppTypography.headline1.copyWith(
                        color: Colors.white,
                        fontSize: 64.resSp,
                      ),
                    ),
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
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: ClipRRect(
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
                                debugPrint('Failed to toggle mic: $e');
                              }
                            },
                          ),
                          _buildIconBtn(
                            icon: _routeState.activeRoute == AudioOutputRoute.speaker ? Icons.volume_up : Icons.volume_down,
                            isActive: _routeState.activeRoute == AudioOutputRoute.speaker,
                            onTap: () => AudioRoutePickerSheet.show(context),
                          ),
                          _buildIconBtn(
                            // Turning on the camera upgrades the call to the
                            // video UI (voice screen renders no video).
                            icon: Icons.videocam,
                            isActive: _isUpgrading,
                            onTap: _upgradeToVideo,
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
                              child: Icon(Icons.call_end, color: const Color(0xFFE33451), size: 26.resR),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                    ),
                  ),
                ),
              ),

              // PIP Avatar — draggable, snaps to the nearest corner on release.
              // Placed last so it stays on top of everything.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: _pipOffset.dx,
                top: _pipOffset.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      double newX = _pipOffset.dx + details.delta.dx;
                      double newY = _pipOffset.dy + details.delta.dy;
                      // clamp to the Stack bounds
                      newX = newX.clamp(0.0, constraints.maxWidth - _pipW.resR);
                      newY = newY.clamp(0.0, constraints.maxHeight - _pipH.resR);
                      _pipOffset = Offset(newX, newY);
                    });
                  },
                  onPanEnd: (_) => _snapPipToCorner(constraints),
                  child: Container(
                    width: _pipW.resR,
                    height: _pipH.resR,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF35C8D),
                      borderRadius: BorderRadius.circular(24.resR),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child: CircleAvatar(
                      radius: 35.resR,
                      backgroundColor: Colors.black12,
                      child: Text(
                        'Me',
                        style: AppTypography.headline2.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
              ),
            ),
          ),
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
