import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
import '../widgets/chat_tile_widget.dart';
import '../bloc/chat_cubit.dart';
import '../../../../core/theme/app_logo.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    // Re-sync rooms from API every time the inbox opens.
    // This is a background refresh — the StreamBuilder already shows
    // cached SQLite data instantly while the fetch completes.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Connect to the WebSocket using the locally persisted token
      final token = await getIt<AuthLocalDataSource>().getAccessToken();
      if (token != null && token.isNotEmpty && mounted) {
        context.read<ChatCubit>().connectNetwork(token);
      }
      
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
            AppLogoWidget(
              size: 44,
              showText: false,
            ),
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
            child: StreamBuilder<List<ChatSession>>(
              stream: context
                  .read<ChatCubit>()
                  .recentChatsStream, // Direct pure SQLite hook!
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final activeChats = snapshot.data ?? [];

                if (activeChats.isEmpty) {
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
                      chat: chat,
                      onTap: () {
                        context.push('/chat_room', extra: chat);
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
