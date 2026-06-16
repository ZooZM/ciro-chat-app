import 'package:equatable/equatable.dart';

class StatusViewer extends Equatable {
  final String userId;
  final String name;
  final String avatarUrl;
  final DateTime viewedAt;

  const StatusViewer({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.viewedAt,
  });

  @override
  List<Object?> get props => [userId, name, avatarUrl, viewedAt];
}
