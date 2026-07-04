import 'package:equatable/equatable.dart';

/// A resolved `@username` mention inside a reel description (FR-047).
class ReelMention extends Equatable {
  const ReelMention({required this.userId, required this.username});

  final String userId;
  final String username;

  @override
  List<Object?> get props => [userId, username];
}
