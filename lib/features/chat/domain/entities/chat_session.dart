class ChatSession {
  final String id; // roomId
  final String name; // the other user's name or group name
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final String avatarUrl;
  final String phoneNumber;

  ChatSession({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.avatarUrl,
    required this.phoneNumber,
  });

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
    );
  }
}
