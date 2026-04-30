import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/presentation/pages/group_info_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
import '../widgets/message_bubble_widget.dart';
import '../widgets/attachment_sheet_widget.dart';
import '../widgets/typing_indicator.dart';
import '../bloc/chat_cubit.dart';
import '../bloc/voice_note_controller.dart';
import '../../../video_call/presentation/bloc/call_cubit.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_search_bar.dart';
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
  bool _isSearching = false;
  String? _highlightMessageId;
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

    // FR-018: Listen for scroll-to-top (older messages) in reversed ListView.
    _scrollController.addListener(_onScroll);

    if (widget.chatData.id.isEmpty) {
      // No room exists yet — entering from ContactsScreen. JIT room will be
      // created on the first Send press. Pass the contact metadata so the
      // Cubit can call createRoom(contact.id) at that moment.
      cubit.openRoom('', contact: widget.chatData);
    } else {
      cubit.openRoom(widget.chatData.id, room: widget.chatData);
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
      builder: (context) =>
          AttachmentSheetWidget(roomType: widget.chatData.type),
    );
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

  void _scrollToMessage(Message targetMessage, List<Message> allMessages) {
    // Hide search bar
    setState(() {
      _isSearching = false;
      _highlightMessageId = targetMessage.id;
    });

    // Reverse index since ListView is reversed
    final index = allMessages.reversed.toList().indexWhere(
      (m) => m.id == targetMessage.id,
    );
    if (index != -1 && _scrollController.hasClients) {
      // Very rough approximation: 80 pixels per message
      final targetOffset = index * 80.resH;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Clear highlight after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightMessageId = null;
        });
      }
    });
  }

  // FR-018: Trigger pagination when scrolling towards older messages.
  // In a reversed ListView, scrolling "up" (older) means approaching maxScrollExtent.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<ChatCubit>().loadMoreMessages();
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

  /// Stops any currently-playing voice note / audio before widget disposal.
  /// This prevents PlatformException from native audio handles being
  /// orphaned when the user navigates away while audio is playing.
  void _safeStopAllAudio() {
    VoiceNoteController().stopCurrent();
  }

  @override
  void dispose() {
    // Stop any playing audio BEFORE the widget tree is torn down.
    _safeStopAllAudio();
    // PREVENT STALE STATE ROUTING! Explicitly flush the bound Mongo identifier.
    cubit.closeRoom();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Stop all audio playback before the screen is popped.
        _safeStopAllAudio();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 40.resW,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.resW),
            onPressed: () {
              _safeStopAllAudio();
              context.go('/home');
            },
          ),
          title: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => widget.chatData.type == ChatRoomType.GROUP
                      ? GroupInfoPage(chatData: widget.chatData)
                      : ChatInfoScreen(chatData: widget.chatData),
                ),
              );
              if (result == 'search' && mounted) {
                setState(() => _isSearching = true);
              }
            },
            child: StreamBuilder<List<ChatSession>>(
              stream: cubit.recentChatsStream,
              builder: (context, snapshot) {
                final chats = snapshot.data ?? [];
                final chatData = chats.firstWhere(
                  (c) => c.id == widget.chatData.id,
                  orElse: () => widget.chatData,
                );
                return ChatRoomIcon(chatData: chatData, chatCubit: cubit);
              },
            ),
          ),
          actions: [
            if (widget.chatData.type == ChatRoomType.PRIVATE) ...[
              IconButton(
                icon: Icon(
                  Icons.phone_outlined,
                  color: AppColors.textSecondary,
                  size: 24.resW,
                ),
                onPressed: () {
                  context.read<CallCubit>().initiateCall(
                    targetUserId: widget.chatData.phoneNumber,
                    targetName: widget.chatData.name,
                    targetAvatarUrl: widget.chatData.avatarUrl,
                    isVideo: false,
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.videocam_outlined,
                  color: AppColors.textSecondary,
                  size: 24.resW,
                ),
                onPressed: () {
                  context.read<CallCubit>().initiateCall(
                    targetUserId: widget.chatData.phoneNumber,
                    targetName: widget.chatData.name,
                    targetAvatarUrl: widget.chatData.avatarUrl,
                  );
                },
              ),
            ],
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
                if (value == 'search') {
                  setState(() => _isSearching = true);
                }
                // Handle other menu actions here
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
                  AppColors.error,
                ),
                _buildMenuItem(
                  'report',
                  Icons.flag_outlined,
                  'Report',
                  AppColors.error,
                ),
                _buildMenuItem(
                  'delete',
                  Icons.delete_outline,
                  'Delete chat',
                  AppColors.error,
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isMenuOpen ? 0.3 : 1.0,
              child: Column(
                children: [
                  Expanded(
                    child: BlocConsumer<ChatCubit, ChatState>(
                      // Only rebuild the message list when messages actually change.
                      // TypingUpdate, TypingUpdate → never triggers a message-list rebuild.
                      buildWhen: (prev, curr) {
                        if (curr is TypingUpdate) return false;
                        if (curr is ChatRoomActive && prev is ChatRoomActive) {
                          // Only rebuild if the messages list itself changed.
                          return curr.messages != prev.messages ||
                              curr.roomId != prev.roomId;
                        }
                        return true;
                      },
                      listenWhen: (prev, curr) =>
                          curr is ChatRoomActive || curr is ChatLoading,
                      listener: (context, state) {
                        if (state is ChatRoomActive) {
                          _scrollToBottom();
                        }
                      },
                      builder: (context, state) {
                        if (state is ChatLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                          // +1 for the loading indicator at the top (end in reversed list)
                          itemCount: displayMessages.length + 1,
                          itemBuilder: (context, index) {
                            // FR-018: Last item (top of screen) shows loading indicator.
                            if (index == displayMessages.length) {
                              if (state is ChatRoomActive && state.isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CupertinoActivityIndicator()),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            final msg = displayMessages[index];
                            return Container(
                              key: ValueKey(msg.clientMessageId),
                              color: _highlightMessageId == msg.id
                                  ? AppColors.primary.withOpacity(0.2)
                                  : Colors.transparent,
                              child: MessageBubbleWidget(
                                message: msg,
                                currentUserId: _currentUserId,
                                isGroup:
                                    widget.chatData.type == ChatRoomType.GROUP,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Input Bar
                  ChatInputBar(
                    onAttachmentTap: () => _showAttachmentSheet(context),
                    onSendText: (text) {
                      context.read<ChatCubit>().sendLocalMessage(
                        MessageDraft(text: text),
                      );
                      _scrollToBottom();
                    },
                  ),
                ],
              ),
            ), // AnimatedOpacity

            if (_isSearching)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: BlocBuilder<ChatCubit, ChatState>(
                  builder: (context, state) {
                    List<Message> allMessages = [];
                    if (state is ChatRoomActive) {
                      allMessages = state.messages;
                    }
                    return ChatSearchBar(
                      onClose: () => setState(() => _isSearching = false),
                      onResultTap: (msg) => _scrollToMessage(msg, allMessages),
                    );
                  },
                ),
              ),
          ],
        ), // Stack
      ), // Scaffold
    ); // PopScope
  }
}

class ChatRoomIcon extends StatelessWidget {
  const ChatRoomIcon({
    super.key,
    required this.chatData,
    required this.chatCubit,
  });

  final ChatSession chatData;
  final ChatCubit chatCubit;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 18.resR,
              backgroundColor: AppColors.divider,
              backgroundImage: chatData.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(chatData.avatarUrl)
                  : null,
              child: chatData.avatarUrl.isEmpty
                  ? (chatData.type == ChatRoomType.GROUP
                        ? Icon(Icons.groups, color: AppColors.primary)
                        : Text(
                            chatData.name.isNotEmpty
                                ? chatData.name[0].toUpperCase()
                                : '?',
                            style: AppTypography.subtitle1.copyWith(
                              color: AppColors.primary,
                            ),
                          ))
                  : null,
            ),
            if (chatData.isOnline && chatData.type == ChatRoomType.PRIVATE)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10.resW,
                  height: 10.resW,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5.resW),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 12.resW),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chatData.name,
                style: AppTypography.subtitle1.copyWith(color: Colors.black),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              TypingIndicatorWidget(
                roomId: chatData.id,
                roomType: chatData.type,
                idleSubtitle: chatData.type == ChatRoomType.GROUP
                    ? '${chatData.participants.length} participants'
                    : (chatData.isOnline ? 'online' : 'offline'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
