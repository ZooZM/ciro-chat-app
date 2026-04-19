import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/mobile_number_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/verify_code_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_room_screen.dart';
import 'package:ciro_chat_app/features/contacts/presentation/pages/contacts_screen.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/splash/presentation/pages/splash_screen.dart';
import 'package:ciro_chat_app/features/video_call/presentation/bloc/call_cubit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/video_call/presentation/pages/video_call_screen.dart';
import '../../features/video_call/presentation/pages/incoming_call_screen.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../di/injection.dart';

import 'go_router_refresh_stream.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(getIt<AuthCubit>().stream),
  redirect: (context, state) async {
    final isLoggedIn = await getIt<AuthLocalDataSource>().getLoggedInStatus();

    final isAuthRoute = state.matchedLocation == '/auth' || state.matchedLocation.startsWith('/auth/');
    final isSplash = state.matchedLocation == '/splash';

    // 1. Unauthenticated users strictly stay in limits
    if (!isLoggedIn && !isAuthRoute) {
      return '/auth';
    }

    // 2. Authenticated users are banned from auth pages, forced to /home
    if (isLoggedIn && (isAuthRoute || isSplash)) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => BlocProvider(
        create: (context) => getIt<AuthCubit>(),
        child: const MobileNumberScreen(),
      ),
      routes: [
        GoRoute(
          path: 'verify',
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return BlocProvider(
              create: (context) => getIt<AuthCubit>(),
              child: VerifyCodeScreen(phoneNumber: phone),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/video',
      builder: (context, state) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.push('/video_call'),
            child: const Text('Launch Video Call UI'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/chat_room',
      builder: (context, state) {
        final chat = state.extra as ChatSession;
        // Use the global ChatCubit instance and open the specific room
        context.read<ChatCubit>().openRoom(chat.id);
        return ChatRoomScreen(chatData: chat);
      },
    ),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactsScreen(),
    ),
    GoRoute(
      path: '/incoming_call',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return IncomingCallScreen(
          callerName: data['callerName'] as String? ?? 'Unknown',
          callerAvatarUrl: data['callerAvatarUrl'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/video_call',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return VideoCallScreen(
          contactName: data['contactName'] as String? ?? 'Calling...',
          livekitUrl: data['livekitUrl'] as String? ?? '',
          livekitToken: data['livekitToken'] as String? ?? '',
        );
      },
    ),
  ],
);
