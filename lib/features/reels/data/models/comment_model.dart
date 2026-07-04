import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_comment.dart';

class CommentModel extends ReelComment {
  const CommentModel({
    required super.id,
    required super.authorId,
    required super.authorName,
    required super.authorAvatarUrl,
    required super.text,
    required super.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorAvatarUrl: UrlUtils.resolveMediaUrl(json['authorAvatarUrl'] as String?),
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }
}
