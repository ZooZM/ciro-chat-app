import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/recording.dart';

abstract class RecordingsRepository {
  Future<Either<Failure, Recording>> save(Recording recording);
  Future<Either<Failure, List<Recording>>> list();
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, void>> rename(String id, String newName);
}
