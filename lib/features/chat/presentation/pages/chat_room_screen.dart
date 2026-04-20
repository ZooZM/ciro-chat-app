import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/message.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
import '../widgets/message_bubble_widget.dart';
import '../widgets/attachment_sheet_widget.dart';
import '../bloc/chat_cubit.dart';
import '../../../video_call/presentation/bloc/call_cubit.dart';
import '../../../video_call/presentation/pages/outgoing_call_screen.dart';
import 'chat_info_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatSession chatData;

  const ChatRoomScreen({Key? key, required this.chatData}) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentUserId;
  bool _isMenuOpen = false; // tracks popup visibility for background dim
  late ChatCubit cubit;
  @override
  void initState() {
    super.initState();
    // Try to read immediately — will be populated if login already completed
    _currentUserId = context.read<ChatCubit>().currentUserId;

    // If empty (race condition on first launch), retry after first frame
    if (_currentUserId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentUserId = context.read<ChatCubit>().currentUserId;
          });
        }
      });
    }
    cubit = context.read<ChatCubit>();

    if (widget.chatData.id.isEmpty) {
      // No room exists yet — entering from ContactsScreen. JIT room will be
      // created on the first Send press. Pass the contact metadata so the
      // Cubit can call createRoom(contact.id) at that moment.
      cubit.openRoom('', contact: widget.chatData);
    } else {
      cubit.openRoom(widget.chatData.id);
      // Mark any delivered-but-unread messages as read now that the user is here.
      // Fire-and-forget: the StreamBuilder will reactively update the UI.
      cubit.markRoomMessagesRead(widget.chatData.id).ignore();
    }
  }

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AttachmentSheetWidget(),
    );
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isNotEmpty) {
      context.read<ChatCubit>().sendLocalMessage(text);
      _msgController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // With reverse: true, the "bottom" visually is offset 0 mathematically.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // PREVENT STALE STATE ROUTING! Explicitly flush the bound Mongo identifier.
    cubit.closeRoom();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallOutgoing) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<CallCubit>(),
                child: OutgoingCallScreen(
                  contactName: widget.chatData.name,
                  avatarUrl: widget.chatData.avatarUrl,
                ),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 40.resW,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.resW),
            onPressed: () => context.go('/home'),
          ),
          title: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatInfoScreen(chatData: widget.chatData),
                ),
              );
            },
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18.resR,
                      backgroundColor: AppColors.divider,
                      backgroundImage: widget.chatData.avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(widget.chatData.avatarUrl)
                          : null,
                      child: widget.chatData.avatarUrl.isEmpty
                          ? Text(
                              widget.chatData.name.isNotEmpty
                                  ? widget.chatData.name[0].toUpperCase()
                                  : '?',
                              style: AppTypography.subtitle1.copyWith(
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    if (widget.chatData.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10.resW,
                          height: 10.resW,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5.resW,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12.resW),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatData.name,
                      style: AppTypography.subtitle1.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      widget.chatData.isOnline ? 'online' : 'offline',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.phone_outlined,
                color: AppColors.textSecondary,
                size: 24.resW,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(
                Icons.videocam_outlined,
                color: AppColors.textSecondary,
                size: 24.resW,
              ),
              onPressed: () {
                // 1. Emit requestCall via socket exactly using Mongo ID
                context.read<CallCubit>().initiateCall(
                  targetUserId: widget.chatData.phoneNumber,
                  targetName: widget.chatData.name,
                  targetAvatarUrl: widget.chatData.avatarUrl,
                );
                // 2. Navigation is completely delegated to BlocListener safely mapping to OutgoingCallScreen
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
                size: 24.resW,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              elevation: 8,
              offset: const Offset(0, 48), // push dropdown below the icon
              onOpened: () => setState(() => _isMenuOpen = true),
              onCanceled: () => setState(() => _isMenuOpen = false),
              onSelected: (value) {
                setState(() => _isMenuOpen = false);
                // Handle menu actions here
              },
              itemBuilder: (context) => [
                _buildMenuItem(
                  'search',
                  Icons.search,
                  'Search in conversation',
                  AppColors.textPrimary,
                ),
                _buildMenuItem(
                  'mute',
                  Icons.notifications_off_outlined,
                  'Mute notification',
                  AppColors.textPrimary,
                ),
                _buildMenuItem(
                  'block',
                  Icons.person_off_outlined,
                  'Block user',
                  Colors.red,
                ),
                _buildMenuItem(
                  'report',
                  Icons.flag_outlined,
                  'Report',
                  Colors.red,
                ),
                _buildMenuItem(
                  'delete',
                  Icons.delete_outline,
                  'Delete chat',
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
        body: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isMenuOpen ? 0.3 : 1.0,
          child: Column(
            children: [
              Expanded(
                child: BlocConsumer<ChatCubit, ChatState>(
                  listener: (context, state) {
                    if (state is ChatRoomActive) {
                      _scrollToBottom();
                    }
                  },
                  builder: (context, state) {
                    if (state is ChatLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Strictly mapping to the localized Stream
                    List<Message> displayMessages = [];
                    if (state is ChatRoomActive) {
                      displayMessages = state.messages.reversed.toList();
                    }

                    return ListView.builder(
                      reverse:
                          true, // Forces keyboard constraints up correctly (WhatsApp spec)
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 16.resH),
                      itemCount: displayMessages.length,
                      itemBuilder: (context, index) {
                        return MessageBubbleWidget(
                          message: displayMessages[index],
                          currentUserId: _currentUserId,
                        );
                      },
                    );
                  },
                ),
              ),

              // Bottom Input Bar
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.resW,
                  vertical: 12.resH,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.divider, width: 0.5),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.add,
                          color: AppColors.textSecondary,
                          size: 28.resW,
                        ),
                        onPressed: () => _showAttachmentSheet(context),
                      ),
                      SizedBox(width: 8.resW),
                      Expanded(
                        child: Container(
                          height: 44.resH,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22.resR),
                            border: Border.all(
                              color: AppColors.divider,
                              width: 1.5.resW,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16.resW),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _msgController,
                            onSubmitted: (_) => _sendMessage(),
                            style: AppTypography.body1.copyWith(
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: AppTypography.body1.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.resW),
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.textSecondary,
                          size: 26.resW,
                        ),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.send,
                          color: AppColors.primary,
                          size: 26.resW,
                        ),
                        onPressed: _sendMessage, // Call _sendMessage on tap
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ), // Column
        ), // AnimatedOpacity
      ),
    ); // Scaffold
  } // BlocListener
}
