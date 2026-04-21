import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';

class ChatSession {
  final String id;             // Room ID (MongoDB room _id). Empty = JIT pending.
  final String name;           // Other user's display name or group name
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final String avatarUrl;
  final String phoneNumber;
  final String lastMessageSenderId;
  final MessageStatus lastMessageStatus;

  /// Carries the contact's MongoDB User _id during a JIT flow.
  /// This is set by ContactsScreen before navigating so the Cubit can call
  /// createRoom(contactUserId). It is intentionally NOT persisted to SQLite.
  final String contactUserId;

  ChatSession({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.avatarUrl,
    required this.phoneNumber,
    this.lastMessageSenderId = '',
    this.lastMessageStatus = MessageStatus.pending,
    this.contactUserId = '',     // defaults to empty; only set for JIT contact flows
  });

  /// Creates a copy with specific fields overridden.
  /// Used by ContactsScreen to zero-out the room [id] and signal a JIT flow
  /// while preserving the contact's User ID in a separate field.
  ChatSession copyWith({
    String? id,
    String? name,
    String? lastMessage,
    DateTime? timestamp,
    int? unreadCount,
    bool? isOnline,
    String? avatarUrl,
    String? phoneNumber,
    String? lastMessageSenderId,
    MessageStatus? lastMessageStatus,
    String? contactUserId,
  }) {
    return ChatSession(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      timestamp: timestamp ?? this.timestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      contactUserId: contactUserId ?? this.contactUserId,
    );
  }

  /// Parses a raw backend ChatRoom JSON object.
  /// The backend returns populated `participants` (array of User objects)
  /// and a populated `lastMessage` object (or null).
  /// The [currentUserPhone] is used to determine the "other" participant's
  /// name to display in the inbox tile.
  factory ChatSession.fromJson(
    Map<String, dynamic> json,
    String currentUserPhone,
  ) {
    final roomId = json['_id'] ?? json['id'] ?? '';

    // Resolve display name from the other participant in a PRIVATE room,
    // or use the group name for GROUP rooms.
    String displayName = json['name'] ?? '';
    String otherPhone = '';
    String otherAvatar = '';
    bool otherIsOnline = false;

    final participants = json['participants'] as List<dynamic>? ?? [];
    if (json['type'] == 'PRIVATE' || displayName.isEmpty) {
      // Find the participant who is NOT the current user
      final other = participants.firstWhere(
        (p) => (p['phoneNumber'] ?? '') != currentUserPhone,
        orElse: () => participants.isNotEmpty ? participants.first : {},
      );
      displayName = other['phoneNumber'] ?? 'Unknown';
      otherPhone = other['phoneNumber'] ?? '';
      otherAvatar = other['avatarUrl'] ?? '';
      otherIsOnline = other['isOnline'] == true;
    }

    // Parse the nested lastMessage object
    String lastMsgText = '';
    DateTime lastMsgTime = DateTime.now();
    String lastMsgSender = '';
    MessageStatus lastMsgStatus = MessageStatus.pending;
    final lastMsg = json['lastMessage'];
    if (lastMsg is Map) {
      lastMsgText = lastMsg['content'] ?? '';
      lastMsgSender = lastMsg['senderId'] ?? '';
      if (lastMsg['status'] != null) {
        lastMsgStatus = MessageStatus.values.firstWhere(
          (e) => e.name == lastMsg['status'],
          orElse: () => MessageStatus.pending,
        );
      }
      lastMsgTime =
          DateTime.tryParse(
            lastMsg['createdAt'] ?? lastMsg['updatedAt'] ?? '',
          ) ??
          DateTime.now();
    } else if (lastMsg == null) {
      lastMsgText = '';
      lastMsgTime =
          DateTime.tryParse(json['updatedAt'] ?? json['createdAt'] ?? '') ??
          DateTime.now();
    }

    return ChatSession(
      id: roomId.toString(),
      name: displayName,
      lastMessage: lastMsgText,
      timestamp: lastMsgTime,
      avatarUrl: otherAvatar.isNotEmpty
          ? otherAvatar
          : 'https://i.pravatar.cc/150?u=$roomId',
      isOnline: otherIsOnline,
      phoneNumber: otherPhone,
      lastMessageSenderId: lastMsgSender,
      lastMessageStatus: lastMsgStatus,
    );
  }

  // ── SQLite serialisation ──────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lastMessage': lastMessage,
      'timestamp': timestamp.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline ? 1 : 0,
      'avatarUrl': avatarUrl,
      'phoneNumber': phoneNumber,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageStatus': lastMessageStatus.name,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      name: map['name'] as String,
      lastMessage: map['lastMessage'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      unreadCount: map['unreadCount'] as int? ?? 0,
      isOnline: (map['isOnline'] as int? ?? 0) == 1,
      avatarUrl: map['avatarUrl'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageStatus: MessageStatus.values.firstWhere(
        (e) => e.name == map['lastMessageStatus'],
        orElse: () => MessageStatus.pending,
      ),
    );
  }
}
