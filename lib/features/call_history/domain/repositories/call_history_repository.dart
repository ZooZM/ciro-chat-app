import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/call_history_record.dart';

/// Contract for the in-app call history store (FR-VoIP-04/05).
abstract class CallHistoryRepository {
  /// Reactive stream of all records, newest first. Emits the current snapshot
  /// on subscribe and again whenever a record is added.
  Stream<List<CallHistoryRecord>> watchAll();

  /// One-off filtered query by contact name.
  Future<Either<Failure, List<CallHistoryRecord>>> search(String query);

  /// Persist a record (idempotent on [CallHistoryRecord.id]).
  Future<Either<Failure, Unit>> add(CallHistoryRecord record);
}
