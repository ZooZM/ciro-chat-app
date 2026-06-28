import 'package:equatable/equatable.dart';
import 'status_content_type.dart';
import 'status_privacy.dart';
import 'status_reaction.dart';
import 'status_viewer.dart';

class StatusEntity extends Equatable {
  final String id;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;
  final DateTime expiresAt;
  final bool isViewed;
  final bool isMine;

  // New fields for creation flow
  final StatusContentType contentType;
  final String? textContent;
  final String? mediaUrl;
  final String? backgroundColor;
  final String? fontStyle;
  final String? musicTrackId;
  final String? caption;
  final StatusPrivacy privacy;

  // Sync/identity fields (014-status-feature-integration)
  final String clientStatusId;
  final String authorId;
  final List<String> audience;
  final String syncStatus;
  final List<StatusViewer> viewers;
  final List<StatusReaction> reactions;

  // Device GPS at post time — only set for StatusPrivacy.showOnMap, where it
  // becomes the pin location on viewers' maps.
  final double? longitude;
  final double? latitude;

  const StatusEntity({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.timestamp,
    required this.expiresAt,
    this.isViewed = false,
    this.isMine = false,
    this.contentType = StatusContentType.image, // default for backward compat
    this.textContent,
    this.mediaUrl,
    this.backgroundColor,
    this.fontStyle,
    this.musicTrackId,
    this.caption,
    this.privacy = StatusPrivacy.public, // default
    this.clientStatusId = '',
    this.authorId = '',
    this.audience = const [],
    this.syncStatus = 'synced',
    this.viewers = const [],
    this.reactions = const [],
    this.longitude,
    this.latitude,
  });

  @override
  List<Object?> get props => [
        id,
        authorName,
        authorAvatar,
        timestamp,
        expiresAt,
        isViewed,
        isMine,
        contentType,
        textContent,
        mediaUrl,
        backgroundColor,
        fontStyle,
        musicTrackId,
        caption,
        privacy,
        clientStatusId,
        authorId,
        audience,
        syncStatus,
        viewers,
        reactions,
        longitude,
        latitude,
      ];

  StatusEntity copyWith({
    String? id,
    String? authorName,
    String? authorAvatar,
    DateTime? timestamp,
    DateTime? expiresAt,
    bool? isViewed,
    bool? isMine,
    StatusContentType? contentType,
    String? textContent,
    String? mediaUrl,
    String? backgroundColor,
    String? fontStyle,
    String? musicTrackId,
    String? caption,
    StatusPrivacy? privacy,
    String? clientStatusId,
    String? authorId,
    List<String>? audience,
    String? syncStatus,
    List<StatusViewer>? viewers,
    List<StatusReaction>? reactions,
    double? longitude,
    double? latitude,
  }) {
    return StatusEntity(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      isViewed: isViewed ?? this.isViewed,
      isMine: isMine ?? this.isMine,
      contentType: contentType ?? this.contentType,
      textContent: textContent ?? this.textContent,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontStyle: fontStyle ?? this.fontStyle,
      musicTrackId: musicTrackId ?? this.musicTrackId,
      caption: caption ?? this.caption,
      privacy: privacy ?? this.privacy,
      clientStatusId: clientStatusId ?? this.clientStatusId,
      authorId: authorId ?? this.authorId,
      audience: audience ?? this.audience,
      syncStatus: syncStatus ?? this.syncStatus,
      viewers: viewers ?? this.viewers,
      reactions: reactions ?? this.reactions,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
    );
  }
}
