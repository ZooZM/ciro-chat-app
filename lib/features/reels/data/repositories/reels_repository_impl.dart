import 'package:flutter/foundation.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/creator_profile.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_comment.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reels_page.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/report_reason.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/search_user.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/upload_cancel_token.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import '../datasources/reels_remote_datasource.dart';

@LazySingleton(as: ReelsRepository)
class ReelsRepositoryImpl implements ReelsRepository {
  ReelsRepositoryImpl(this.remoteDataSource);

  final ReelsRemoteDataSource remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      debugPrint('[ReelsRepo] DioException type=${e.type} '
          'status=${e.response?.statusCode} body=${e.response?.data}');
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReelsPage>> fetchFeed({
    String? cursor,
    String? creatorId,
    String? hashtag,
  }) {
    return _guard(
      () => remoteDataSource.fetchFeed(
        cursor: cursor,
        creatorId: creatorId,
        hashtag: hashtag,
        limit: 10,
      ),
    );
  }

  @override
  Future<Either<Failure, Reel>> fetchReel(String id) {
    return _guard(() => remoteDataSource.fetchReel(id));
  }

  @override
  Future<Either<Failure, ({bool liked, int likesCount})>> toggleLike(String id) {
    return _guard(() => remoteDataSource.toggleLike(id));
  }

  @override
  Future<Either<Failure, ({List<ReelComment> items, String? nextCursor, int commentsCount})>>
      fetchComments(String id, {String? cursor}) {
    return _guard(() async {
      final result = await remoteDataSource.fetchComments(id, cursor: cursor, limit: 20);
      return (
        items: result.items.cast<ReelComment>(),
        nextCursor: result.nextCursor,
        commentsCount: result.commentsCount,
      );
    });
  }

  @override
  Future<Either<Failure, ({ReelComment comment, int commentsCount})>> postComment(
    String id,
    String text,
  ) {
    return _guard(() async {
      final result = await remoteDataSource.postComment(id, text);
      return (comment: result.comment as ReelComment, commentsCount: result.commentsCount);
    });
  }

  @override
  Future<Either<Failure, int>> recordShare(String id) {
    return _guard(() => remoteDataSource.recordShare(id));
  }

  @override
  Future<Either<Failure, CreatorProfile>> fetchProfile(String userId) {
    return _guard(() => remoteDataSource.fetchProfile(userId));
  }

  @override
  Future<Either<Failure, ({bool following, int followersCount})>> toggleFollow(String userId) {
    return _guard(() => remoteDataSource.toggleFollow(userId));
  }

  @override
  Future<Either<Failure, int>> recordView(String id) {
    return _guard(() => remoteDataSource.recordView(id));
  }

  @override
  Future<Either<Failure, bool>> toggleSave(String id) {
    return _guard(() => remoteDataSource.toggleSave(id));
  }

  @override
  Future<Either<Failure, ReelsPage>> fetchLiked({String? cursor}) {
    return _guard(() => remoteDataSource.fetchLiked(cursor: cursor, limit: 10));
  }

  @override
  Future<Either<Failure, ReelsPage>> fetchSaved({String? cursor}) {
    return _guard(() => remoteDataSource.fetchSaved(cursor: cursor, limit: 10));
  }

  @override
  Future<Either<Failure, ReelsPage>> fetchReposted({String? userId, String? cursor}) {
    return _guard(
      () => remoteDataSource.fetchReposted(userId: userId, cursor: cursor, limit: 10),
    );
  }

  @override
  Future<Either<Failure, ReelsPage>> searchReels(String query, {String? cursor}) {
    return _guard(() => remoteDataSource.searchReels(query, cursor: cursor, limit: 10));
  }

  @override
  Future<Either<Failure, ({List<SearchUser> items, String? nextCursor})>> searchUsers(
    String query, {
    String? cursor,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.searchUsers(query, cursor: cursor, limit: 10);
      return (items: result.items.cast<SearchUser>(), nextCursor: result.nextCursor);
    });
  }

  @override
  Future<Either<Failure, bool>> toggleBlock(String userId) {
    return _guard(() => remoteDataSource.toggleBlock(userId));
  }

  @override
  Future<Either<Failure, bool>> reportReel(
    String id,
    ReportReason reason, {
    String? customReason,
  }) async {
    try {
      final alreadyReported = await remoteDataSource.reportReel(
        id,
        reason.toJson(),
        customReason: customReason,
      );
      return Right(alreadyReported);
    } on DioException catch (e) {
      // v4 (FR-069): the daily report cap gets its own Failure type so the
      // UI can show a distinct notice, not the generic report-failed one.
      if (e.response?.statusCode == 429) {
        return const Left(RateLimitedFailure());
      }
      debugPrint('[ReelsRepo] DioException type=${e.type} '
          'status=${e.response?.statusCode} body=${e.response?.data}');
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Reel>> uploadReel({
    required String videoPath,
    String? thumbnailPath,
    required String description,
    void Function(int sent, int total)? onSendProgress,
    UploadCancelToken? cancelToken,
  }) {
    return _guard(() {
      // Adapts the domain-safe UploadCancelToken to a real dio.CancelToken
      // (constitution I — dio stays out of the domain layer).
      CancelToken? dioCancelToken;
      if (cancelToken != null) {
        dioCancelToken = CancelToken();
        cancelToken.onCancel(() => dioCancelToken?.cancel());
      }
      return remoteDataSource.uploadReel(
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        description: description,
        onSendProgress: onSendProgress,
        cancelToken: dioCancelToken,
      );
    });
  }

  @override
  Future<Either<Failure, Unit>> deleteReel(String id) {
    return _guard(() async {
      await remoteDataSource.deleteReel(id);
      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> repostReel(String id) {
    return _guard(() async {
      await remoteDataSource.repostReel(id);
      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> unrepostReel(String id) {
    return _guard(() async {
      await remoteDataSource.unrepostReel(id);
      return unit;
    });
  }

  @override
  Future<Either<Failure, ReelsPage>> fetchFollowing({String? cursor}) {
    return _guard(() => remoteDataSource.fetchFollowing(cursor: cursor, limit: 10));
  }

  @override
  Future<Either<Failure, ({List<FollowedUser> items, String? nextCursor})>> getFollowingUsers({
    String? cursor,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.getFollowingUsers(cursor: cursor, limit: 50);
      return (items: result.items.cast<FollowedUser>(), nextCursor: result.nextCursor);
    });
  }

  @override
  Future<Either<Failure, ({List<FollowedUser> items, String? nextCursor})>> fetchReposters(
    String reelId, {
    String? cursor,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.getReposters(reelId, cursor: cursor, limit: 20);
      return (items: result.items.cast<FollowedUser>(), nextCursor: result.nextCursor);
    });
  }
}
