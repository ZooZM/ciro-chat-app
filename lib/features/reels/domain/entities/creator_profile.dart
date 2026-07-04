import 'package:equatable/equatable.dart';
import 'reel_thumb.dart';

class CreatorProfile extends Equatable {
  const CreatorProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.totalLikes,
    required this.videos,
    required this.viewerFollowing,
    required this.isSelf,
    this.username = '',
  });

  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int totalLikes;
  final List<ReelThumb> videos;
  final bool viewerFollowing;
  final bool isSelf;
  final String username;

  CreatorProfile copyWith({
    bool? viewerFollowing,
    int? followersCount,
    List<ReelThumb>? videos,
  }) =>
      CreatorProfile(
        id: id,
        name: name,
        avatarUrl: avatarUrl,
        bio: bio,
        followersCount: followersCount ?? this.followersCount,
        followingCount: followingCount,
        totalLikes: totalLikes,
        videos: videos ?? this.videos,
        viewerFollowing: viewerFollowing ?? this.viewerFollowing,
        isSelf: isSelf,
        username: username,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        bio,
        followersCount,
        followingCount,
        totalLikes,
        videos,
        viewerFollowing,
        isSelf,
        username,
      ];
}
