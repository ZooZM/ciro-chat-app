import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../chat/data/datasources/chat_local_data_source.dart';
import '../models/call_history_record_model.dart';

abstract class CallHistoryLocalDataSource {
  /// Emits the current snapshot on subscribe, then on every [add].
  Stream<List<CallHistoryRecordModel>> watchAll();
  Future<List<CallHistoryRecordModel>> getAll();
  Future<List<CallHistoryRecordModel>> search(String query);
  Future<void> add(CallHistoryRecordModel record);
}

@LazySingleton(as: CallHistoryLocalDataSource)
class CallHistoryLocalDataSourceImpl implements CallHistoryLocalDataSource {
  final ChatLocalDataSource _chatLocalDataSource;
  final StreamController<List<CallHistoryRecordModel>> _controller =
      StreamController<List<CallHistoryRecordModel>>.broadcast();

  CallHistoryLocalDataSourceImpl(this._chatLocalDataSource);

  Database get _db {
    final db = _chatLocalDataSource.database;
    if (db == null) throw Exception('Database not initialized');
    return db;
  }

  @override
  Stream<List<CallHistoryRecordModel>> watchAll() async* {
    yield await getAll();
    yield* _controller.stream;
  }

  @override
  Future<List<CallHistoryRecordModel>> getAll() async {
    final rows = await _db.query('call_history', orderBy: 'started_at DESC');
    return rows.map(CallHistoryRecordModel.fromMap).toList();
  }

  @override
  Future<List<CallHistoryRecordModel>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return getAll();
    final rows = await _db.query(
      'call_history',
      where: 'contact_name LIKE ?',
      whereArgs: ['%$q%'],
      orderBy: 'started_at DESC',
    );
    return rows.map(CallHistoryRecordModel.fromMap).toList();
  }

  @override
  Future<void> add(CallHistoryRecordModel record) async {
    await _db.insert(
      'call_history',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (!_controller.isClosed) {
      _controller.add(await getAll());
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
