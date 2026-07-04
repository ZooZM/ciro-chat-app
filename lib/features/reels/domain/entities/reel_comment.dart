import 'package:equatable/equatable.dart';

class ReelComment extends Equatable {
  const ReelComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String text;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, authorId, authorName, authorAvatarUrl, text, createdAt];
}
