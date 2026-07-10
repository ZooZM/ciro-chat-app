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
import 'package:ciro_chat_app/features/call_history/presentation/pages/calls_history_screen.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/reels_feed_screen.dart';
import 'package:ciro_chat_app/features/profile/presentation/pages/profile_main_screen.dart';
import 'package:easy_localization/easy_localization.dart';

/// Bottom-nav tab index for Reels — inserted after Calls per the
/// "keep the Call icon/tab as-is and add Reels directly after it" clarification.
const int kReelsTabIndex = 4;

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
    context.locale; // Subscribe to locale changes for bottom nav translations

    return Scaffold(
      // Black on Reels: the bottom nav Container's rounded top corners clip
      // to reveal whatever sits behind them — with a white Scaffold, that
      // was showing as a white sliver at the corners even though the
      // Container's own decoration was already black.
      backgroundColor: _currentIndex == kReelsTabIndex
          ? Colors.black
          : Colors.white,
      appBar:
          (_currentIndex == 2 ||
              _currentIndex == 3 ||
              _currentIndex == kReelsTabIndex)
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              titleSpacing: 0, // Shift the entire logo to the left
              title: ChatListAppBar(),
              actions: [
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
          // Dark-themed while viewing Reels — matches the inner
          // BottomNavigationBar below so no white/light edge shows through
          // at the rounded top corners or border (spec.md clarification
          // 2026-07-02).
          color: _currentIndex == kReelsTabIndex ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: _currentIndex == kReelsTabIndex
              ? null
              : Border.all(color: Colors.green.withOpacity(0.15), width: 1.5),
          boxShadow: _currentIndex == kReelsTabIndex
              ? null
              : [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BottomNavigationBar(
            // Dark-themed while viewing Reels so the bar blends with the
            // full-screen video behind it (spec.md clarification 2026-07-02).
            backgroundColor: _currentIndex == kReelsTabIndex
                ? Colors.black
                : Colors.white,
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: _currentIndex == kReelsTabIndex
                ? Colors.white70
                : Colors.grey[600],
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            elevation: 0,
            items: [
              // ── 1. Chats — logo asset ──────────────────────────────────────
              BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: Image.asset(
                    AppLogo.assetPath,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
                activeIcon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: Image.asset(
                    AppLogo.assetPath,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
                label: 'nav_chats'.tr(),
              ),
              // ── 2. Updates ────────────────────────────────────────────────
              BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.motion_photos_on_outlined, size: 28),
                ),
                activeIcon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.motion_photos_on, size: 28),
                ),
                label: 'nav_updates'.tr(),
              ),
              // ── 3. Map ────────────────────────────────────────────────────
              BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.location_on_outlined, size: 28),
                ),
                activeIcon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.location_on, size: 28),
                ),
                label: 'nav_map'.tr(),
              ),
              // ── 4. Calls ──────────────────────────────────────────────────
              BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.call_outlined, size: 28),
                ),
                activeIcon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.call, size: 28),
                ),
                label: 'nav_calls'.tr(),
              ),
              // ── 5. Reels ──────────────────────────────────────────────────
              BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.play_circle_outline, size: 28),
                ),
                activeIcon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.play_circle, size: 28),
                ),
                label: 'nav_reels'.tr(),
              ),
              // ── 6. Profile ────────────────────────────────────────────────
              BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_outline, size: 28),
                ),
                activeIcon: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, size: 28),
                ),
                label: 'nav_profile'.tr(),
              ),
            ],
          ),
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
    if (_currentIndex == 3) {
      return const CallsHistoryScreen();
    }
    if (_currentIndex == kReelsTabIndex) {
      return const ReelsFeedScreen();
    }
    if (_currentIndex == 5) {
      return const ProfileMainScreen();
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
                  height: 32.resH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.resR),
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
    context.locale; // Subscribe to locale changes
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
          offset: Offset(-12.resW, 0), // Shift left
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ciro',
                style: AppTypography.logoMark.copyWith(
                  fontFamily: 'GeometrySoftPro',
                  fontSize: 34,
                  height: 1.1,
                  letterSpacing: 1,
                  color: const Color(0xFF111111),
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
