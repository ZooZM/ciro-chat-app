import 'package:equatable/equatable.dart';

class ReelCreator extends Equatable {
  const ReelCreator({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.viewerFollowing,
    this.username = '',
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool viewerFollowing;
  final String username;

  ReelCreator copyWith({bool? viewerFollowing}) => ReelCreator(
        id: id,
        name: name,
        avatarUrl: avatarUrl,
        viewerFollowing: viewerFollowing ?? this.viewerFollowing,
        username: username,
      );

  @override
  List<Object?> get props => [id, name, avatarUrl, viewerFollowing, username];
}
