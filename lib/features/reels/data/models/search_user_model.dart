import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/search_user.dart';

class SearchUserModel extends SearchUser {
  const SearchUserModel({
    required super.id,
    required super.username,
    required super.name,
    required super.avatarUrl,
    required super.viewerFollowing,
  });

  factory SearchUserModel.fromJson(Map<String, dynamic> json) {
    return SearchUserModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: UrlUtils.resolveMediaUrl(json['avatarUrl'] as String?),
      viewerFollowing: json['viewerFollowing'] as bool? ?? false,
    );
  }
}
