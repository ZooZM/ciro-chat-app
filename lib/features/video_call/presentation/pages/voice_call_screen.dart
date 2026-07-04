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

class VoiceCallScreen extends StatefulWidget {
  final String contactName;
  final String avatarInitials;
  final String livekitUrl;
  final String livekitToken;
  final bool initialMicMuted;
  final bool initialSpeakerOn;

  const VoiceCallScreen({
    Key? key,
    required this.contactName,
    required this.avatarInitials,
    required this.livekitUrl,
    required this.livekitToken,
    this.initialMicMuted = false,
    this.initialSpeakerOn = false,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Room? _room;
  bool _isConnecting = true;
  late bool _isMicMuted;
  bool _hasRemoteParticipantJoined = false;
  bool _isUpgrading = false;
  late final AudioRouteService _audioRoute = getIt<AudioRouteService>();
  StreamSubscription<AudioRouteState>? _routeSub;
  AudioRouteState _routeState = const AudioRouteState();

  late final Stopwatch _callTimer;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _callTimer = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _isMicMuted = widget.initialMicMuted;
    _routeSub = _audioRoute.routeStream.listen((s) {
      if (mounted) setState(() => _routeState = s);
    });

    if (widget.livekitToken.trim().isEmpty ||
        widget.livekitUrl.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    try {
      await getIt<CallAudioSessionService>().configureForCall();
      _room = Room(roomOptions: CallAudioConfig.roomOptions());
      _room!.addListener(_onRoomUpdate);

      await _room!.connect(widget.livekitUrl, widget.livekitToken);

      // Publish local audio with initial state
      await _room!.localParticipant?.setMicrophoneEnabled(!_isMicMuted);

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
    _callTimer.stop();
    _room?.removeListener(_onRoomUpdate);
    _routeSub?.cancel();
    if (!_isUpgrading) {
      _room?.disconnect();
      getIt<CallAudioSessionService>().deactivate();
      _audioRoute.stop();
    }
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildIconBtn(
                            icon: Icons.arrow_upward_rounded,
                            onTap: () {},
                          ),
                          _buildIconBtn(
                            icon: Icons.sentiment_satisfied_alt,
                            onTap: () => AudioRoutePickerSheet.show(context),
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
                                debugPrint('Failed to toggle mic: $e');
                              }
                            },
                          ),
                          _buildIconBtn(
                            icon: Icons.sync,
                            onTap: () {},
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
            ],
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
