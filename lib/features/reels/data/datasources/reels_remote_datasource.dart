import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../models/comment_model.dart';
import '../models/creator_profile_model.dart';
import '../models/reel_model.dart';
import '../models/reels_page_model.dart';
import '../models/search_user_model.dart';

/// Unwraps the backend's `GlobalResponseInterceptor` envelope
/// (`{ success, message, data }`) when present, so this datasource is
/// correct whether or not a given route is actually passed through it.
Map<String, dynamic> _unwrap(dynamic responseData) {
  if (responseData is Map && responseData.containsKey('data') && responseData['data'] is Map) {
    return (responseData['data'] as Map).cast<String, dynamic>();
  }
  return (responseData as Map).cast<String, dynamic>();
}

abstract class ReelsRemoteDataSource {
  Future<ReelsPageModel> fetchFeed({
    String? cursor,
    String? creatorId,
    String? hashtag,
    int limit,
  });
  Future<ReelModel> fetchReel(String id);
  Future<({bool liked, int likesCount})> toggleLike(String id);
  Future<({List<CommentModel> items, String? nextCursor, int commentsCount})> fetchComments(
    String id, {
    String? cursor,
    int limit,
  });
  Future<({CommentModel comment, int commentsCount})> postComment(String id, String text);
  Future<int> recordShare(String id);
  Future<CreatorProfileModel> fetchProfile(String userId);
  Future<({bool following, int followersCount})> toggleFollow(String userId);
  Future<int> recordView(String id);
  Future<bool> toggleSave(String id);
  Future<ReelsPageModel> fetchLiked({String? cursor, int limit});
  Future<ReelsPageModel> fetchSaved({String? cursor, int limit});
  Future<ReelsPageModel> searchReels(String query, {String? cursor, int limit});
  Future<({List<SearchUserModel> items, String? nextCursor})> searchUsers(
    String query, {
    String? cursor,
    int limit,
  });
  Future<bool> toggleBlock(String userId);

  /// v3 (FR-060): multipart upload; [cancelToken] is a real `dio.CancelToken`
  /// — the domain-layer `UploadCancelToken` is adapted to one by the
  /// repository implementation, keeping `dio` out of the domain layer.
  Future<ReelModel> uploadReel({
    required String videoPath,
    String? thumbnailPath,
    required String description,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  });

  Future<void> deleteReel(String id);
}

@LazySingleton(as: ReelsRemoteDataSource)
class ReelsRemoteDataSourceImpl implements ReelsRemoteDataSource {
  ReelsRemoteDataSourceImpl(this.dioClient);

  final DioClient dioClient;

