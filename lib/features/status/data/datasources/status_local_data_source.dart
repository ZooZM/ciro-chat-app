import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

abstract class StatusLocalDataSource {
  Future<List<StatusModel>> getStatuses({required bool isViewed});

  /// All of the current user's active (non-expired) statuses, in
  /// chronological order (oldest first) so they can be played back in the
  /// story viewer in the order they were posted.
  Future<List<StatusModel>> getMyStatuses();
  Future<void> cacheStatus(StatusModel status);
  Future<void> markAsViewed(String statusId);
  Future<void> deleteExpiredStatuses();
  Future<void> clearAll();

  /// FR-002/FR-016: own statuses still awaiting server confirmation, for offline-queue replay (T027)
  Future<List<StatusModel>> getPendingStatuses();

  /// Promotes a status from `pending`/`error` to [syncStatus] (e.g. `'synced'`),
  /// optionally renaming its row id to the server-assigned [newId] (statusUploaded ACK)
  /// and replacing the locally-cached [mediaUrl] (a device file path used for
  /// the optimistic insert) with the server-hosted URL once the upload
  /// completes.
  Future<void> updateSyncStatus(
    String clientStatusId,
    String syncStatus, {
    String? newId,
    String? mediaUrl,
  });
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
  Future<List<StatusModel>> getMyStatuses() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'statuses',
      // Exclude permanently-failed uploads (sync_status = 'error') so
      // abandoned attempts - which still point at a local device file path -
      // don't linger as extra "my status" entries.
      where: "is_mine = 1 AND expires_at > ? AND sync_status != 'error'",
      whereArgs: [now],
      orderBy: 'timestamp ASC',
    );
    return maps.map((e) => StatusModel.fromMap(e)).toList();
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

  @override
  Future<List<StatusModel>> getPendingStatuses() async {
    final db = await database;
    final maps = await db.query(
      'statuses',
      where: "sync_status = 'pending' AND is_mine = 1",
      orderBy: 'timestamp ASC',
    );
    return maps.map((e) => StatusModel.fromMap(e)).toList();
  }

  @override
  Future<void> updateSyncStatus(
    String clientStatusId,
    String syncStatus, {
    String? newId,
    String? mediaUrl,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (newId != null) {
        // The server-assigned id may already exist locally (e.g. a feed
        // refresh or socket echo cached it before this ACK arrived).
        // Renaming the pending row's id to a duplicate would violate the
        // PRIMARY KEY constraint, so merge instead: drop the now-redundant
        // pending row and mark the existing one as synced.
        final existing = await txn.query(
          'statuses',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [newId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          await txn.delete(
            'statuses',
            where: 'client_status_id = ? AND id != ?',
            whereArgs: [clientStatusId, newId],
          );
          final existingValues = <String, dynamic>{
            'sync_status': syncStatus,
            'client_status_id': clientStatusId,
          };
          if (mediaUrl != null) existingValues['media_url'] = mediaUrl;
          await txn.update(
            'statuses',
            existingValues,
            where: 'id = ?',
            whereArgs: [newId],
          );
          return;
        }
      }

      final values = <String, dynamic>{'sync_status': syncStatus};
      if (newId != null) values['id'] = newId;
      if (mediaUrl != null) values['media_url'] = mediaUrl;
      await txn.update(
        'statuses',
        values,
        where: 'client_status_id = ?',
        whereArgs: [clientStatusId],
      );
    });
  }
}
