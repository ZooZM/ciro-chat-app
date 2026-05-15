import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';
import '../../../chat/data/datasources/chat_local_data_source.dart';
import '../models/recording_model.dart';

abstract class RecordingsLocalDataSource {
  Future<void> save(RecordingModel recording);
  Future<List<RecordingModel>> list();
  Future<void> delete(String id);
  Future<void> rename(String id, String newName);
}

@LazySingleton(as: RecordingsLocalDataSource)
class RecordingsLocalDataSourceImpl implements RecordingsLocalDataSource {
  final ChatLocalDataSource _chatLocalDataSource;

  const RecordingsLocalDataSourceImpl(this._chatLocalDataSource);

  Database get _db {
    final db = _chatLocalDataSource.database;
    if (db == null) throw Exception('Database not initialized');
    return db;
  }

  @override
  Future<void> save(RecordingModel recording) async {
    await _db.insert(
      'recordings',
      recording.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<RecordingModel>> list() async {
    final rows = await _db.query(
      'recordings',
      orderBy: 'created_at DESC',
    );

    // FR-035: orphan recovery — filter out rows whose file no longer exists
    final valid = <RecordingModel>[];
    for (final row in rows) {
      final model = RecordingModel.fromMap(row);
      if (File(model.filePath).existsSync()) {
        valid.add(model);
      } else {
        // Prune stale row silently
        await _db.delete('recordings', where: 'id = ?', whereArgs: [model.id]);
      }
    }
    return valid;
  }

  @override
  Future<void> delete(String id) async {
    final rows = await _db.query(
      'recordings',
      columns: ['file_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final filePath = rows.first['file_path'] as String;
      final file = File(filePath);
      if (file.existsSync()) await file.delete();
    }
    await _db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> rename(String id, String newName) async {
    await _db.update(
      'recordings',
      {'display_name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
