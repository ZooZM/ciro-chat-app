import 'dart:convert';

import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';

class ChatRoomModel extends ChatSession {
  ChatRoomModel({
    required super.id,
    required super.name,
    required super.lastMessage,
    required super.timestamp,
    super.unreadCount,
    super.isOnline,
    required super.avatarUrl,
    required super.phoneNumber,
    super.lastMessageSenderId,
    super.lastMessageStatus,
    super.contactUserId,
    super.type,
    super.participants,
    super.admins,
  });

  factory ChatRoomModel.fromJson(
    Map<String, dynamic> json,
    String currentUserPhone,
  ) {
    // Re-use ChatSession's fromJson logic, as ChatRoomModel extends ChatSession
    final chatSession = ChatSession.fromJson(json, currentUserPhone);
    return ChatRoomModel(
      id: chatSession.id,
      name: chatSession.name,
      lastMessage: chatSession.lastMessage,
      timestamp: chatSession.timestamp,
      unreadCount: chatSession.unreadCount,
      isOnline: chatSession.isOnline,
      avatarUrl: chatSession.avatarUrl,
      phoneNumber: chatSession.phoneNumber,
      lastMessageSenderId: chatSession.lastMessageSenderId,
      lastMessageStatus: chatSession.lastMessageStatus,
      contactUserId: chatSession.contactUserId,
      type: chatSession.type,
      participants: chatSession.participants,
      admins: chatSession.admins,
    );
  }

  Map<String, dynamic> toJson() {
    // Re-use ChatSession's toMap logic as it's already structured for Map conversion
    // and rename to toJson for consistency with model naming conventions
    return {
      'id': id,
      'name': name,
      'lastMessage': lastMessage,
      'timestamp': timestamp.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'avatarUrl': avatarUrl,
      'phoneNumber': phoneNumber,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageStatus': lastMessageStatus.name,
      'type': type.name,
      'participants': jsonEncode(participants), // Stored as JSON string
      'admins': jsonEncode(admins), // Stored as JSON string
    };
  }
}
