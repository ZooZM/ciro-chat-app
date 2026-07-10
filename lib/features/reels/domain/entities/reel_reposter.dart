import 'package:equatable/equatable.dart';

/// v4 (FR-076/FR-077): the attributed reposter on a For You repost-injected
/// item — drives the "[name] reposted" / "You reposted" badge.
class ReelReposter extends Equatable {
  const ReelReposter({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String name;
  final String avatarUrl;

  @override
  List<Object?> get props => [id, username, name, avatarUrl];
}
