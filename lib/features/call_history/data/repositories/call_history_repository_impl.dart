import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/call_history_record.dart';
import '../../domain/repositories/call_history_repository.dart';
import '../datasources/call_history_local_data_source.dart';
import '../models/call_history_record_model.dart';

@LazySingleton(as: CallHistoryRepository)
class CallHistoryRepositoryImpl implements CallHistoryRepository {
  final CallHistoryLocalDataSource _local;

  CallHistoryRepositoryImpl(this._local);

  @override
  Stream<List<CallHistoryRecord>> watchAll() => _local.watchAll();

  @override
  Future<Either<Failure, List<CallHistoryRecord>>> search(String query) async {
    try {
      final results = await _local.search(query);
      return Right(results);
    } catch (e) {
      return Left(CacheFailure('Failed to search call history: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> add(CallHistoryRecord record) async {
    try {
      await _local.add(CallHistoryRecordModel.fromEntity(record));
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Failed to save call history: $e'));
    }
  }
}
