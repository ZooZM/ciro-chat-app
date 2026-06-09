import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/updates_screen.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/status_creation_screen.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/mobile_number_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/verify_code_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_room_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/create_group_page.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/group_chat_screen.dart';
import 'package:ciro_chat_app/features/contacts/presentation/pages/contacts_screen.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/splash/presentation/pages/splash_screen.dart';
import 'package:ciro_chat_app/features/map/presentation/pages/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/story_viewer_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/video_call/presentation/pages/video_call_screen.dart';
import '../../features/video_call/presentation/pages/voice_call_screen.dart';
import '../../features/video_call/presentation/pages/incoming_call_screen.dart';
import '../../features/video_call/presentation/pages/outgoing_call_screen.dart';
import '../../features/video_call/presentation/pages/group_call_screen.dart';
import '../../features/video_call/presentation/pages/incoming_group_call_screen.dart';
import '../../features/call_recording/presentation/pages/recordings_list_page.dart';
import '../di/injection.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'go_router_refresh_stream.dart';

class AppRouterName {
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String verify = 'verify';
  static const String home = '/home';
  static const String createGroup = '/home/create_group';
  static const String chatRoom = '/chat_room';
  static const String groupChat = '/group_chat';
  static const String contacts = '/contacts';
  static const String incomingCall = '/incoming_call';
  static const String videoCall = '/video_call';
  static const String outgoingCall = '/outgoing_call';
  static const String voiceCall = '/voice_call';
  static const String updates = '/updates';
  static const String map = '/map';
  static const String calls = '/calls';
  static const String profile = '/profile';
  static const String groupCall = '/group_call/:roomId';
  static const String incomingGroupCall = '/incoming_group_call';
  static const String recordings = '/recordings';
}

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

/// Checks if the app was launched by tapping a push notification (terminated state).
/// If so, navigates directly to the referenced chat room.
Future<void> handleInitialNotification() async {
  final message = await FirebaseMessaging.instance.getInitialMessage();
  if (message == null) return;
  final roomId = message.data['roomId'] as String?;
  if (roomId == null) return;
  final room = await getIt<ChatCubit>().getRoomById(roomId);
  if (room != null) {
    appRouter.push(AppRouterName.chatRoom, extra: room);
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: globalNavigatorKey,
  initialLocation: AppRouterName.splash,
  // GoRouterRefreshStream bridges AuthCubit state changes to GoRouter.
  // Every time AuthCubit emits a new state, the redirect guard below is re-run.
  refreshListenable: GoRouterRefreshStream(getIt<AuthCubit>().stream),
  // Pure state-driven redirect: reads AuthCubit synchronously — no async,
  // no stale boolean flags, no race conditions.
  redirect: (context, state) async {
    // Remove the native splash on the very first routing evaluation.
    FlutterNativeSplash.remove();

    final authState = getIt<AuthCubit>().state;
    final location = state.uri.toString();

    final isAuthRoute =
        location == AppRouterName.auth ||
        location.startsWith('${AppRouterName.auth}/');
    final isSplash = location == AppRouterName.splash;

    // ── RULE 1: Transient states — do NOT redirect ────────────────────────────
    // AuthLoading fires during OTP send, token refresh, and initial boot.
    // AuthInitial is the cold-start state before verifyAuthStatus() runs.
    // Returning null keeps the user exactly where they are so loading spinners work.
    if (authState is AuthInitial || authState is AuthLoading) {
      return null;
    }

    // ── RULE 2: Authenticated ─────────────────────────────────────────────────
    // Eject from splash/auth screens into the app; don't disturb any other screen.
    if (authState is Authenticated) {
      await context.read<ChatCubit>().hydrateRooms();
      if (isAuthRoute) return AppRouterName.home;
      return null;
    }

    // ── RULE 3: Unauthenticated or AuthError ──────────────────────────────────
    // Redirect to /auth only if not already there.
    if (!isAuthRoute && !isSplash) return AppRouterName.auth;
    return null;
  },
  routes: [
    GoRoute(
      path: AppRouterName.splash,
      builder: (context, state) => BlocProvider.value(
        value: getIt<AuthCubit>(),
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: AppRouterName.auth,
      builder: (context, state) => BlocProvider.value(
        value: getIt<AuthCubit>(),
        child: const MobileNumberScreen(),
      ),
      routes: [
        GoRoute(
          path: AppRouterName.verify,
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return BlocProvider.value(
              value: getIt<AuthCubit>(),
              child: VerifyCodeScreen(phoneNumber: phone),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: AppRouterName.home,
      builder: (context, state) => const ChatListScreen(),
      routes: [
        GoRoute(
          path: 'create_group',
          builder: (context, state) => const CreateGroupPage(),
        ),
      ],
    ),
    GoRoute(
      path: AppRouterName.chatRoom,
      builder: (context, state) {
        // state.extra is null when GoRouter rebuilds this route without the
        // original extra (deep link, router restore, rotation, or any push
        // missing extra). Cast as nullable and redirect to home instead of
        // throwing a TypeError.
        final chat = state.extra as ChatSession?;
        if (chat == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppRouterName.home);
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // ChatRoomScreen.initState calls cubit.openRoom — do NOT call it here too.
        return ChatRoomScreen(chatData: chat);
      },
    ),
    GoRoute(
      path: AppRouterName.groupChat,
      builder: (context, state) {
        final chat = state.extra as ChatSession?;
        if (chat != null) return ChatRoomScreen(chatData: chat);
        return const GroupChatScreen();
      },
    ),
    GoRoute(
      path: AppRouterName.contacts,
      builder: (context, state) => const ContactsScreen(),
    ),
    GoRoute(
      path: AppRouterName.incomingCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return IncomingCallScreen(
          callerName: data['callerName'] as String? ?? 'Unknown',
          callerId: data['callerId'] as String? ?? '',
          callerAvatarUrl: data['callerAvatarUrl'] as String? ?? '',
          isVideo: data['isVideo'] == true,
        );
      },
    ),
    GoRoute(
      path: AppRouterName.videoCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return VideoCallScreen(
          contactName: data['contactName'] as String? ?? 'Calling...',
          livekitUrl: data['livekitUrl'] as String? ?? '',
          livekitToken: data['livekitToken'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRouterName.outgoingCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return OutgoingCallScreen(
          contactName: data['contactName'] as String? ?? 'Calling...',
          avatarUrl: data['avatarUrl'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRouterName.voiceCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return VoiceCallScreen(
          contactName: data['contactName'] as String? ?? 'Calling...',
          avatarInitials: data['avatarInitials'] as String? ?? '',
          livekitUrl: data['livekitUrl'] as String? ?? '',
          livekitToken: data['livekitToken'] as String? ?? '',
          initialMicMuted: data['initialMicMuted'] as bool? ?? false,
          initialSpeakerOn: data['initialSpeakerOn'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: AppRouterName.updates,
      builder: (context, state) => const UpdatesScreen(),
    ),
    GoRoute(
      path: '/group_call/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? '';
        return GroupCallScreen(roomId: roomId);
      },
    ),
    GoRoute(
      path: AppRouterName.incomingGroupCall,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return IncomingGroupCallScreen(
          chatRoomId: data['chatRoomId'] as String? ?? '',
          callerName: data['callerName'] as String? ?? 'Unknown',
          groupName: data['groupName'] as String? ?? '',
          isVideo: data['isVideo'] == true,
        );
      },
    ),
    GoRoute(
      path: AppRouterName.recordings,
      builder: (context, state) => const RecordingsListPage(),
    ),
  ],
);
