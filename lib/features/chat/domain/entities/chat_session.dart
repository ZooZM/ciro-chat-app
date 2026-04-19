import 'package:permission_handler/permission_handler.dart';

class ChatSession {
  final String id; // roomId
  final String name; // the other user's name or group name
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final String avatarUrl;
  final String phoneNumber;
  final String lastMessageSenderId;

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
  });

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
    final lastMsg = json['lastMessage'];
    if (lastMsg is Map) {
      lastMsgText = lastMsg['content'] ?? '';
      lastMsgSender = lastMsg['senderId'] ?? '';
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
    );
  }
}
