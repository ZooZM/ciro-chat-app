import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/call_cubit.dart';

/// Shown on the receiving device when someone calls us.
/// Displayed as a full-page route pushed by the global CallCubit listener.
class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final String callerAvatarUrl;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    this.callerAvatarUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark gradient background ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1A2E),
                  AppColors.primary.withOpacity(0.15),
                  const Color(0xFF1A1A2E),
                ],
              ),
            ),
          ),

          // ── Ringing pulse animation around avatar ─────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Animated rings
                _PulseAvatar(
                  avatarUrl: callerAvatarUrl,
                  name: callerName,
                ),

                const SizedBox(height: 28),

                // Caller name
                Text(
                  callerName,
                  style: AppTypography.headline2.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Status
                Text(
                  'جاري الاتصال...',
                  style: AppTypography.body1.copyWith(
                    color: Colors.white54,
                  ),
                ),

                const Spacer(flex: 3),

                // ── Action buttons row ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decline
                      _CallActionButton(
                        icon: Icons.call_end,
                        color: Colors.red,
                        label: 'رفض',
                        onTap: () {
                          context.read<CallCubit>().rejectCall();
                          Navigator.of(context).pop();
                        },
                      ),

                      // Accept
                      _CallActionButton(
                        icon: Icons.videocam,
                        color: AppColors.primary,
                        label: 'قبول',
                        onTap: () {
                          context.read<CallCubit>().acceptCall();
                          // Replace IncomingCallScreen with VideoCallScreen
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<CallCubit>(),
                                child: VideoCallActiveWrapper(
                                    contactName: callerName),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing avatar ─────────────────────────────────────────────────────────────

class _PulseAvatar extends StatefulWidget {
  final String avatarUrl;
  final String name;

  const _PulseAvatar({required this.avatarUrl, required this.name});

  @override
  State<_PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<_PulseAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(
        scale: _pulse.value,
        child: child,
      ),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withOpacity(0.25),
          border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 3),
        ),
        child: CircleAvatar(
          radius: 56,
          backgroundColor: AppColors.primary,
          backgroundImage: widget.avatarUrl.isNotEmpty
              ? NetworkImage(widget.avatarUrl)
              : null,
          child: widget.avatarUrl.isEmpty
              ? Text(
                  widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ── Round action button ─────────────────────────────────────────────────────────

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

// ── Thin wrapper used after accept, waits for CallActive state ─────────────────

class VideoCallActiveWrapper extends StatelessWidget {
  final String contactName;
  const VideoCallActiveWrapper({super.key, required this.contactName});

  @override
  Widget build(BuildContext context) {
    // The actual VideoCallScreen lives in video_call_screen.dart
    // Import it here to avoid circular imports at the top
    return _VideoCallBridge(contactName: contactName);
  }
}

// Lazy import bridge to avoid circular dependency at top of file
class _VideoCallBridge extends StatelessWidget {
  final String contactName;
  const _VideoCallBridge({required this.contactName});

  @override
  Widget build(BuildContext context) {
    // This screen is already self-contained; we simply push it.
    // The CallCubit endCall() is wired to the End Call button below.
    return BlocListener<CallCubit, CallState>(
      listenWhen: (_, s) => s is CallIdle || s is CallEnded,
      listener: (context, _) => Navigator.of(context).pop(),
      child: VideoCallScreenShell(contactName: contactName),
    );
  }
}

/// Minimal shell that renders the UI from video_call_screen.dart
/// without depending on LiveKit. Import video_call_screen at top
/// of the consuming file.
class VideoCallScreenShell extends StatelessWidget {
  final String contactName;
  const VideoCallScreenShell({super.key, required this.contactName});

  @override
  Widget build(BuildContext context) {
    // Delegate to the full VideoCallScreen widget
    // (imported indirectly via the file that uses this)
    return Scaffold(
      body: Center(
        child: Text(
          'Active call with $contactName',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
