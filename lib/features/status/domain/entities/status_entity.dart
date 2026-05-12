import 'package:equatable/equatable.dart';
import 'status_content_type.dart';
import 'status_privacy.dart';

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
      ];
}
