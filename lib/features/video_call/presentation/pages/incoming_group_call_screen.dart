import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../bloc/call_cubit.dart';

class IncomingGroupCallScreen extends StatelessWidget {
  final String chatRoomId;
  final String callerName;
  final String groupName;
  final bool isVideo;

  const IncomingGroupCallScreen({
    super.key,
    required this.chatRoomId,
    required this.callerName,
    required this.groupName,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = groupName.isNotEmpty ? groupName : callerName;
    final initials = displayName.length >= 2
        ? displayName.substring(0, 2).toUpperCase()
        : displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : 'G';

    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallActive && state.isGroupCall) {
          context.pushReplacement(
            '/group_call/${state.chatRoomId}',
          );
        } else if (state is CallEnded || state is CallIdle) {
          if (context.canPop()) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF555555),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Group avatar ──────────────────────────────────────────────
              CircleAvatar(
                radius: 75.resR,
                backgroundColor: const Color(0xFF8E6FB1),
                child: Text(
                  initials,
                  style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(height: 24.resH),

              // ── Group name ────────────────────────────────────────────────
              Text(
                displayName,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.resH),

              // ── Caller info ───────────────────────────────────────────────
              Text(
                '$callerName is calling',
                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 16),
              ),
              SizedBox(height: 6.resH),

              Text(
                isVideo ? 'Group Video Call' : 'Group Voice Call',
                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              ),

              const Spacer(flex: 3),

              // ── Action buttons ────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: 40.resH, left: 30.resW, right: 30.resW),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _GroupCallButton(
                      icon: Icons.call_end,
                      color: const Color(0xFFE53935),
                      label: 'Decline',
                      onTap: () => context.read<CallCubit>().declineGroupCall(),
                    ),
                    _GroupCallButton(
                      icon: isVideo ? Icons.videocam : Icons.phone,
                      color: const Color(0xFF4CAF50),
                      label: 'Accept',
                      onTap: () => context.read<CallCubit>().acceptGroupCall(),
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

class _GroupCallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _GroupCallButton({
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
            width: 70.resW,
            height: 70.resW,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32.resW),
          ),
        ),
        SizedBox(height: 12.resH),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
