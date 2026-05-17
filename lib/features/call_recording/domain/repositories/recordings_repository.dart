import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/recording.dart';

abstract class RecordingsRepository {
  Future<Either<Failure, Recording>> save(Recording recording);
  Future<Either<Failure, List<Recording>>> list();
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, void>> rename(String id, String newName);
  // FR-035: post-save gallery path and share-pipeline status updates
  Future<Either<Failure, void>> updateGalleryPath(String id, String galleryPath);
  Future<Either<Failure, void>> updateShareStatus(
    String id,
    ShareStatus status, {
    String? sharedMessageId,
  });
}
