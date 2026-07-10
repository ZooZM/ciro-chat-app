import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';

class FollowedUserModel extends FollowedUser {
  const FollowedUserModel({
    required super.id,
    required super.username,
    required super.name,
    super.avatarUrl,
  });

  factory FollowedUserModel.fromJson(Map<String, dynamic> json) {
    return FollowedUserModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: UrlUtils.resolveMediaUrl(json['avatarUrl'] as String?),
    );
  }
}
