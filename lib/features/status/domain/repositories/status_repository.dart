import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/status/domain/entities/ai_image_result.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:fpdart/fpdart.dart';

abstract class StatusRepository {
  Future<Either<Failure, List<StatusEntity>>> getRecentStatuses();
  Future<Either<Failure, List<StatusEntity>>> getViewedStatuses();
  Future<Either<Failure, StatusEntity?>> getMyStatus();
  Future<Either<Failure, void>> markAsViewed(String statusId);
  Future<Either<Failure, void>> addStatus(StatusEntity status);
  Stream<StatusEntity> get statusStream;
  Future<Either<Failure, void>> purgeExpiredStatuses();
  
  // New methods for Creation Flow
  Future<Either<Failure, void>> uploadStatus(StatusEntity status);
  Future<Either<Failure, void>> reactToStatus(String statusId, String reaction);
  Future<Either<Failure, void>> replyToStatus(String statusId, String message);
  Future<Either<Failure, AIImageResult>> generateAIImage(String prompt);
}
