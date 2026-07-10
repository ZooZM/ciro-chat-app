import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import '../bloc/call_cubit.dart';

// ─── Design tokens (match mockup) ────────────────────────────────────────────
const _kBgPurple  = Color(0xFF8A3DB8); 
const _kRed       = Color(0xFFE53935);

class OutgoingCallScreen extends StatefulWidget {
  final String contactName;
  final String avatarUrl;
  final bool isVideoCall;

  const OutgoingCallScreen({
    super.key,
    required this.contactName,
    required this.avatarUrl,
    this.isVideoCall = false,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  bool _isMicMuted   = false;
  bool _isSpeakerOn  = true;  
  bool _isCameraOff  = true;  
  bool _showControls = true;

  LocalVideoTrack? _localVideoTrack;

  @override
  void initState() {
    super.initState();
    _isCameraOff = !widget.isVideoCall;
    if (!_isCameraOff) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      _localVideoTrack = await LocalVideoTrack.createCameraTrack();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to start camera: $e');
    }
  }

  @override
  void dispose() {
    _localVideoTrack?.dispose();
    super.dispose();
  }

  /// Extract up to 2-letter initials from contact name
  String get _initials {
    final parts = widget.contactName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].length >= 2
          ? parts[0].substring(0, 2).toUpperCase()
          : parts[0][0].toUpperCase();
    }
    return '??';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallActive) {
          final initials = state.contactName.isNotEmpty
              ? (state.contactName.length >= 2
                  ? state.contactName.substring(0, 2).toUpperCase()
                  : state.contactName[0].toUpperCase())
              : _initials;

          if (state.isVideo) {
            context.pushReplacement(AppRouterName.videoCall, extra: {
              'contactName': state.contactName,
              'livekitUrl': state.livekitUrl,
              'livekitToken': state.livekitToken,
            });
          } else {
            context.pushReplacement(AppRouterName.voiceCall, extra: {
              'contactName': state.contactName,
              'avatarInitials': initials,
              'livekitUrl': state.livekitUrl,
              'livekitToken': state.livekitToken,
              'initialMicMuted': _isMicMuted,
              'initialSpeakerOn': _isSpeakerOn,
            });
          }
        } else if (state is CallEnded || state is CallIdle) {
          if (state is CallEnded && state.reason == 'rejected') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Call was rejected by the receiver.',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          if (context.canPop()) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _kBgPurple,
        body: Stack(
          children: [
            // Background tap target
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _showControls = !_showControls);
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            if (!_isCameraOff && _localVideoTrack != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showControls = !_showControls);
                  },
                  child: VideoTrackRenderer(
                    _localVideoTrack!,
                    fit: VideoViewFit.cover,
                  ),
                ),
              ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: SafeArea(
                child: Column(
                  children: [
              SizedBox(height: 16.resH),
              // ── Top Bar ──────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.resW),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 12.resH),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
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
                        backgroundImage: widget.avatarUrl.isNotEmpty ? NetworkImage(widget.avatarUrl) : null,
                        child: widget.avatarUrl.isEmpty
                            ? Text(_initials, style: const TextStyle(color: Colors.white))
                            : null,
                      ),
                      
                      SizedBox(width: 12.resW),
                      
                      // Name & Status
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
                              'Calling...', // Matches UI, could also use 'call_status_calling'.tr()
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
                        onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                        child: Container(
                          width: 44.resW,
                          height: 44.resW,
                          decoration: BoxDecoration(
                            color: _isSpeakerOn ? Colors.white.withOpacity(0.2) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                            color: _isSpeakerOn ? Colors.white : _kBgPurple,
                            size: 22.resW,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.resW),
                      
                      // End Call Button
                      GestureDetector(
                        onTap: () => context.read<CallCubit>().endCall(),
                        child: Container(
                          width: 44.resW,
                          height: 44.resW,
                          decoration: const BoxDecoration(
                            color: _kRed,
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

              const Spacer(flex: 2),

              if (_isCameraOff)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220.resW,
                      height: 220.resW,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                    CircleAvatar(
                      radius: 90.resW,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      backgroundImage: widget.avatarUrl.isNotEmpty ? NetworkImage(widget.avatarUrl) : null,
                      child: widget.avatarUrl.isEmpty
                          ? Text(
                              _initials,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 64.resSp,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),

              const Spacer(flex: 3),

              // ── Bottom Controls ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(left: 16.resW, right: 16.resW, bottom: 24.resH),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 16.resH),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Camera Off
                      _BottomBtn(
                        icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                        active: _isCameraOff, 
                        activeBgColor: Colors.white,
                        activeIconColor: _kRed,
                        onTap: () async {
                          setState(() => _isCameraOff = !_isCameraOff);
                          if (!_isCameraOff) {
                            if (_localVideoTrack == null) {
                              await _startCamera();
                            } else {
                              await _localVideoTrack?.unmute();
                            }
                          } else {
                            await _localVideoTrack?.mute();
                          }
                        },
                      ),
                      // Flip Camera
                      _BottomBtn(
                        icon: Icons.cameraswitch_outlined,
                        active: false,
                        onTap: () async {
                          if (_localVideoTrack != null) {
                            try {
                              await Helper.switchCamera(_localVideoTrack!.mediaStreamTrack);
                            } catch (e) {
                              debugPrint('Failed to flip camera: $e');
                            }
                          }
                        },
                      ),
                      // Mic
                      _BottomBtn(
                        icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
                        active: _isMicMuted,
                        onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                      ),
                      // Emoji
                      _BottomBtn(
                        icon: Icons.emoji_emotions_outlined,
                        active: false,
                        onTap: () {},
                      ),
                      // Menu
                      _BottomBtn(
                        icon: Icons.menu,
                        active: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
            ],
          ),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color? activeBgColor;
  final Color? activeIconColor;

  const _BottomBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeBgColor,
    this.activeIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56.resW,
        height: 56.resW,
        decoration: BoxDecoration(
          color: active 
            ? (activeBgColor ?? Colors.white) 
            : Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active 
            ? (activeIconColor ?? Colors.black) 
            : Colors.white,
          size: 26.resW,
        ),
      ),
    );
  }
}
