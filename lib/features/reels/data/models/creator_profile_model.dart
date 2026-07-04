import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/creator_profile.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_status.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_thumb.dart';

class CreatorProfileModel extends CreatorProfile {
  const CreatorProfileModel({
    required super.id,
    required super.name,
    required super.avatarUrl,
    required super.bio,
    required super.followersCount,
    required super.followingCount,
    required super.totalLikes,
    required super.videos,
    required super.viewerFollowing,
    required super.isSelf,
    super.username,
  });

  factory CreatorProfileModel.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final viewer = (json['viewer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawVideos = json['videos'] as List<dynamic>? ?? const [];

    return CreatorProfileModel(
      id: user['id'] as String? ?? '',
      name: user['name'] as String? ?? '',
      avatarUrl: UrlUtils.resolveMediaUrl(user['avatarUrl'] as String?),
      bio: user['bio'] as String? ?? '',
      followersCount: stats['followers'] as int? ?? 0,
      followingCount: stats['following'] as int? ?? 0,
      totalLikes: stats['totalLikes'] as int? ?? 0,
      videos: rawVideos.map((e) {
        final map = (e as Map).cast<String, dynamic>();
        return ReelThumb(
          id: map['id'] as String? ?? '',
          thumbnailUrl: UrlUtils.resolveMediaUrl(map['thumbnailUrl'] as String?),
          status: ReelStatus.fromJson(map['status'] as String?),
        );
      }).toList(),
      viewerFollowing: viewer['following'] as bool? ?? false,
      isSelf: viewer['isSelf'] as bool? ?? false,
      username: user['username'] as String? ?? '',
    );
  }
}
