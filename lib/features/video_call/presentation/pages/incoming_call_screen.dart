import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/call_cubit.dart';

/// Shown on the receiving device when someone calls us.
/// Displayed as a full-page route pushed by the global CallCubit listener.
class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final String callerId;
  final String callerAvatarUrl;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    this.callerId = '',
    this.callerAvatarUrl = '',
    this.isVideo = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallActive) {
          final initials = state.contactName.isNotEmpty 
              ? (state.contactName.length >= 2 ? state.contactName.substring(0, 2).toUpperCase() : state.contactName[0].toUpperCase()) 
              : 'AK';
              
          if (state.isVideo) {
            context.pushReplacement(
              '/video_call',
              extra: {
                'contactName': state.contactName,
                'livekitUrl': state.livekitUrl,
                'livekitToken': state.livekitToken,
              },
            );
          } else {
            context.pushReplacement(
              '/voice_call',
              extra: {
                'contactName': state.contactName,
                'avatarInitials': initials,
                'livekitUrl': state.livekitUrl,
                'livekitToken': state.livekitToken,
              },
            );
          }
        } else if (state is CallEnded || state is CallIdle) {
          Navigator.pop(context); // Fallback pop if completely dismissed
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF555555), // Solid dark grey background matching the mockup
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // ── Avatar ──────────────────────────────────────────────────────
              CircleAvatar(
                radius: 75.resR,
                backgroundColor: const Color(0xFF8E6FB1), // Muted purple from mockup
                backgroundImage: callerAvatarUrl.isNotEmpty
                    ? NetworkImage(callerAvatarUrl)
                    : null,
                child: callerAvatarUrl.isEmpty
                    ? Text(
                        callerName.isNotEmpty 
                            ? (callerName.length >= 2 ? callerName.substring(0, 2).toUpperCase() : callerName[0].toUpperCase()) 
                            : 'AK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
              ),
              SizedBox(height: 24.resH),
              
              // ── Caller Name ─────────────────────────────────────────────────
              Text(
                callerName,
                style: AppTypography.headline3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                ),
              ),
              SizedBox(height: 8.resH),
              
              // ── Caller Number ───────────────────────────────────────────────
              Text(
                callerId, // Using callerId as the phone number
                style: AppTypography.body1.copyWith(
                  color: const Color(0xFFAAAAAA), // Light grey
                  fontSize: 18,
                ),
              ),
              
              const Spacer(flex: 3),
              
              // ── Animated Swipe Chevrons ─────────────────────────────────────
              const _AnimatedChevrons(),
              
              // ── Action Buttons Row ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: 40.resH, left: 30.resW, right: 30.resW),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Messaging Button
                    _CallActionButton(
                      icon: Icons.message,
                      color: const Color(0xFF888888),
                      label: 'Messaging',
                      onTap: () {
                        context.read<CallCubit>().rejectCall();
                      },
                    ),

                    // Swipe up to Accept
                    _AnimatedAcceptButton(isVideo: isVideo),

                    // Reject Button
                    _CallActionButton(
                      icon: Icons.call_end,
                      color: const Color(0xFFE53935), // Red
                      label: 'Reject',
                      onTap: () {
                        context.read<CallCubit>().rejectCall();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated Chevrons ────────────────────────────────────────────────────────

class _AnimatedChevrons extends StatefulWidget {
  const _AnimatedChevrons();

  @override
  State<_AnimatedChevrons> createState() => _AnimatedChevronsState();
}

class _AnimatedChevronsState extends State<_AnimatedChevrons> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Column(
          children: List.generate(4, (index) {
            // Calculate a wave effect for each chevron
            final double phase = (index * 0.2);
            final double opacity = ((_ctrl.value - phase + 1.0) % 1.0);
            
            // Invert index so the top chevron is the faintest/oldest in the wave
            return Opacity(
              opacity: (1.0 - opacity).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white54,
                  size: 28.resW,
                ),
              ),
            );
          }),
        );
      },
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
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60.resW,
            height: 60.resW,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28.resW),
          ),
        ),
        SizedBox(height: 12.resH),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}

// ── Animated Accept Button ───────────────────────────────────────────────────

class _AnimatedAcceptButton extends StatefulWidget {
  final bool isVideo;
  const _AnimatedAcceptButton({required this.isVideo});

  @override
  State<_AnimatedAcceptButton> createState() => _AnimatedAcceptButtonState();
}

class _AnimatedAcceptButtonState extends State<_AnimatedAcceptButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    // A subtle bounce up and down
    _animation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      // Allow dragging upwards (negative offset)
      _dragOffset += details.primaryDelta ?? 0;
      if (_dragOffset > 0) _dragOffset = 0; // Prevent dragging downwards
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    
    // If dragged up by more than 80 pixels or flicked upwards
    if (_dragOffset < -80 || (details.primaryVelocity != null && details.primaryVelocity! < -300)) {
      context.read<CallCubit>().acceptCall();
    }
    
    // Snap back to original position
    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onTap: () {
        context.read<CallCubit>().acceptCall();
      },
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              // Prioritize drag offset if user is interacting, else bounce
              final currentOffset = _isDragging ? _dragOffset : _animation.value;
              return Transform.translate(
                offset: Offset(0, currentOffset),
                child: child,
              );
            },
            child: Container(
              width: 72.resW,
              height: 72.resW,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50), // Green
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isVideo ? Icons.videocam : Icons.phone, 
                color: Colors.white, 
                size: 36.resW,
              ),
            ),
          ),
          SizedBox(height: 12.resH),
          const Text(
            'Swap up to accept', // Matches user's screenshot
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
