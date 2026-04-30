import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';

class StatusModel extends StatusEntity {
  const StatusModel({
    required super.id,
    required super.authorName,
    required super.authorAvatar,
    required super.timestamp,
    required super.expiresAt,
    super.isViewed = false,
    super.isMine = false,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      authorAvatar: json['authorAvatar'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isViewed: (json['isViewed'] as bool?) ?? false,
      isMine: (json['isMine'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isViewed': isViewed,
      'isMine': isMine,
    };
  }

  factory StatusModel.fromMap(Map<String, dynamic> map) {
    return StatusModel(
      id: map['id'] as String,
      authorName: map['author_name'] as String,
      authorAvatar: map['author_avatar'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      isViewed: (map['is_viewed'] as int) == 1,
      isMine: (map['is_mine'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'is_viewed': isViewed ? 1 : 0,
      'is_mine': isMine ? 1 : 0,
    };
  }
}
