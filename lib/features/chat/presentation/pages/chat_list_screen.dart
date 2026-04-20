import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
import '../widgets/chat_tile_widget.dart';
import '../bloc/chat_cubit.dart';
import '../../../../core/theme/app_logo.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    // The router guarantees we only land here when AuthCubit has emitted
    // Authenticated and the socket is already connected with a fresh token.
    // We only need to trigger a background room hydration from the API.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatCubit>().hydrateRooms();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16.resW,
        title: Row(
          children: [
            AppLogoWidget(size: 44, showText: false),
            SizedBox(width: 8.resW),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CIRO',
                  style: AppTypography.logoMark.copyWith(
                    fontSize: 20,
                    height: 1.1,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'CONNECT',
                  style: AppTypography.logoTagline.copyWith(
                    fontSize: 9,
                    height: 1.1,
                    letterSpacing: 3,
                  ),
                ),
                // WhatsApp-Style minimal connecting feedback seamlessly below the branding
                ValueListenableBuilder<bool>(
                  valueListenable: getIt<SocketService>().isConnectedNotifier,
                  builder: (context, isConnected, _) {
                    if (isConnected) return const SizedBox.shrink();
                    return Text(
                      'Connecting...',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 9, // Subtly styled
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // SvgPicture.asset(
        //   'assets/icons/logo.svg', // Assuming primary logo variant exists
        //   height: 36.resH,
        //   // Placeholder if missing
        //   placeholderBuilder: (_) => Text(
        //     'CIRO CONNECT',
        //     style: AppTypography.headline2.copyWith(color: AppColors.primary),
        //   ),
        // ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout,
              color: AppColors.textSecondary,
              size: 20.resW,
            ),
            onPressed: () async {
              await getIt<AuthCubit>().logOut();
              if (mounted) {
                context.go('/auth');
              }
            },
          ),
          Padding(
            padding: EdgeInsets.only(right: 16.resW),
            child: CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 18.resR,
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.white, size: 20.resW),
                onPressed: () {
                  context.push('/contacts');
                },
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 8.resH,
            ),
            child: Row(
              children: [
                Text(
                  'Chats',
                  style: AppTypography.headline1.copyWith(color: Colors.black),
                ),
                SizedBox(width: 16.resW),
                // Pill Search Bar
                Expanded(
                  child: Container(
                    height: 40.resH,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.resR),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.5),
                        width: 1.resW,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12.resW),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 20.resW,
                        ),
                        SizedBox(width: 8.resW),
                        Text(
                          'Search',
                          style: AppTypography.body1.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) {
                return StreamBuilder<List<ChatSession>>(
                  stream: context
                      .read<ChatCubit>()
                      .recentChatsStream, // Direct pure SQLite hook!
                  builder: (context, snapshot) {
                    // Offline-First UX: Prevent 1-frame flashes while SQLite boots or network spins
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const SizedBox.shrink(); // Silent buffer
                    }

                    final activeChats = snapshot.data ?? [];

                    // Do NOT show empty state permanently unless DB is truly empty AND Hydration natively finished!
                    if (activeChats.isEmpty) {
                      if (!context.read<ChatCubit>().isHydrationComplete) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        ); // Subtle fallback if zero cache
                      }

                      return Center(
                        child: Text(
                          'No active chats yet.\nTap the + button to start one!',
                          textAlign: TextAlign.center,
                          style: AppTypography.body1.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: activeChats.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: AppColors.divider.withOpacity(0.5),
                        indent: 80.resW, // Lines up under names
                      ),
                      itemBuilder: (context, index) {
                        final chat = activeChats[index];
                        return ChatTileWidget(
                          key: ValueKey(chat.id),
                          chat: chat,
                          currentUserId: context
                              .read<ChatCubit>()
                              .currentUserId,
                          onTap: () {
                            context.push('/chat_room', extra: chat);
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTypography.caption,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble, size: 24.resW),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.update, size: 24.resW),
              label: 'Updates',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_outlined, size: 24.resW),
              label: 'Calls',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 24.resW),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
