import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/auth_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/video_call/presentation/pages/video_call_screen.dart';
import '../../features/video_call/presentation/bloc/video_call_cubit.dart';
import '../di/injection.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => BlocProvider(
        create: (context) => getIt<AuthCubit>(),
        child: const AuthScreen(),
      ),
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
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home (Chat List) Placeholder')),
      ),
    ),
    GoRoute(
      path: '/video_call',
      // We will assume the user passes a map { 'url': wsUrl, 'token': token }
      // but for testing, we can just grab it or initiate a blank one.
      // Wait, we need to invoke joinRoom if we pass it, but maybe just provision the bloc:
      builder: (context, state) {
        return BlocProvider(
          create: (_) => getIt<VideoCallCubit>()
            // Trigger connection attempt with dummy credentials to test State flows
            ..joinRoom('testRoom1'),
          child: const VideoCallScreen(),
        );
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ChatCubit>(),
        child: const ChatScreen(),
      ),
    ),
  ],
);
