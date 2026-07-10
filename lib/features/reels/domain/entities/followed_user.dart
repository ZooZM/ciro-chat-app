import 'package:equatable/equatable.dart';

/// v5 (FR-083/FR-084): an entry in the caller's followed-users list, used to
/// populate the post-details `@`-mention suggestion overlay.
class FollowedUser extends Equatable {
  const FollowedUser({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String name;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, username, name, avatarUrl];
}
