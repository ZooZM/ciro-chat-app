import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/call_history_record.dart';
import '../../domain/repositories/call_history_repository.dart';

sealed class CallHistoryState extends Equatable {
  const CallHistoryState();
  @override
  List<Object?> get props => [];
}

class CallHistoryLoading extends CallHistoryState {
  const CallHistoryLoading();
}

class CallHistoryLoaded extends CallHistoryState {
  final List<CallHistoryRecord> records;
  final String query;

  const CallHistoryLoaded({required this.records, this.query = ''});

  @override
  List<Object?> get props => [records, query];
}

class CallHistoryError extends CallHistoryState {
  final String message;
  const CallHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

@injectable
class CallHistoryCubit extends Cubit<CallHistoryState> {
  final CallHistoryRepository _repo;
  StreamSubscription<List<CallHistoryRecord>>? _sub;
  List<CallHistoryRecord> _all = const [];
  String _query = '';

  CallHistoryCubit(this._repo) : super(const CallHistoryLoading());

  void load() {
    _sub?.cancel();
    _sub = _repo.watchAll().listen(
      (records) {
        _all = records;
        emit(CallHistoryLoaded(records: _filtered(), query: _query));
      },
      onError: (e) => emit(CallHistoryError('Failed to load call history: $e')),
    );
  }

  void search(String query) {
    _query = query;
    emit(CallHistoryLoaded(records: _filtered(), query: _query));
  }

  List<CallHistoryRecord> _filtered() {
    if (_query.trim().isEmpty) return _all;
    final q = _query.trim().toLowerCase();
    return _all.where((r) => r.contactName.toLowerCase().contains(q)).toList();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
