import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/status/data/datasources/status_local_data_source.dart';
import 'package:ciro_chat_app/features/status/data/datasources/status_remote_data_source.dart';
import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:ciro_chat_app/features/status/domain/entities/ai_image_result.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/status_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: StatusRepository)
class StatusRepositoryImpl implements StatusRepository {
  final StatusLocalDataSource localDataSource;
  final StatusRemoteDataSource remoteDataSource;

  StatusRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, List<StatusEntity>>> getRecentStatuses() async {
    try {
      final statuses = await localDataSource.getStatuses(isViewed: false);
      return Right(statuses);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StatusEntity>>> getViewedStatuses() async {
    try {
      final statuses = await localDataSource.getStatuses(isViewed: true);
      return Right(statuses);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, StatusEntity?>> getMyStatus() async {
    try {
      final status = await localDataSource.getMyStatus();
      return Right(status);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsViewed(String statusId) async {
    try {
      await localDataSource.markAsViewed(statusId);
      await remoteDataSource.notifyViewed(statusId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addStatus(StatusEntity status) async {
    return uploadStatus(status);
  }

  @override
  Future<Either<Failure, void>> uploadStatus(StatusEntity status) async {
    try {
      final statusModel = StatusModel(
        id: status.id,
        authorName: status.authorName,
        authorAvatar: status.authorAvatar,
        timestamp: status.timestamp,
        expiresAt: status.expiresAt,
        isViewed: status.isViewed,
        isMine: true,
        contentType: status.contentType,
        textContent: status.textContent,
        mediaUrl: status.mediaUrl,
        backgroundColor: status.backgroundColor,
        fontStyle: status.fontStyle,
        musicTrackId: status.musicTrackId,
        caption: status.caption,
        privacy: status.privacy,
      );
      // Always cache it first for offline capability
      await localDataSource.cacheStatus(statusModel);
      try {
        await remoteDataSource.uploadStatus(statusModel);
      } catch (e) {
        // If upload fails, it remains in local cache as pending.
        // A retry mechanism should pick it up. For now we return ServerFailure.
        return Left(ServerFailure(e.toString()));
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> reactToStatus(String statusId, String reaction) async {
    try {
      await remoteDataSource.reactToStatus(statusId, reaction);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> replyToStatus(String statusId, String message) async {
    try {
      await remoteDataSource.replyToStatus(statusId, message);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AIImageResult>> generateAIImage(String prompt) async {
    try {
      final result = await remoteDataSource.generateAIImage(prompt);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<StatusEntity> get statusStream => remoteDataSource.onStatusReceived.map((model) {
        // Cache immediately upon receiving
        localDataSource.cacheStatus(model);
        return model;
      });

  @override
  Future<Either<Failure, void>> purgeExpiredStatuses() async {
    try {
      await localDataSource.deleteExpiredStatuses();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
