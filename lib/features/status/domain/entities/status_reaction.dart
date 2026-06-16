import 'package:equatable/equatable.dart';

class StatusReaction extends Equatable {
  final String userId;
  final String reaction;
  final DateTime createdAt;

  const StatusReaction({
    required this.userId,
    required this.reaction,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [userId, reaction, createdAt];
}
