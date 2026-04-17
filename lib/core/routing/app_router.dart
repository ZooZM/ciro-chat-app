import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/mobile_number_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/verify_code_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/chat_room_screen.dart';
import 'package:ciro_chat_app/features/contacts/presentation/pages/contacts_screen.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';

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
  ],
);
