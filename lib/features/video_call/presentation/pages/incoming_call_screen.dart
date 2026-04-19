import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:go_router/go_router.dart';
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
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallActive) {
          context.pushReplacement(
            '/video_call',
            extra: {
              'contactName': state.contactName,
              'livekitUrl': state.livekitUrl,
              'livekitToken': state.livekitToken,
            },
          );
        } else if (state is CallEnded || state is CallIdle) {
          Navigator.pop(context); // Fallback pop if completely dismissed
        }
      },
      child: Scaffold(
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
                  _PulseAvatar(avatarUrl: callerAvatarUrl, name: callerName),

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
                    style: AppTypography.body1.copyWith(color: Colors.white54),
                  ),

                  const Spacer(flex: 3),

                  // ── Action buttons row ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 48,
                    ),
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
                            // Tap Accept: State goes to CallConnecting until server acknowledges.
                            // The BlocListener directly above will intercept CallActive when ready.
                            context.read<CallCubit>().acceptCall();
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
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withOpacity(0.25),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.6),
            width: 3,
          ),
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
