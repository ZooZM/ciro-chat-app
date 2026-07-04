import 'package:equatable/equatable.dart';

/// A user search result row (FR-057) — username/name substring match.
class SearchUser extends Equatable {
  const SearchUser({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.viewerFollowing,
  });

  final String id;
  final String username;
  final String name;
  final String avatarUrl;
  final bool viewerFollowing;

  @override
  List<Object?> get props => [id, username, name, avatarUrl, viewerFollowing];
}
