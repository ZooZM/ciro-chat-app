import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Very light gray
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            const _GroupChatInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              }
            },
          ),
          CircleAvatar(
            radius: 20.resR,
            backgroundColor: const Color(0xFF14345B), // Dark blue
            child: Text(
              'TT',
              style: AppTypography.body1.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.resSp,
              ),
            ),
          ),
          SizedBox(width: 12.resW),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tech Team',
                  style: AppTypography.headline3.copyWith(
                    fontSize: 16.resSp,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '14 members',
                  style: AppTypography.body2.copyWith(
                    fontSize: 12.resSp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_outlined, color: Colors.black54),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Colors.black54),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black54),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    final messages = [
      _MessageData(
        text: "Hey everyone! The new feature is ready",
        time: "1:20 PM",
        isMe: false,
        senderName: null, // First message doesn't have name in mockup
        senderInitials: "M",
      ),
      _MessageData(
        text: "Awesome work! 🎉",
        time: "1:21 PM",
        isMe: true,
        status: _MessageStatus.read,
      ),
      _MessageData(
        text: "Can we test it now?",
        time: "1:22 PM",
        isMe: false,
        senderName: "Sara",
        senderInitials: "S",
      ),
      _MessageData(
        text: "Yes, I just deployed it to staging",
        time: "1:23 PM",
        isMe: false,
        senderName: "Mohamed",
        senderInitials: "M",
      ),
      _MessageData(
        text: "Great! I'll check it out",
        time: "1:24 PM",
        isMe: true,
        status: _MessageStatus.sent,
      ),
      _MessageData(
        text: "Looking good so far!",
        time: "1:25 PM",
        isMe: false,
        senderName: "Ahmed",
        senderInitials: "A",
      ),
      _MessageData(
        text: "Thanks team! Let me know if you find any issues",
        time: "1:30 PM",
        isMe: false,
        senderName: "Mohamed",
        senderInitials: "M",
      ),
    ];

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 20.resH),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        if (msg.isMe) {
          return _MyMessageBubble(data: msg);
        } else {
          return _OtherMessageBubble(data: msg);
        }
      },
    );
  }
}

class _GroupChatInputBar extends StatelessWidget {
  const _GroupChatInputBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.fromLTRB(16.resW, 8.resH, 16.resW, 20.resH),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8.resH, right: 12.resW),
            child: Icon(Icons.add, color: Colors.grey[600], size: 28.resW),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.resR),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      maxLines: 4,
                      minLines: 1,
                      style: AppTypography.body1.copyWith(
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: AppTypography.body1.copyWith(
                          color: Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.resW,
                          vertical: 12.resH,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.resH, right: 12.resW),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.grey[600],
                      size: 24.resW,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 8.resH, left: 12.resW),
            child: Icon(Icons.mic_none, color: Colors.grey[600], size: 28.resW),
          ),
        ],
      ),
    );
  }
}

class _MyMessageBubble extends StatelessWidget {
  final _MessageData data;

  const _MyMessageBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.resH),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: 0.7.sw),
            padding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 10.resH,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F7CB), // Light green
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.resR),
                topRight: Radius.circular(16.resR),
                bottomRight: Radius.circular(16.resR),
                bottomLeft: Radius.zero, // Tail on the left
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.text,
                  style: AppTypography.body1.copyWith(
                    color: Colors.black87,
                    fontSize: 15.resSp,
                  ),
                ),
                SizedBox(height: 4.resH),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.time,
                      style: AppTypography.body2.copyWith(
                        color: Colors.grey[600],
                        fontSize: 11.resSp,
                      ),
                    ),
                    SizedBox(width: 4.resW),
                    Icon(
                      data.status == _MessageStatus.read
                          ? Icons.done_all
                          : Icons.check,
                      size: 14.resW,
                      color: data.status == _MessageStatus.read
                          ? AppColors.secondary
                          : Colors.grey[600],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherMessageBubble extends StatelessWidget {
  final _MessageData data;

  const _OtherMessageBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.resH),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.senderName != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 4.resH, left: 12.resW),
                  child: Text(
                    data.senderName!,
                    style: AppTypography.body2.copyWith(
                      color: Colors.grey[400],
                      fontSize: 12.resSp,
                    ),
                  ),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: 0.65.sw),
                padding: EdgeInsets.symmetric(
                  horizontal: 16.resW,
                  vertical: 10.resH,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.resR),
                    topRight: Radius.circular(16.resR),
                    bottomLeft: Radius.circular(16.resR),
                    bottomRight: Radius.zero, // Tail on the right
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      data.text,
                      style: AppTypography.body1.copyWith(
                        color: Colors.black87,
                        fontSize: 15.resSp,
                      ),
                    ),
                    SizedBox(height: 4.resH),
                    Text(
                      data.time,
                      style: AppTypography.body2.copyWith(
                        color: Colors.grey[400],
                        fontSize: 11.resSp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 8.resW),
          CircleAvatar(
            radius: 16.resR,
            backgroundColor: const Color(0xFF38703C), // Darkish green
            child: Text(
              data.senderInitials ?? '?',
              style: AppTypography.body2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.resSp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MessageStatus { sent, read }

class _MessageData {
  final String text;
  final String time;
  final bool isMe;
  final String? senderName;
  final String? senderInitials;
  final _MessageStatus? status;

  _MessageData({
    required this.text,
    required this.time,
    required this.isMe,
    this.senderName,
    this.senderInitials,
    this.status,
  });
}
