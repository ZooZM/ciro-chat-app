import 'dart:async';

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

  @override
  void initState() {
    super.initState();
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
    _room?.removeListener(_onRoomUpdate);
    _routeSub?.cancel();
    if (!_isUpgrading) {
      _room?.disconnect();
      getIt<CallAudioSessionService>().deactivate();
      _audioRoute.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null && !_isConnecting) {
      return const Scaffold(backgroundColor: Color(0xFF555555));
    }

    final isConnected =
        !_isConnecting && _room != null && _hasRemoteParticipantJoined;

    // (Removed the black screen transition here as per user's request for inline button update)

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await context.read<CallCubit>().endCall();
        await _room?.disconnect();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(
          0xFF555555,
        ), // Dark grey background matching the image
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Avatar
              CircleAvatar(
                radius: 65.resR,
                backgroundColor: const Color(0xFF8E6FB1), // Muted purple
                child: Text(
                  widget.avatarInitials,
                  style: AppTypography.headline1.copyWith(
                    color: Colors.white,
                    fontSize: 50,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 24.resH),
              // Name
              Text(
                widget.contactName,
                style: AppTypography.headline3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 8.resH),
              // Calling Status
              Text(
                _isConnecting
                    ? 'Connecting...'
                    : (!isConnected ? 'Ringing...' : 'Connected'),
                style: AppTypography.body1.copyWith(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),

              const Spacer(flex: 4),

              // ── Bottom Controls ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute / Mic Toggle
                  _buildControlButton(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    _isMicMuted ? Colors.white : Colors.white24,
                    _isMicMuted ? Colors.red : Colors.white,
                    onPressed: () async {
                      try {
                        final targetMuted = !_isMicMuted;
                        await _room!.localParticipant?.setMicrophoneEnabled(
                          !targetMuted,
                        );
                        if (!mounted) return;
                        context.read<CallCubit>().reportLocalMute(targetMuted);
                        setState(() => _isMicMuted = targetMuted);
                      } catch (e) {
                        debugPrint('Failed to toggle mic: $e');
                      }
                    },
                  ),
                  SizedBox(width: 24.resW),
                  // Audio route — opens the Earpiece/Speaker/Bluetooth picker
                  // (FR-VoIP-07); icon reflects the active route (FR-VoIP-08).
                  _buildControlButton(
                    speakerIconForRoute(_routeState.activeRoute),
                    _routeState.activeRoute == AudioOutputRoute.earpiece
                        ? Colors.white24
                        : Colors.white,
                    _routeState.activeRoute == AudioOutputRoute.earpiece
                        ? Colors.white
                        : Colors.green,
                    onPressed: () => AudioRoutePickerSheet.show(context),
                  ),
                  SizedBox(width: 24.resW),
                  // Video Upgrade
                  _isUpgrading
                      ? Container(
                          width: 60.resW,
                          height: 60.resW,
                          decoration: const BoxDecoration(
                            color: Colors.green, // Primary color when activated
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                      : _buildControlButton(
                          Icons.videocam_off, // Starts as videocam_off
                          Colors.white24, // Greyish background initially
                          Colors.white,
                          onPressed: () async {
                            if (context.mounted) {
                              final status = await Permission.camera.request();
                              if (status.isGranted) {
                                setState(() => _isUpgrading = true);
                                try {
                                  // Enable camera and simulate connection delay
                                  await Future.wait([
                                    _room?.localParticipant?.setCameraEnabled(
                                          true,
                                        ) ??
                                        Future.value(),
                                    Future.delayed(const Duration(seconds: 1)),
                                  ]);
                                } catch (e) {
                                  debugPrint(
                                    'Failed to enable camera before upgrade: $e',
                                  );
                                }

                                if (context.mounted) {
                                  // Navigate to VideoCallScreen
                                  context.pushReplacement(
                                    AppRouterName.videoCall,
                                    extra: {
                                      'contactName': widget.contactName,
                                      'livekitUrl': widget.livekitUrl,
                                      'livekitToken': widget.livekitToken,
                                    },
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Camera permission is required to switch to video.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                ],
              ),
              SizedBox(height: 32.resH),

              // ── End Call Button ──────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.resW),
                child: SizedBox(
                  width: double.infinity,
                  height: 56.resH,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await context.read<CallCubit>().endCall();
                      await _room?.disconnect();
                      if (context.mounted) context.go(AppRouterName.home);
                    },
                    icon: const Icon(Icons.phone_missed, color: Colors.white),
                    label: const Text(
                      'End Call',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFFE53935,
                      ), // Exact red from design
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.resR),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 48.resH),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    Color bgColor,
    Color iconColor, {
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60.resW,
        height: 60.resW,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Center(
          child: Icon(icon, color: iconColor, size: 28.resW),
        ),
      ),
    );
  }
}
