import 'package:equatable/equatable.dart';

class StatusEntity extends Equatable {
  final String id;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;
  final DateTime expiresAt;
  final bool isViewed;
  final bool isMine;

  const StatusEntity({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.timestamp,
    required this.expiresAt,
    this.isViewed = false,
    this.isMine = false,
  });

  @override
  List<Object?> get props => [
        id,
        authorName,
        authorAvatar,
        timestamp,
        expiresAt,
        isViewed,
        isMine,
      ];
}