  @override
  Future<ReelsPageModel> fetchFeed({
    String? cursor,
    String? creatorId,
    String? hashtag,
    int limit = 10,
  }) async {
    final response = await dioClient.dio.get(
      '/api/reels',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (creatorId != null) 'creatorId': creatorId,
        if (hashtag != null) 'hashtag': hashtag,
      },
    );
    return ReelsPageModel.fromJson(_unwrap(response.data));
  }

  @override
  Future<ReelModel> fetchReel(String id) async {
    final response = await dioClient.dio.get('/api/reels/$id');
    return ReelModel.fromJson(_unwrap(response.data));
  }

  @override
  Future<({bool liked, int likesCount})> toggleLike(String id) async {
    final response = await dioClient.dio.post('/api/reels/$id/like');
    final json = _unwrap(response.data);
    return (liked: json['liked'] as bool? ?? false, likesCount: json['likesCount'] as int? ?? 0);
  }

  @override
  Future<({List<CommentModel> items, String? nextCursor, int commentsCount})> fetchComments(
    String id, {
    String? cursor,
    int limit = 20,
  }) async {
    final response = await dioClient.dio.get(
      '/api/reels/$id/comments',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    final json = _unwrap(response.data);
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return (
      items: rawItems.map((e) => CommentModel.fromJson((e as Map).cast<String, dynamic>())).toList(),
      nextCursor: json['nextCursor'] as String?,
      commentsCount: json['commentsCount'] as int? ?? 0,
    );
  }

  @override
  Future<({CommentModel comment, int commentsCount})> postComment(String id, String text) async {
    final response = await dioClient.dio.post('/api/reels/$id/comments', data: {'text': text});
    final json = _unwrap(response.data);
    return (
      comment: CommentModel.fromJson((json['comment'] as Map).cast<String, dynamic>()),
      commentsCount: json['commentsCount'] as int? ?? 0,
    );
  }

  @override
  Future<int> recordShare(String id) async {
    final response = await dioClient.dio.post('/api/reels/$id/share');
    final json = _unwrap(response.data);
    return json['sharesCount'] as int? ?? 0;
  }

  @override
  Future<CreatorProfileModel> fetchProfile(String userId) async {
    final response = await dioClient.dio.get('/api/users/$userId/profile');
    return CreatorProfileModel.fromJson(_unwrap(response.data));
  }

  @override
  Future<({bool following, int followersCount})> toggleFollow(String userId) async {
    final response = await dioClient.dio.post('/api/users/$userId/follow');
    final json = _unwrap(response.data);
    return (
      following: json['following'] as bool? ?? false,
      followersCount: json['followersCount'] as int? ?? 0,
    );
  }

  @override
  Future<int> recordView(String id) async {
    final response = await dioClient.dio.post('/api/reels/$id/view');
    final json = _unwrap(response.data);
    return json['viewsCount'] as int? ?? 0;
  }

  @override
  Future<bool> toggleSave(String id) async {
    final response = await dioClient.dio.post('/api/reels/$id/save');
    final json = _unwrap(response.data);
    return json['saved'] as bool? ?? false;
  }

  @override
  Future<ReelsPageModel> fetchLiked({String? cursor, int limit = 10}) async {
    final response = await dioClient.dio.get(
      '/api/reels/liked',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return ReelsPageModel.fromJson(_unwrap(response.data));
  }

  @override
  Future<ReelsPageModel> fetchSaved({String? cursor, int limit = 10}) async {
    final response = await dioClient.dio.get(
      '/api/reels/saved',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return ReelsPageModel.fromJson(_unwrap(response.data));
  }

  @override
  Future<ReelsPageModel> searchReels(String query, {String? cursor, int limit = 10}) async {
    final response = await dioClient.dio.get(
      '/api/reels/search',
      queryParameters: {'q': query, 'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return ReelsPageModel.fromJson(_unwrap(response.data));
  }

  @override
  Future<({List<SearchUserModel> items, String? nextCursor})> searchUsers(
    String query, {
    String? cursor,
    int limit = 10,
  }) async {
    final response = await dioClient.dio.get(
      '/api/users/search',
      queryParameters: {'q': query, 'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    final json = _unwrap(response.data);
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return (
      items: rawItems
          .map((e) => SearchUserModel.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  Future<bool> toggleBlock(String userId) async {
    final response = await dioClient.dio.post('/api/users/$userId/block');
    final json = _unwrap(response.data);
    return json['blocked'] as bool? ?? false;
  }

  @override
  Future<ReelModel> uploadReel({
    required String videoPath,
    String? thumbnailPath,
    required String description,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final bytes = await File(videoPath).length();
      debugPrint('[ReelsRemote] uploading video '
          '${(bytes / 1048576).toStringAsFixed(1)}MB');
    } catch (_) {}
    final formData = FormData.fromMap({
      'description': description,
      'video': await MultipartFile.fromFile(
        videoPath,
        filename: videoPath.split('/').last,
      ),
      if (thumbnailPath != null)
        'thumbnail': await MultipartFile.fromFile(
          thumbnailPath,
          filename: thumbnailPath.split('/').last,
        ),
    });
    final response = await dioClient.dio.post(
      '/api/reels',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return ReelModel.fromJson(_unwrap(response.data));
  }

  @override
  Future<void> deleteReel(String id) async {
    await dioClient.dio.delete('/api/reels/$id');
  }
}
