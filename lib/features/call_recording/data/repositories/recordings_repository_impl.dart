import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/recording.dart';
import '../../domain/repositories/recordings_repository.dart';
import '../datasources/recordings_local_data_source.dart';
import '../models/recording_model.dart';

@LazySingleton(as: RecordingsRepository)
class RecordingsRepositoryImpl implements RecordingsRepository {
  final RecordingsLocalDataSource _dataSource;

  const RecordingsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, Recording>> save(Recording recording) async {
    try {
      final model = RecordingModel.fromEntity(recording);
      await _dataSource.save(model);
      return Right(recording);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Recording>>> list() async {
    try {
      final models = await _dataSource.list();
      return Right(models);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await _dataSource.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> rename(String id, String newName) async {
    try {
      await _dataSource.rename(id, newName);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateGalleryPath(
    String id,
    String galleryPath,
  ) async {
    try {
      await _dataSource.updateGalleryPath(id, galleryPath);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateShareStatus(
    String id,
    ShareStatus status, {
    String? sharedMessageId,
  }) async {
    try {
      await _dataSource.updateShareStatus(id, status, sharedMessageId: sharedMessageId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
