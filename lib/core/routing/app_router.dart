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
import '../di/injection.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'go_router_refresh_stream.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  // GoRouterRefreshStream bridges AuthCubit state changes to GoRouter.
  // Every time AuthCubit emits a new state, the redirect guard below is re-run.
  refreshListenable: GoRouterRefreshStream(getIt<AuthCubit>().stream),
  // Pure state-driven redirect: reads AuthCubit synchronously — no async,
  // no stale boolean flags, no race conditions.
  redirect: (context, state) {
    // Remove the native splash on the very first routing evaluation.
    FlutterNativeSplash.remove();

    final authState = getIt<AuthCubit>().state;
    final location = state.matchedLocation;

    final isAuthRoute = location == '/auth' || location.startsWith('/auth/');
    final isSplash   = location == '/splash';

    // While auth is still being determined, stay on the splash screen.
    if (authState is AuthInitial || authState is AuthLoading) {
      return isSplash ? null : '/splash';
    }

    // Fully authenticated: move out of splash/auth into the app.
    if (authState is Authenticated) {
      if (isSplash || isAuthRoute) return '/home';
      return null; // already on a valid screen
    }

    // Unauthenticated (or AuthError): keep out of the app.
    if (!isAuthRoute) return '/auth';
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => BlocProvider.value(
        value: getIt<AuthCubit>(),
        child: const MobileNumberScreen(),
      ),
      routes: [
        GoRoute(
          path: 'verify',
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
        // ChatRoomScreen.initState calls cubit.openRoom — do NOT call it here too.
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
