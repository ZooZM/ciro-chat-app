import 'dart:convert';

import 'package:ciro_chat_app/features/status/data/models/status_reaction_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_viewer_model.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';

class StatusModel extends StatusEntity {
  const StatusModel({
    required super.id,
    required super.authorName,
    required super.authorAvatar,
    required super.timestamp,
    required super.expiresAt,
    super.isViewed = false,
    super.isMine = false,
    super.contentType = StatusContentType.image,
    super.textContent,
    super.mediaUrl,
    super.backgroundColor,
    super.fontStyle,
    super.musicTrackId,
    super.caption,
    super.privacy = StatusPrivacy.public,
    super.clientStatusId = '',
    super.authorId = '',
    super.audience = const [],
    super.syncStatus = 'synced',
    super.viewers = const [],
    super.reactions = const [],
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      authorAvatar: json['authorAvatar'] as String,
      timestamp: DateTime.parse(
        (json['createdAt'] ?? json['timestamp']) as String,
      ),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isViewed: (json['isViewed'] as bool?) ?? false,
      isMine: (json['isMine'] as bool?) ?? false,
      contentType: StatusContentType.values.firstWhere(
        (e) => e.name == json['contentType'],
        orElse: () => StatusContentType.image,
      ),
      textContent: json['textContent'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      fontStyle: json['fontStyle'] as String?,
      musicTrackId: json['musicTrackId'] as String?,
      caption: json['caption'] as String?,
      privacy: StatusPrivacy.values.firstWhere(
        (e) => e.name == json['privacy'],
        orElse: () => StatusPrivacy.public,
      ),
      clientStatusId: json['clientStatusId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      audience: (json['audience'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      syncStatus: json['syncStatus'] as String? ?? 'synced',
      viewers: (json['viewers'] as List<dynamic>?)
              ?.map((e) => StatusViewerModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map(
                (e) => StatusReactionModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
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
      'contentType': contentType.name,
      'textContent': textContent,
      'mediaUrl': mediaUrl,
      'backgroundColor': backgroundColor,
      'fontStyle': fontStyle,
      'musicTrackId': musicTrackId,
      'caption': caption,
      'privacy': privacy.name,
      'clientStatusId': clientStatusId,
      'authorId': authorId,
      'audience': audience,
      'syncStatus': syncStatus,
      'viewers': viewers
          .map((v) => StatusViewerModel(
                userId: v.userId,
                name: v.name,
                avatarUrl: v.avatarUrl,
                viewedAt: v.viewedAt,
              ).toJson())
          .toList(),
      'reactions': reactions
          .map((r) => StatusReactionModel(
                userId: r.userId,
                reaction: r.reaction,
                createdAt: r.createdAt,
              ).toJson())
          .toList(),
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
      contentType: StatusContentType.values.firstWhere(
        (e) => e.name == map['content_type'],
        orElse: () => StatusContentType.image,
      ),
      textContent: map['text_content'] as String?,
      mediaUrl: map['media_url'] as String?,
      backgroundColor: map['background_color'] as String?,
      fontStyle: map['font_style'] as String?,
      musicTrackId: map['music_track_id'] as String?,
      caption: map['caption'] as String?,
      privacy: StatusPrivacy.values.firstWhere(
        (e) => e.name == map['privacy'],
        orElse: () => StatusPrivacy.public,
      ),
      clientStatusId: map['client_status_id'] as String? ?? '',
      authorId: map['author_id'] as String? ?? '',
      syncStatus: map['sync_status'] as String? ?? 'synced',
      audience: map['audience_json'] != null
          ? (jsonDecode(map['audience_json'] as String) as List<dynamic>)
              .map((e) => e as String)
              .toList()
          : const [],
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
      'content_type': contentType.name,
      'text_content': textContent,
      'media_url': mediaUrl,
      'background_color': backgroundColor,
      'font_style': fontStyle,
      'music_track_id': musicTrackId,
      'caption': caption,
      'privacy': privacy.name,
      'client_status_id': clientStatusId,
      'sync_status': syncStatus,
      'audience_json': jsonEncode(audience),
      'author_id': authorId,
    };
  }
}
