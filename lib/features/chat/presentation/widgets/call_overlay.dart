import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../video_call/presentation/bloc/call_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CallOverlay
//
// A transparent wrapper that sits above the entire widget tree (placed in
// main.dart as the child of MultiBlocProvider, wrapping MaterialApp.router).
//
// Responsibilities:
//   • Reacts to [CallIncoming] → routes to /incoming_call (full-screen)
//   • Reacts to [CallOutgoing] → routes to /outgoing_call (full-screen)
//   • Reacts to [CallActive]   → routes to /video_call or /voice_call
//   • Shows a non-intrusive [_MiniBanner] for [CallEnded] / [CallIdle]
//     transitions so the chat text + scroll position are preserved.
//
// Because routing is driven through GoRouter (not bare Navigator), the chat
// back-stack is kept intact — the user can return to exactly where they were.
// ─────────────────────────────────────────────────────────────────────────────

class CallOverlay extends StatelessWidget {
  final Widget child;

  const CallOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      // Only react to state transitions that need a navigation action.
      listenWhen: (prev, curr) {
        // Skip redundant transitions to the same state type.
        if (prev.runtimeType == curr.runtimeType) return false;
        return curr is CallIncoming ||
            curr is CallOutgoing ||
            curr is CallActive ||
            curr is CallEnded;
      },
      listener: (context, state) {
        if (state is CallIncoming) {
          // ── Incoming call → full-screen ────────────────────────────────────
          // Use push (not pushReplacement) so the chat route stays in the stack
          // and the user returns to it after the call ends.
          context.push(
            AppRouterName.incomingCall,
            extra: {
              'callerName': state.callerName,
              'callerAvatarUrl': state.callerAvatarUrl,
              'callerId': state.callerId,
              'isVideo': state.isVideo,
            },
          );
        } else if (state is CallOutgoing) {
          // ── Outgoing call → full-screen ────────────────────────────────────
          context.push(
            AppRouterName.outgoingCall,
            extra: {
              'contactName': state.targetName,
              'avatarUrl': state.targetAvatarUrl,
            },
          );
        } else if (state is CallActive) {
          // ── Call connected → replace call lobby with media room ────────────
          final initials = state.contactName.isNotEmpty
              ? (state.contactName.length >= 2
                    ? state.contactName.substring(0, 2).toUpperCase()
                    : state.contactName[0].toUpperCase())
              : '??';

          if (state.isVideo) {
            context.pushReplacement(
              AppRouterName.videoCall,
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
        } else if (state is CallEnded) {
          // ── Call ended — pop the call screen if it is on top ───────────────
          // context.canPop() prevents crashes if the call ended before any
          // call route was pushed (e.g., rejected before accept UI showed).
          if (context.canPop()) context.pop();
        }
      },
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniBanner — shown during CallConnecting to avoid a blank screen gap.
// Rendered as a floating pill at the top of [child] using a Stack.
// ─────────────────────────────────────────────────────────────────────────────

/// A lightweight floating banner displayed while we are in [CallConnecting]
/// state (receiver accepted, waiting for LiveKit token from server).
/// Rendered as an Overlay entry so it appears above the active route.
class CallConnectingBanner extends StatelessWidget {
  final String contactName;
  final bool isVideo;

  const CallConnectingBanner({
    super.key,
    required this.contactName,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: Container(
            margin: EdgeInsets.only(top: 8.resH, left: 16.resW, right: 16.resW),
            padding: EdgeInsets.symmetric(
              horizontal: 20.resW,
              vertical: 10.resH,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(32.resR),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.phone,
                  color: Colors.white,
                  size: 18.resW,
                ),
                SizedBox(width: 8.resW),
                Text(
                  'Connecting to $contactName…',
                  style: AppTypography.body2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
