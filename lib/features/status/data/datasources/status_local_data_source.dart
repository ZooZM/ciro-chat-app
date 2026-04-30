import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

abstract class StatusLocalDataSource {
  Future<List<StatusModel>> getStatuses({required bool isViewed});
  Future<StatusModel?> getMyStatus();
  Future<void> cacheStatus(StatusModel status);
  Future<void> markAsViewed(String statusId);
  Future<void> deleteExpiredStatuses();
  Future<void> clearAll();
}

@LazySingleton(as: StatusLocalDataSource)
class StatusLocalDataSourceImpl implements StatusLocalDataSource {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ciro_chat.db_v1');
    _db = await openDatabase(path);
    return _db!;
  }

  @override
  Future<List<StatusModel>> getStatuses({required bool isViewed}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'statuses',
      where: 'is_viewed = ? AND is_mine = 0 AND expires_at > ?',
      whereArgs: [isViewed ? 1 : 0, now],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => StatusModel.fromMap(e)).toList();
  }

  @override
  Future<StatusModel?> getMyStatus() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'statuses',
      where: 'is_mine = 1 AND expires_at > ?',
      whereArgs: [now],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return StatusModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<void> cacheStatus(StatusModel status) async {
    final db = await database;
    await db.insert(
      'statuses',
      status.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> markAsViewed(String statusId) async {
    final db = await database;
    await db.update(
      'statuses',
      {'is_viewed': 1},
      where: 'id = ?',
      whereArgs: [statusId],
    );
  }

  @override
  Future<void> deleteExpiredStatuses() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete(
      'statuses',
      where: 'expires_at <= ?',
      whereArgs: [now],
    );
  }

  @override
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('statuses');
  }
}
