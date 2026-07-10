import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_creator.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_mention.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_reposter.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_status.dart';

class ReelCreatorModel extends ReelCreator {
  const ReelCreatorModel({
    required super.id,
    required super.name,
    required super.avatarUrl,
    required super.viewerFollowing,
    super.username,
  });

  factory ReelCreatorModel.fromJson(Map<String, dynamic> json) {
    return ReelCreatorModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: UrlUtils.resolveMediaUrl(json['avatarUrl'] as String?),
      viewerFollowing: json['viewerFollowing'] as bool? ?? false,
      username: json['username'] as String? ?? '',
    );
  }
}

ReelMention _mentionFromJson(Map<String, dynamic> json) {
  return ReelMention(
    userId: json['userId'] as String? ?? '',
    username: json['username'] as String? ?? '',
  );
}

/// v4 (FR-076): only present on For You repost-injected items.
ReelReposter? _repostedByFromJson(dynamic raw) {
  if (raw is! Map) return null;
  final json = raw.cast<String, dynamic>();
  return ReelReposter(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avatarUrl: UrlUtils.resolveMediaUrl(json['avatarUrl'] as String?),
  );
}

class ReelModel extends Reel {
  const ReelModel({
    required super.id,
    required super.videoUrl,
    required super.thumbnailUrl,
    required super.createdAt,
    required super.creator,
    required super.likesCount,
    required super.commentsCount,
    required super.sharesCount,
    required super.viewerLiked,
    super.description,
    super.hashtags,
    super.mentions,
    super.viewsCount,
    super.viewerSaved,
    super.status,
    super.viewerReposted,
    super.repostedBy,
    super.repostersCount,
    super.topReposters,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    final rawMentions = json['mentions'] as List<dynamic>? ?? const [];
    final rawHashtags = json['hashtags'] as List<dynamic>? ?? const [];
    return ReelModel(
      id: json['id'] as String? ?? '',
      videoUrl: UrlUtils.resolveMediaUrl(json['videoUrl'] as String?),
      thumbnailUrl: UrlUtils.resolveMediaUrl(json['thumbnailUrl'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
      creator: ReelCreatorModel.fromJson(
        (json['creator'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      viewerLiked: json['viewerLiked'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      hashtags: rawHashtags.map((e) => e as String).toList(),
      mentions: rawMentions
          .map((e) => _mentionFromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      viewsCount: json['viewsCount'] as int? ?? 0,
      viewerSaved: json['viewerSaved'] as bool? ?? false,
      status: ReelStatus.fromJson(json['status'] as String?),
      viewerReposted: json['viewerReposted'] as bool? ?? false,
      repostedBy: _repostedByFromJson(json['repostedBy']),
      repostersCount: json['repostersCount'] as int? ?? 0,
      topReposters: (json['topReposters'] as List<dynamic>? ?? const [])
          .map((e) => _repostedByFromJson(e))
          .whereType<ReelReposter>()
          .toList(),
    );
  }
}
