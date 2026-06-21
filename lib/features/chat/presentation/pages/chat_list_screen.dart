import 'package:ciro_chat_app/core/routing/app_router.dart';
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
import '../../../status/presentation/pages/updates_screen.dart';
import 'package:ciro_chat_app/features/map/presentation/pages/map_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    // The router guarantees we only land here when AuthCubit has emitted
    // Authenticated and the socket is already connected with a fresh token.
    // We only need to trigger a background room hydration from the API.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        'ChatListScreen: isHydrationComplete: ${context.read<ChatCubit>().isHydrationComplete}',
      );
      if (mounted && !context.read<ChatCubit>().isHydrationComplete) {
        context.read<ChatCubit>().hydrateRooms();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentIndex == 2 ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16.resW,
        title: ChatListAppBar(),
        actions: [
          IconButton(
            icon: Icon(
              Icons.language,
              color: AppColors.primary,
              size: 24.resW,
            ),
            onPressed: () {
              if (context.locale.languageCode == 'en') {
                context.setLocale(const Locale('ar'));
              } else {
                context.setLocale(const Locale('en'));
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.logout,
              color: AppColors.textSecondary,
              size: 20.resW,
            ),
            onPressed: () async {
              await getIt<AuthCubit>().logOut();
              if (mounted) {
                context.go(AppRouterName.auth);
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
                  context.push(AppRouterName.contacts);
                },
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          color: Colors.white,
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: AppTypography.caption.copyWith(fontSize: 11),
          elevation: 0,
          items: [
            // ── 1. Chats — logo asset ──────────────────────────────────────
            BottomNavigationBarItem(
              icon: Image.asset(
                AppLogo.assetPath,
                width: 40.resW,
                height: 40.resW,
                fit: BoxFit.contain,
              ),
              activeIcon: Image.asset(
                AppLogo.assetPath,
                width: 40.resW,
                height: 40.resW,
                fit: BoxFit.contain,
                // color: AppColors.primary,
                colorBlendMode: BlendMode.srcIn,
              ),
              label: 'nav_chats'.tr(),
            ),
            // ── 2. Updates ────────────────────────────────────────────────
            BottomNavigationBarItem(
              icon: Icon(Icons.motion_photos_on_outlined, size: 24.resW),
              activeIcon: Icon(Icons.motion_photos_on, size: 24.resW),
              label: 'nav_updates'.tr(),
            ),
            // ── 3. Map ────────────────────────────────────────────────────
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined, size: 24.resW),
              activeIcon: Icon(Icons.location_on, size: 24.resW),
              label: 'nav_map'.tr(),
            ),
            // ── 4. Calls ──────────────────────────────────────────────────
            BottomNavigationBarItem(
              icon: Icon(Icons.call_outlined, size: 24.resW),
              activeIcon: Icon(Icons.call, size: 24.resW),
              label: 'nav_calls'.tr(),
            ),
            // ── 5. Profile ────────────────────────────────────────────────
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 24.resW),
              activeIcon: Icon(Icons.person, size: 24.resW),
              label: 'nav_profile'.tr(),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                context.push('/home/create_group');
              },
              child: const Icon(Icons.group_add),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_currentIndex == 1) {
      return const UpdatesScreen();
    }
    if (_currentIndex == 2) {
      return const MapScreen();
    }
    // Default to Chat List
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 8.resH),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'nav_chats'.tr(),
                style: AppTypography.subtitle1.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 12.resW),
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
                        'search_placeholder'.tr(),
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

                  return StreamBuilder<Map<String, Set<String>>>(
                    stream: context.read<ChatCubit>().allTypingUsersStream,
                    builder: (context, typingSnapshot) {
                      final typingMap = typingSnapshot.data ?? {};

                      return ListView.separated(
                        itemCount: activeChats.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: AppColors.divider.withOpacity(0.5),
                          indent: 80.resW, // Lines up under names
                        ),
                        itemBuilder: (context, index) {
                          final chat = activeChats[index];
                          final isTyping =
                              (typingMap[chat.id]?.isNotEmpty ?? false);

                          return ChatTileWidget(
                            key: ValueKey(chat.id),
                            chat: chat,
                            currentUserId: context
                                .read<ChatCubit>()
                                .currentUserId,
                            isTyping: isTyping,
                            onTap: () {
                              context.push(AppRouterName.chatRoom, extra: chat);
                            },
                          );
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
    );
  }
}

class ChatListAppBar extends StatelessWidget {
  const ChatListAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Bubble icon — left side of logo ─────────────────────────────
        Image.asset(
          AppLogo.assetPath,
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        ),
        // ── CIRO / CONNECT stacked text — right side of logo ─────────────
        Transform.translate(
          offset: Offset(-6.resW, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ciro',
                style: AppTypography.logoMark.copyWith(
                  fontSize: 24,
                  height: 1.1,
                  letterSpacing: -1.0,
                  color: const Color(0xFF222222),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'CONNECT',
                style: AppTypography.logoTagline.copyWith(
                  fontSize: 8,
                  height: 1.1,
                  letterSpacing: 2.5,
                  color: AppColors.primary,
                ),
              ),
              // ── "Connecting..." subtle status below branding ────────────
              ValueListenableBuilder<bool>(
                valueListenable: getIt<SocketService>().isConnectedNotifier,
                builder: (context, isConnected, _) {
                  if (isConnected) return const SizedBox.shrink();
                  return Text(
                    'status_connecting'.tr(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
