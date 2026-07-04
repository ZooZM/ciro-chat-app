import 'package:equatable/equatable.dart';
import 'reel_creator.dart';
import 'reel_mention.dart';
import 'reel_status.dart';

class Reel extends Equatable {
  const Reel({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.createdAt,
    required this.creator,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewerLiked,
    this.description = '',
    this.hashtags = const [],
    this.mentions = const [],
    this.viewsCount = 0,
    this.viewerSaved = false,
    this.status = ReelStatus.published,
  });

  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final DateTime createdAt;
  final ReelCreator creator;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool viewerLiked;

  /// FR-047: supports #hashtags and @mentions.
  final String description;
  final List<String> hashtags;
  final List<ReelMention> mentions;

  /// FR-048: deduped per user per reel.
  final int viewsCount;

  /// FR-049: private — no public counter.
  final bool viewerSaved;

  /// v3 (FR-061): defaults to [ReelStatus.published] — tolerant of older
  /// payloads that predate the moderation pipeline.
  final ReelStatus status;

  Reel copyWith({
    ReelCreator? creator,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? viewerLiked,
    bool? viewerSaved,
  }) =>
      Reel(
        id: id,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        createdAt: createdAt,
        creator: creator ?? this.creator,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        sharesCount: sharesCount ?? this.sharesCount,
        viewerLiked: viewerLiked ?? this.viewerLiked,
        description: description,
        hashtags: hashtags,
        mentions: mentions,
        viewsCount: viewsCount,
        viewerSaved: viewerSaved ?? this.viewerSaved,
        status: status,
      );

  @override
  List<Object?> get props => [
        id,
        videoUrl,
        thumbnailUrl,
        createdAt,
        creator,
        likesCount,
        commentsCount,
        sharesCount,
        viewerLiked,
        description,
        hashtags,
        mentions,
        viewsCount,
        viewerSaved,
        status,
      ];
}
