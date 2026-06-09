import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import '../bloc/call_cubit.dart';

// ─── Design tokens (match mockup) ────────────────────────────────────────────
const _kBg        = Color(0xFF616161);
const _kAvatarBg  = Color(0xFF9575CD); // purple avatar
const _kBtnGray   = Color(0xFF757575);
const _kGreen     = Color(0xFF4CAF50);
const _kRed       = Color(0xFFE53935);

class OutgoingCallScreen extends StatefulWidget {
  final String contactName;
  final String avatarUrl;

  const OutgoingCallScreen({
    super.key,
    required this.contactName,
    required this.avatarUrl,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  bool _isMicMuted   = false;
  bool _isSpeakerOn  = true;  // speaker active by default (matches mockup)
  bool _isCameraOff  = true;  // camera off by default for voice call

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
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Avatar circle ────────────────────────────────────────────
              Container(
                width: 130.resW,
                height: 130.resW,
                decoration: const BoxDecoration(
                  color: _kAvatarBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48.resSp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.resH),

              // ── Contact name ─────────────────────────────────────────────
              Text(
                widget.contactName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.resSp,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 8.resH),

              // ── Status label ─────────────────────────────────────────────
              Text(
                'call_status_calling'.tr(),
                style: TextStyle(
                  color: const Color(0xFFCCCCCC),
                  fontSize: 15.resSp,
                ),
              ),

              const Spacer(flex: 4),

              // ── 3 control buttons ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.resW),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Camera off
                    _CircleBtn(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam_outlined,
                      active: false,
                      onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                    ),
                    // Mic toggle
                    _CircleBtn(
                      icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
                      active: false,
                      onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                    ),
                    // Speaker toggle (active = white bg + green icon)
                    _CircleBtn(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      active: _isSpeakerOn,
                      onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 28.resH),

              // ── End Call button ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.resW),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      padding: EdgeInsets.symmetric(vertical: 15.resH),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => context.read<CallCubit>().endCall(),
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 22),
                    label: Text(
                      'call_action_end'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.resSp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32.resH),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable circle icon button
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;   // true → white background + green icon
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58.resW,
        height: 58.resW,
        decoration: BoxDecoration(
          color: active ? Colors.white : _kBtnGray,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active ? _kGreen : Colors.white,
          size: 26.resW,
        ),
      ),
    );
  }
}
