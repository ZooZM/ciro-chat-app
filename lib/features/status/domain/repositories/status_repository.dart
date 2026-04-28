import 'package:ciro_chat_app/core/error/failures.dart';
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
}
