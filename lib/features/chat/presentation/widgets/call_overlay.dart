import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/services/callkit_service.dart';
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

class CallOverlay extends StatefulWidget {
  final Widget child;

  const CallOverlay({super.key, required this.child});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> with WidgetsBindingObserver {
  // True while a lobby screen (outgoing/incoming) is on the navigation stack.
  // Used to decide push vs pushReplacement when CallActive arrives: if a lobby
  // was pushed, replace it; if the user joined directly from the chat screen
  // (joinActiveGroupCall), push on top so the chat screen stays in the stack.
  bool _lobbyWasPushed = false;

  // True while any call route (lobby OR media screen) is on the nav stack. Lets
  // us pop safely on CallEnded/CallIdle without accidentally popping the chat
  // screen once the lobby has already been dismissed (during CallConnecting).
  bool _callRouteOnStack = false;

  // Live "Connecting…" pill shown after the receiver accepts, while we await the
  // LiveKit token from the server's callAccepted. Inserted into the root
  // Navigator overlay so there is immediate feedback (previously CallConnecting
  // produced no UI change at all — the accept button appeared to do nothing).
  OverlayEntry? _connectingBanner;

  void _removeConnectingBanner() {
    _connectingBanner?.remove();
    _connectingBanner = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // main()'s startup cleanup only runs on a cold launch. If the app was merely
    // backgrounded during/after a call that didn't tear the native call down,
    // resuming would still show a ghost CallKit call. Clear it here whenever we
    // come back to the foreground with no active/ringing call in progress.
    if (state == AppLifecycleState.resumed) {
      // Delay briefly so any in-flight socket `incomingCall` (e.g. after a
      // reconnect) can set the state first — then only clear if there is still
      // genuinely no live call, so we never kill a real ringing/active call.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        final s = getIt<CallCubit>().state;
        final hasLiveCall = s is CallIncoming ||
            s is CallOutgoing ||
            s is CallConnecting ||
            s is CallActive;
        if (!hasLiveCall) {
          getIt<CallKitService>().endAllCalls();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeConnectingBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      // Only react to state transitions that need a navigation action.
      listenWhen: (prev, curr) {
        // Skip redundant transitions to the same state type.
        if (prev.runtimeType == curr.runtimeType) return false;
        return curr is CallIncoming ||
            curr is CallOutgoing ||
            curr is CallConnecting ||
            curr is CallActive ||
            curr is CallEnded ||
            curr is CallIdle;
      },
      listener: (context, state) {
        final navContext = globalNavigatorKey.currentContext;
        if (navContext == null) return;

        if (state is CallIncoming) {
          // ── Incoming call → full-screen ────────────────────────────────────
          _lobbyWasPushed = true;
          _callRouteOnStack = true;
          if (state.isGroupCall) {
            navContext.push(
              AppRouterName.incomingGroupCall,
              extra: {
                'chatRoomId': state.chatRoomId,
                'callerName': state.callerName,
                'groupName': state.groupName,
                'isVideo': state.isVideo,
              },
            );
          } else {
            navContext.push(
              AppRouterName.avatarIncomingCall,
              extra: {
                'callerName': state.callerName,
                'callerAvatarUrl': state.callerAvatarUrl,
                'callerId': state.callerId,
                'isVideo': state.isVideo,
              },
            );
          }
        } else if (state is CallOutgoing) {
          // ── Outgoing call → full-screen ────────────────────────────────────
          _lobbyWasPushed = true;
          _callRouteOnStack = true;
          navContext.push(
            AppRouterName.outgoingCall,
            extra: {
              'contactName': state.targetName,
              'avatarUrl': state.targetAvatarUrl,
              'isVideoCall': state.isVideo,
            },
          );
        } else if (state is CallConnecting) {
          // ── Receiver accepted → dismiss the incoming lobby (whether accepted
          // in-app or via the native CallKit button) and show a connecting pill
          // while we wait for the LiveKit token. This keeps the in-app UI in
          // sync with CallKit and gives the tap immediate feedback.
          if (_lobbyWasPushed && navContext.canPop()) {
            navContext.pop();
          }
          _lobbyWasPushed = false;
          _callRouteOnStack = false;
          _removeConnectingBanner();
          _connectingBanner = OverlayEntry(
            // Informational pill only — IgnorePointer so the full-screen overlay
            // never swallows taps meant for the screen beneath it.
            builder: (_) => IgnorePointer(
              child: CallConnectingBanner(
                contactName: state.contactName,
                isVideo: state.isVideo,
              ),
            ),
          );
          globalNavigatorKey.currentState?.overlay?.insert(_connectingBanner!);
        } else if (state is CallActive) {
          // ── Call connected → navigate to media room ────────────────────────
          _removeConnectingBanner();
          // Replace the lobby if one is still on the stack; otherwise (lobby
          // already dismissed during CallConnecting, or joinActiveGroupCall from
          // chat) push so the chat screen underneath is preserved.
          final replace = _lobbyWasPushed;
          _lobbyWasPushed = false;
          _callRouteOnStack = true;

          if (state.isGroupCall) {
            final route = '/group_call/${state.chatRoomId}';
            replace
                ? navContext.pushReplacement(route)
                : navContext.push(route);
            return;
          }

          // Both 1:1 video and voice calls use the same VideoCallScreen for an
          // identical UX; voice simply starts with the camera off.
          final extra = {
            'contactName': state.contactName,
            'livekitUrl': state.livekitUrl,
            'livekitToken': state.livekitToken,
            'roomName': state.chatRoomId,
            'startWithCamera': state.isVideo,
          };
          replace
              ? navContext.pushReplacement(AppRouterName.videoCall, extra: extra)
              : navContext.push(AppRouterName.videoCall, extra: extra);
        } else if (state is CallEnded || state is CallIdle) {
          // ── Call ended / cleared elsewhere → tear down any call UI ──────────
          // Only pop when a call route is actually on the stack — guards against
          // popping the chat screen if the call ended before/without one (e.g.
          // rejected before accept UI showed, or callHandledElsewhere).
          _removeConnectingBanner();
          if (_callRouteOnStack && navContext.canPop()) {
            navContext.pop();
          }
          _lobbyWasPushed = false;
          _callRouteOnStack = false;
        }
      },
      child: widget.child,
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
