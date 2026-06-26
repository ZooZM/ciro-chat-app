import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/foundation.dart';

abstract class ChatLocalDataSource {
  Future<void> initDB();
  Future<void> saveMessage(
    Message message, {
    bool incrementUnread = false,
    String roomName = '',
    String roomAvatarUrl = '',
    String roomPhoneNumber = '',
  });
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status, {
    DateTime? createdAt,
  });

  /// Updates the [fileUrl] and [metadata] of an already-saved message.
  /// Called after a successful upload to replace the optimistic placeholder.
  Future<void> updateMessageMedia(
    String messageId,
    String fileUrl,
    Map<String, dynamic> metadata,
  );

  Future<List<Message>> getRoomMessages(
    String roomId, {
    int limit = 30,
    int offset = 0,
  });
  Stream<List<Message>> watchRoomMessages(String roomId, {int limit = 30});
  Future<void> saveRoom(ChatSession room);
  Stream<List<ChatSession>> watchRecentChats();
  Stream<List<ChatSession>> watchContacts();
  Future<void> upsertContacts(List<ChatSession> contacts);
  Future<void> resetUnreadCount(String roomId);
  void closeRoomStream(String roomId);
  void setRoomDisplayLimit(String roomId, int limit); // T006 — BN-03
  Future<void> clearAllData();

  /// Returns all messages with [MessageStatus.pending], oldest-first.
  Future<List<Message>> getPendingMessages();

  /// Returns all messages stuck in [pending] OR [sent] state, oldest-first.
  Future<List<Message>> getStuckMessages();

  /// Returns the timestamp of the most-recent message stored for [roomId],
  /// or null if the room has no messages locally. Used by offline recovery (BN-06).
  Future<DateTime?> getLastMessageTimestamp(String roomId);

  /// Returns a locally-cached [ChatSession] by its ID, or null if not found.
  Future<ChatSession?> getRoomById(String roomId);

  /// Returns the current [MessageStatus] of a single message by its ID.
  Future<MessageStatus?> getMessageStatus(String messageId);

  /// Deletes a message from the local DB and removes any associated cached file.
  Future<void> deleteMessage(String messageId);

  /// Deletes a room and all its associated messages.
  Future<void> deleteRoom(String roomId);

  /// Retrieves a specific message by its ID.
  Future<Message?> getMessageById(String messageId);

  /// Retrieves cached waveform samples for a message.
  Future<List<double>?> getWaveformCache(String messageId);

  /// Saves waveform samples to a message's metadata.
  Future<void> saveWaveformCache(String messageId, List<double> samples);

  Future<List<Message>> searchMessages(String roomId, String query);
  Future<List<Message>> getSharedMedia(String roomId);

  /// FR-022: Soft-delete a message in local DB — sets is_deleted = 1.
  Future<void> markMessageDeleted(String clientMessageId);

  /// FR-024: Returns messages containing URLs (for Links tab).
  Future<List<Message>> getSharedLinks(String roomId);

  /// FR-024: Returns messages where type = 'file' (for Docs tab).
  Future<List<Message>> getSharedDocs(String roomId);

  /// FR-024: Returns photo/video count summary for ChatInfoScreen.
  Future<Map<String, int>> getMediaCount(String roomId);

  Future<void> updateUserOnlineStatus(String userId, bool isOnline);

  /// Exposes the underlying SQLite [Database] instance for use by other
  /// datasources that share the same DB file (e.g., RecordingsLocalDataSource).
  Database? get database;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Returns a short, human-readable preview for the inbox "last message" row.
String _mediaPreview(MessageType type) {
  switch (type) {
    case MessageType.image:
      return '📷 Photo';
    case MessageType.file:
      return '📎 File';
    case MessageType.voiceNote:
      return '🎤 Voice note';
    case MessageType.audio:
      return '🎵 Audio';
    case MessageType.contact:
      return '👤 Contact';
    // case MessageType.system:
    //   return 'ℹ️ System';
    case MessageType.location:
      return '📍 Location';
    case MessageType.poll:
      return '📊 Poll';
    case MessageType.event:
      return '📅 Event';
    case MessageType.video:
      return '🎬 Video';
    case MessageType.text:
      return '';
    default:
      return '';
  }
}

/// Returns an integer rank for monotonic status promotion (FR-019).
/// Higher rank = more "advanced" status. Updates are only allowed forward.
int _statusRank(MessageStatus status) {
  switch (status) {
    case MessageStatus.pending:
      return 0;
    case MessageStatus.sent:
      return 1;
    case MessageStatus.delivered:
      return 2;
    case MessageStatus.read:
      return 3;
    case MessageStatus.error:
      return -1;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

@LazySingleton(as: ChatLocalDataSource)
class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  Database? _db;

  @override
  Database? get database => _db;

  final Map<String, StreamController<List<Message>>> _roomStreamControllers =
      {};
  final StreamController<List<ChatSession>> _recentChatsController =
      StreamController<List<ChatSession>>.broadcast();
  final StreamController<List<ChatSession>> _contactsController =
      StreamController<List<ChatSession>>.broadcast();
  // T005 — BN-03: tracks the highest message count shown per room so that
  // _dispatchUpdateForRoom never narrows a paginated-out list back to 30.
  final Map<String, int> _roomDisplayLimits = {};

  // ── Schema helpers ──────────────────────────────────────────────────────────

  static const _messagesSchema = '''
    CREATE TABLE messages(
      id                TEXT PRIMARY KEY,
      client_message_id TEXT,
      room_id           TEXT,
      sender_id         TEXT,
      sender_phone      TEXT DEFAULT '',
      sender_name       TEXT DEFAULT '',
      text              TEXT,
      timestamp         INTEGER,
      status            TEXT,
      type              TEXT DEFAULT 'text',
      file_url          TEXT DEFAULT '',
      metadata          TEXT DEFAULT '',
      is_deleted        INTEGER DEFAULT 0
    )
  ''';

  static const _roomsSchema = '''
    CREATE TABLE rooms(
      id                  TEXT PRIMARY KEY,
      name                TEXT,
      lastMessage         TEXT,
      lastMessageId       TEXT,
      timestamp           TEXT,
      unreadCount         INTEGER,
      isOnline            INTEGER,
      avatarUrl           TEXT,
      phoneNumber         TEXT DEFAULT '',
      lastMessageSenderId TEXT DEFAULT '',
      lastMessageStatus   TEXT DEFAULT 'pending',
      type                TEXT DEFAULT 'PRIVATE',
      participants        TEXT DEFAULT '[]',
      admins              TEXT DEFAULT '[]'
    )
  ''';

  static const _contactsSchema = '''
    CREATE TABLE contacts(
      id          TEXT PRIMARY KEY,
      name        TEXT,
      phoneNumber TEXT,
      avatarUrl   TEXT,
      isOnline    INTEGER
    )
  ''';

  static const _statusesSchema = '''
    CREATE TABLE statuses(
      id           TEXT PRIMARY KEY,
      author_name  TEXT,
      author_avatar TEXT,
      timestamp    INTEGER,
      expires_at   INTEGER,
      is_viewed    INTEGER DEFAULT 0,
      is_mine      INTEGER DEFAULT 0,
      content_type TEXT DEFAULT 'image',
      text_content TEXT,
      media_url    TEXT,
      background_color TEXT,
      font_style   TEXT,
      music_track_id TEXT,
      caption      TEXT,
      privacy      TEXT DEFAULT 'public',
      client_status_id TEXT DEFAULT '',
      sync_status  TEXT DEFAULT 'synced',
      audience_json TEXT DEFAULT '[]',
      author_id    TEXT DEFAULT ''
    )
  ''';

  // T002 — BN-01: Secondary indexes for all hot query paths.
  static const _indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_msg_room_ts    ON messages(room_id, timestamp DESC)',
    'CREATE INDEX IF NOT EXISTS idx_msg_client_id  ON messages(client_message_id)',
    'CREATE INDEX IF NOT EXISTS idx_msg_status     ON messages(status)',
    'CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phoneNumber)',
    'CREATE INDEX IF NOT EXISTS idx_statuses_client_id ON statuses(client_status_id)',
  ];

  static const _recordingsSchema = '''
    CREATE TABLE IF NOT EXISTS recordings (
      id                TEXT PRIMARY KEY,
      call_room_id      TEXT NOT NULL,
      call_room_name    TEXT NOT NULL,
      file_path         TEXT NOT NULL,
      gallery_path      TEXT,
      duration_ms       INTEGER NOT NULL DEFAULT 0,
      has_video         INTEGER NOT NULL DEFAULT 0,
      size_bytes        INTEGER NOT NULL DEFAULT 0,
      created_at        INTEGER NOT NULL,
      display_name      TEXT NOT NULL,
      share_status      TEXT NOT NULL DEFAULT 'idle',
      shared_message_id TEXT
    )
  ''';

  static const _recordingsIndexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_recordings_created_at  ON recordings(created_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_recordings_call_room   ON recordings(call_room_id)',
    'CREATE INDEX IF NOT EXISTS idx_recordings_share_status ON recordings(share_status)',
  ];

  // 020-native-voip-callkit: in-app call history (FR-VoIP-04/05, data-model.md)
  static const _callHistorySchema = '''
    CREATE TABLE IF NOT EXISTS call_history (
      id                TEXT PRIMARY KEY,
      contact_user_id   TEXT NOT NULL,
      contact_name      TEXT NOT NULL,
      avatar_url        TEXT,
      avatar_color_seed INTEGER NOT NULL DEFAULT 0,
      direction         TEXT NOT NULL,
      outcome           TEXT NOT NULL,
      call_type         TEXT NOT NULL,
      is_group          INTEGER NOT NULL DEFAULT 0,
      started_at        INTEGER NOT NULL,
      duration_seconds  INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _callHistoryIndexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_call_history_started_at ON call_history(started_at DESC)',
  ];

  // ── DB lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> initDB() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ciro_chat.db_v1');

    _db = await openDatabase(
      path,
      version:
          19, // v19: add call_history table (020-native-voip-callkit)
      onCreate: (db, version) async {
        await db.execute(_messagesSchema);
        await db.execute(_roomsSchema);
        await db.execute(_contactsSchema);
        await db.execute(_statusesSchema);
        await db.execute(_recordingsSchema);
        await db.execute(_callHistorySchema);
        for (final stmt in _indexStatements) {
          await db.execute(stmt);
        }
        for (final stmt in _recordingsIndexStatements) {
          await db.execute(stmt);
        }
        for (final stmt in _callHistoryIndexStatements) {
          await db.execute(stmt);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 8) {
          try {
            await db.execute(
              "ALTER TABLE rooms ADD COLUMN type TEXT DEFAULT 'PRIVATE'",
            );
            await db.execute(
              "ALTER TABLE rooms ADD COLUMN participants TEXT DEFAULT '[]'",
            );
            await db.execute(
              "ALTER TABLE rooms ADD COLUMN admins TEXT DEFAULT '[]'",
            );
          } catch (e) {
            debugPrint('Migration v8 error: $e');
          }
        }
        // FR-020: Add last_message_id and last_message_sender_id columns.
        if (oldVersion < 9) {
          try {
            await db.execute(
              "ALTER TABLE rooms ADD COLUMN last_message_id TEXT DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE rooms ADD COLUMN last_message_sender_id TEXT DEFAULT ''",
            );
          } catch (e) {
            debugPrint('Migration v9 error: $e');
          }
        }
        if (oldVersion < 10) {
          try {
            await db.execute(
              "ALTER TABLE rooms ADD COLUMN lastMessageId TEXT DEFAULT ''",
            );
          } catch (e) {
            debugPrint('Migration v10 error: $e');
          }
        }
        if (oldVersion < 11) {
          try {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN is_deleted INTEGER DEFAULT 0',
            );
          } catch (e) {
            debugPrint('Migration v11 error: $e');
          }
        }
        // T004 — BN-01: add secondary indexes to existing installs
        if (oldVersion < 12) {
          for (final stmt in _indexStatements) {
            try {
              await db.execute(stmt);
            } catch (e) {
              debugPrint('Migration v12 index error: $e');
            }
          }
        }
        if (oldVersion < 13) {
          try {
            await db.execute(_recordingsSchema);
            for (final stmt in _recordingsIndexStatements) {
              await db.execute(stmt);
            }
          } catch (e) {
            debugPrint('Migration v13 error: $e');
          }
        }
        if (oldVersion < 14) {
          try {
            await db.execute(
              "ALTER TABLE messages ADD COLUMN sender_phone TEXT DEFAULT ''",
            );
          } catch (e) {
            debugPrint('Migration v14 error: $e');
          }
        }
        if (oldVersion < 15) {
          try {
            await db.execute(
              "ALTER TABLE messages ADD COLUMN sender_name TEXT DEFAULT ''",
            );
          } catch (e) {
            debugPrint('Migration v15 error: $e');
          }
        }
        // v16: add share-pipeline columns to recordings (FR-035, data-model.md §3)
        if (oldVersion < 16) {
          try {
            await db.execute(
              "ALTER TABLE recordings ADD COLUMN gallery_path TEXT",
            );
            await db.execute(
              "ALTER TABLE recordings ADD COLUMN share_status TEXT NOT NULL DEFAULT 'idle'",
            );
            await db.execute(
              "ALTER TABLE recordings ADD COLUMN shared_message_id TEXT",
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_recordings_share_status ON recordings(share_status)',
            );
          } catch (e) {
            debugPrint('Migration v16 error: $e');
          }
        }
        // v17: status sync metadata (FR-002/FR-016/FR-017, data-model.md §4)
        if (oldVersion < 17) {
          try {
            await db.execute(
              "ALTER TABLE statuses ADD COLUMN client_status_id TEXT DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE statuses ADD COLUMN sync_status TEXT DEFAULT 'synced'",
            );
            await db.execute(
              "ALTER TABLE statuses ADD COLUMN audience_json TEXT DEFAULT '[]'",
            );
            await db.execute(
              "ALTER TABLE statuses ADD COLUMN author_id TEXT DEFAULT ''",
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_statuses_client_id ON statuses(client_status_id)',
            );
          } catch (e) {
            debugPrint('Migration v17 error: $e');
          }
        }
        // v18: backfill statuses content columns missing on installs that
        // upgraded through a build where this migration was dropped.
        if (oldVersion < 18) {
          for (final stmt in [
            "ALTER TABLE statuses ADD COLUMN content_type TEXT DEFAULT 'image'",
            'ALTER TABLE statuses ADD COLUMN text_content TEXT',
            'ALTER TABLE statuses ADD COLUMN media_url TEXT',
            'ALTER TABLE statuses ADD COLUMN background_color TEXT',
            'ALTER TABLE statuses ADD COLUMN font_style TEXT',
            'ALTER TABLE statuses ADD COLUMN music_track_id TEXT',
          ]) {
            try {
              await db.execute(stmt);
            } catch (e) {
              debugPrint('Migration v18 error: $e');
            }
          }
        }
        // v19: in-app call history table (020-native-voip-callkit)
        if (oldVersion < 19) {
          try {
            await db.execute(_callHistorySchema);
            for (final stmt in _callHistoryIndexStatements) {
              await db.execute(stmt);
            }
          } catch (e) {
            debugPrint('Migration v19 error: $e');
          }
        }
      },
    );
  }

  // ── saveMessage ─────────────────────────────────────────────────────────────

  @override
  Future<void> saveMessage(
    Message message, {
    bool incrementUnread = false,
    String roomName = '',
    String roomAvatarUrl = '',
    String roomPhoneNumber = '',
  }) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    // FR-019: Idempotent insert — skip if clientMessageId already exists.
    if (message.clientMessageId.isNotEmpty) {
      final existing = await db.query(
        'messages',
        columns: ['id'],
        where: 'client_message_id = ?',
        whereArgs: [message.clientMessageId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        debugPrint(
          '[LocalData] Dedup: message with clientMessageId=${message.clientMessageId} already exists, skipping insert.',
        );
        return;
      }
    }

    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Determine a human-readable last-message preview for the inbox.
    final lastMsgPreview = message.type == MessageType.text
        ? message.text
        : _mediaPreview(message.type);

    // GHOST CHAT FIX: UPSERT the room row so JIT rooms appear immediately.
    // FR-020: Also track lastMessageId for scoped status.
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO rooms
        (id, name, avatarUrl, phoneNumber, lastMessage, timestamp, unreadCount, isOnline, lastMessageSenderId, lastMessageStatus, type, participants, admins, lastMessageId)
      VALUES (
        ?,
        COALESCE((SELECT name          FROM rooms WHERE id = ?), ?),
        COALESCE((SELECT avatarUrl     FROM rooms WHERE id = ?), ?),
        COALESCE((SELECT phoneNumber   FROM rooms WHERE id = ?), ?),
        ?,
        ?,
        COALESCE((SELECT unreadCount   FROM rooms WHERE id = ?), 0) + ?,
        COALESCE((SELECT isOnline      FROM rooms WHERE id = ?), 0),
        ?,
        ?,
        COALESCE((SELECT type          FROM rooms WHERE id = ?), 'PRIVATE'),
        COALESCE((SELECT participants  FROM rooms WHERE id = ?), '[]'),
        COALESCE((SELECT admins        FROM rooms WHERE id = ?), '[]'),
        ?
      )
      ''',
      [
        message.roomId, // id
        message.roomId, roomName, // name
        message.roomId, roomAvatarUrl, // avatarUrl
        message.roomId, roomPhoneNumber, // phoneNumber
        lastMsgPreview, // lastMessage
        message.timestamp.toIso8601String(), // timestamp
        message.roomId, incrementUnread ? 1 : 0, // unreadCount
        message.roomId, // isOnline
        message.senderId, // lastMessageSenderId
        message.status.name, // lastMessageStatus
        message.roomId, // type
        message.roomId, // participants
        message.roomId, // admins
        message.id, // lastMessageId (FR-020)
      ],
    );

    await _dispatchUpdateForRoom(message.roomId);
    await _dispatchRecentChatsUpdate();
  }

  // ── updateMessageMedia ──────────────────────────────────────────────────────

  @override
  Future<void> updateMessageMedia(
    String messageId,
    String fileUrl,
    Map<String, dynamic> metadata,
  ) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    final records = await db.query(
      'messages',
      columns: ['room_id'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    await db.update(
      'messages',
      {'file_url': fileUrl, 'metadata': jsonEncode(metadata)},
      where: 'id = ?',
      whereArgs: [messageId],
    );

    if (records.isNotEmpty) {
      final roomId = records.first['room_id'] as String;
      await _dispatchUpdateForRoom(roomId);
      await _dispatchRecentChatsUpdate();
    }
  }

  // ── Waveform Cache ──────────────────────────────────────────────────────────

  @override
  Future<List<double>?> getWaveformCache(String messageId) async {
    final msg = await getMessageById(messageId);
    if (msg == null) return null;

    final meta = msg.metadata;
    if (meta != null && meta.containsKey('waveformSamples')) {
      final rawList = meta['waveformSamples'];
      if (rawList is List) {
        return rawList.map((e) => (e as num).toDouble()).toList();
      }
    }
    return null;
  }

  @override
  Future<void> saveWaveformCache(String messageId, List<double> samples) async {
    final db = _db;
    if (db == null) return;

    final msg = await getMessageById(messageId);
    if (msg == null) return;

    final updatedMeta = Map<String, dynamic>.from(msg.metadata ?? {});
    updatedMeta['waveformSamples'] = samples;

    await db.update(
      'messages',
      {'metadata': jsonEncode(updatedMeta)},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ── deleteMessage ───────────────────────────────────────────────────────────

  @override
  Future<void> deleteMessage(String messageId) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    final maps = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final message = Message.fromMap(maps.first);
      final meta = message.metadata ?? {};
      final localPath = meta['localPath'] as String?;

      if (localPath != null) {
        final file = File(localPath);
        if (file.existsSync()) {
          try {
            file.deleteSync();
            debugPrint('[LocalData] Deleted cached media file: $localPath');
          } catch (e) {
            debugPrint('[LocalData] Failed to delete media file: $e');
          }
        }
      }

      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);

      await _dispatchUpdateForRoom(message.roomId);
      await _dispatchRecentChatsUpdate();
    }
  }

  // ── updateMessageStatus ─────────────────────────────────────────────────────

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status, {
    DateTime? createdAt,
  }) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    // FR-019: Query by client_message_id for reliable lookup across
    // socket reconnects where the MongoDB _id may not yet be known.
    final records = await db.query(
      'messages',
      columns: ['id', 'room_id', 'status'],
      where: 'client_message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    // Fallback: try by primary id if client_message_id lookup fails.
    final List<Map<String, dynamic>> effectiveRecords;
    if (records.isEmpty) {
      effectiveRecords = await db.query(
        'messages',
        columns: ['id', 'room_id', 'status'],
        where: 'id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
    } else {
      effectiveRecords = records;
    }

    if (effectiveRecords.isEmpty) return;

    final row = effectiveRecords.first;
    final dbId = row['id'] as String;
    final roomId = row['room_id'] as String;
    final currentStatusStr = row['status'] as String?;

    // FR-019: Monotonic status guard — never allow backward status changes.
    if (currentStatusStr != null) {
      final currentStatus = MessageStatus.values.firstWhere(
        (e) => e.name == currentStatusStr,
        orElse: () => MessageStatus.pending,
      );
      if (_statusRank(status) <= _statusRank(currentStatus)) {
        debugPrint(
          '[LocalData] Status guard: rejecting ${status.name} (rank ${_statusRank(status)}) '
          '— current is ${currentStatus.name} (rank ${_statusRank(currentStatus)})',
        );
        return;
      }
    }

    final updateData = <String, dynamic>{'status': status.name};
    if (createdAt != null) {
      updateData['timestamp'] = createdAt.millisecondsSinceEpoch;
    }

    await db.update('messages', updateData, where: 'id = ?', whereArgs: [dbId]);

    // FR-020: Only update room status if this message is the room's latest.
    final roomRows = await db.query(
      'rooms',
      columns: ['lastMessageId'],
      where: 'id = ?',
      whereArgs: [roomId],
      limit: 1,
    );

    final roomLastMsgId = roomRows.isNotEmpty
        ? (roomRows.first['lastMessageId'] as String? ?? '')
        : '';

    // Only update room status if this IS the latest message (or no tracking yet).
    if (roomLastMsgId.isEmpty ||
        roomLastMsgId == dbId ||
        roomLastMsgId == messageId) {
      final roomUpdateData = <String, dynamic>{
        'lastMessageStatus': status.name,
      };
      if (createdAt != null) {
        roomUpdateData['timestamp'] = createdAt.toIso8601String();
      }

      await db.update(
        'rooms',
        roomUpdateData,
        where: 'id = ?',
        whereArgs: [roomId],
      );
    }

    await _dispatchUpdateForRoom(roomId);
    await _dispatchRecentChatsUpdate();
  }

  // ── getRoomMessages ─────────────────────────────────────────────────────────

  @override
  Future<List<Message>> getRoomMessages(
    String roomId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final db = _db;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((e) => Message.fromMap(e)).toList().reversed.toList();
  }

  // ── watchRoomMessages ───────────────────────────────────────────────────────

  @override
  Stream<List<Message>> watchRoomMessages(String roomId, {int limit = 30}) {
    if (!_roomStreamControllers.containsKey(roomId)) {
      _roomStreamControllers[roomId] =
          StreamController<List<Message>>.broadcast();
    }
    getRoomMessages(
      roomId,
      limit: limit,
    ).then((msgs) => _roomStreamControllers[roomId]!.add(msgs));
    return _roomStreamControllers[roomId]!.stream;
  }

  // T006 — BN-03: called by ChatCubit after loadMoreMessages to record the
  // expanded window so _dispatchUpdateForRoom never shrinks it back to 30.
  @override
  void setRoomDisplayLimit(String roomId, int limit) {
    _roomDisplayLimits[roomId] = limit;
  }

  // T007 — BN-03: use stored HWM so a new incoming message or status update
  // doesn't reset a paginated list back to the default 30-item window.
  Future<void> _dispatchUpdateForRoom(String roomId) async {
    if (_roomStreamControllers.containsKey(roomId)) {
      final limit = _roomDisplayLimits[roomId] ?? 30;
      final messages = await getRoomMessages(roomId, limit: limit);
      _roomStreamControllers[roomId]!.add(messages);
    }
  }

  // ── getPendingMessages ──────────────────────────────────────────────────────

  @override
  Future<List<Message>> getPendingMessages() async {
    final db = _db;
    if (db == null) return [];
    final maps = await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: [MessageStatus.pending.name],
      orderBy: 'timestamp ASC',
    );
    return maps.map((e) => Message.fromMap(e)).toList();
  }

  // ── getStuckMessages ────────────────────────────────────────────────────────

  @override
  Future<List<Message>> getStuckMessages() async {
    final db = _db;
    if (db == null) return [];
    final maps = await db.query(
      'messages',
      where: 'status IN (?, ?)',
      whereArgs: [MessageStatus.pending.name, MessageStatus.sent.name],
      orderBy: 'timestamp ASC',
    );
    return maps.map((e) => Message.fromMap(e)).toList();
  }

  // ── getLastMessageTimestamp ─────────────────────────────────────────────────

  @override
  Future<DateTime?> getLastMessageTimestamp(String roomId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.rawQuery(
      'SELECT MAX(timestamp) AS ts FROM messages WHERE room_id = ?',
      [roomId],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['ts'];
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw as int, isUtc: true);
  }

  // ── getRoomById ─────────────────────────────────────────────────────────────

  @override
  Future<ChatSession?> getRoomById(String roomId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'rooms',
      where: 'id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChatSession.fromMap(rows.first);
  }

  // ── getMessageStatus ────────────────────────────────────────────────────────

  @override
  Future<MessageStatus?> getMessageStatus(String messageId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'messages',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['status'] as String?;
    if (raw == null) return null;
    return MessageStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => MessageStatus.pending,
    );
  }

  // ── getMessageById ──────────────────────────────────────────────────────────

  @override
  Future<Message?> getMessageById(String messageId) async {
    final db = _db;
    if (db == null) return null;
    final maps = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Message.fromMap(maps.first);
    }
    return null;
  }

  // ── saveRoom ────────────────────────────────────────────────────────────────

  @override
  Future<void> saveRoom(ChatSession room) async {
    final db = _db;
    if (db == null) return;

    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO rooms (id, name, lastMessage, lastMessageId, timestamp, unreadCount, isOnline, avatarUrl, phoneNumber, lastMessageSenderId, lastMessageStatus, type, participants, admins)
      VALUES (?, ?, ?, ?, ?, COALESCE((SELECT unreadCount FROM rooms WHERE id = ?), 0), ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        room.id,
        room.name,
        room.lastMessage,
        room.lastMessageId,
        room.timestamp.toIso8601String(),
        room.id,
        room.isOnline ? 1 : 0,
        room.avatarUrl,
        room.phoneNumber,
        room.lastMessageSenderId,
        room.lastMessageStatus.name,
        room.type.name,
        jsonEncode(room.participants),
        jsonEncode(room.admins),
      ],
    );

    await _dispatchRecentChatsUpdate();
  }

  // ── watchRecentChats ────────────────────────────────────────────────────────

  @override
  Stream<List<ChatSession>> watchRecentChats() {
    _dispatchRecentChatsUpdate();
    return _recentChatsController.stream;
  }

  Future<void> _dispatchRecentChatsUpdate() async {
    final db = _db;
    if (db == null) return;

    final maps = await db.rawQuery('''
      SELECT
        r.id,
        COALESCE(NULLIF(c.name, ''), NULLIF(r.name, ''), r.phoneNumber) AS name,
        r.lastMessage,
        r.lastMessageId,
        r.timestamp,
        r.unreadCount,
        r.isOnline,
        COALESCE(NULLIF(c.avatarUrl, ''), NULLIF(r.avatarUrl, '')) AS avatarUrl,
        r.phoneNumber,
        r.lastMessageSenderId,
        r.lastMessageStatus,
        r.lastMessageId,
        r.type,
        r.participants,
        r.admins
      FROM rooms r
      LEFT JOIN contacts c ON c.phoneNumber = r.phoneNumber
      ORDER BY r.timestamp DESC
      LIMIT 20
    ''');

    final rooms = maps
        .map(
          (e) => ChatSession(
            id: e['id'] as String,
            name: (e['name'] as String?) ?? '',
            lastMessage: (e['lastMessage'] as String?) ?? '',
            timestamp:
                DateTime.tryParse(e['timestamp'] as String? ?? '') ??
                DateTime.now(),
            unreadCount: (e['unreadCount'] as int?) ?? 0,
            isOnline: ((e['isOnline'] as int?) ?? 0) == 1,
            avatarUrl: (e['avatarUrl'] as String?) ?? '',
            phoneNumber: (e['phoneNumber'] as String?) ?? '',
            lastMessageSenderId: (e['lastMessageSenderId'] as String?) ?? '',
            lastMessageStatus: MessageStatus.values.firstWhere(
              (st) => st.name == e['lastMessageStatus'],
              orElse: () => MessageStatus.pending,
            ),
            lastMessageId: (e['lastMessageId'] as String?) ?? '',
            type: ChatRoomType.values.firstWhere(
              (t) => t.name == (e['type'] as String? ?? 'PRIVATE'),
              orElse: () => ChatRoomType.PRIVATE,
            ),
            participants: e['participants'] != null
                ? (jsonDecode(e['participants'] as String) as List<dynamic>)
                      .map((p) => p as String)
                      .toList()
                : [],
            admins: e['admins'] != null
                ? (jsonDecode(e['admins'] as String) as List<dynamic>)
                      .map((a) => a as String)
                      .toList()
                : [],
          ),
        )
        .toList();

    if (!_recentChatsController.isClosed) {
      _recentChatsController.add(rooms);
    }
  }

  // ── watchContacts ───────────────────────────────────────────────────────────

  @override
  Stream<List<ChatSession>> watchContacts() async* {
    final db = _db;
    if (db != null) {
      final maps = await db.query(
        'contacts',
        orderBy: 'name COLLATE NOCASE ASC',
      );
      debugPrint(
        'contacts: ${maps.map((e) => ChatSession.fromMap(e)).toList()}',
      );
      yield maps.map((e) => ChatSession.fromMap(e)).toList();
    } else {
      yield <ChatSession>[];
    }
    yield* _contactsController.stream;
  }

  // ── upsertContacts ──────────────────────────────────────────────────────────

  @override
  Future<void> upsertContacts(List<ChatSession> contacts) async {
    final db = _db;
    if (db == null || contacts.isEmpty) return;

    final batch = db.batch();
    for (final contact in contacts) {
      batch.insert('contacts', {
        'id': contact.id,
        'name': contact.name,
        'phoneNumber': contact.phoneNumber,
        'avatarUrl': contact.avatarUrl,
        'isOnline': contact.isOnline ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    final maps = await db.query('contacts', orderBy: 'name COLLATE NOCASE ASC');
    if (!_contactsController.isClosed) {
      _contactsController.add(maps.map((e) => ChatSession.fromMap(e)).toList());
    }
    await _dispatchRecentChatsUpdate();
  }

  // ── resetUnreadCount ────────────────────────────────────────────────────────

  @override
  Future<void> resetUnreadCount(String roomId) async {
    final db = _db;
    if (db == null) return;

    await db.update(
      'rooms',
      {'unreadCount': 0},
      where: 'id = ?',
      whereArgs: [roomId],
    );
    await _dispatchRecentChatsUpdate();
  }

  // ── deleteRoom ─────────────────────────────────────────────────────────────

  @override
  Future<void> deleteRoom(String roomId) async {
    final db = _db;
    if (db == null) return;

    await db.delete('rooms', where: 'id = ?', whereArgs: [roomId]);
    await db.delete('messages', where: 'room_id = ?', whereArgs: [roomId]);

    await _dispatchRecentChatsUpdate();
    closeRoomStream(roomId);
  }

  // ── closeRoomStream ─────────────────────────────────────────────────────────

  @override
  void closeRoomStream(String roomId) {
    if (_roomStreamControllers.containsKey(roomId)) {
      _roomStreamControllers[roomId]?.close();
      _roomStreamControllers.remove(roomId);
    }
    _roomDisplayLimits.remove(roomId); // T008 — BN-03: clear HWM on room close
  }

  // ── clearAllData ────────────────────────────────────────────────────────────

  @override
  Future<void> clearAllData() async {
    final db = _db;
    if (db == null) return;

    await db.delete('messages');
    await db.delete('rooms');
    await db.delete('contacts');
    await db.delete('statuses');

    for (final controller in _roomStreamControllers.values) {
      if (!controller.isClosed) {
        controller.add([]);
        await controller.close();
      }
    }
    _roomStreamControllers.clear();

    if (!_recentChatsController.isClosed) _recentChatsController.add([]);
    if (!_contactsController.isClosed) _contactsController.add([]);
  }

  // ── Search & Media ────────────────────────────────────────────────────────

  @override
  Future<List<Message>> searchMessages(String roomId, String query) async {
    final db = _db;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'room_id = ? AND text LIKE ?',
      whereArgs: [roomId, '%$query%'],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  @override
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    final db = _db;
    if (db == null) return;
    // For private rooms, the 'id' is often the user's ID or phone.
    // We update any room where this user is the "other" participant.
    final contact = await db.query(
      'contacts',
      columns: ['phoneNumber'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (contact.isNotEmpty) {
      final phone = contact.first['phoneNumber'] as String;
      await db.update(
        'rooms',
        {'isOnline': isOnline ? 1 : 0},
        where: 'phoneNumber = ?',
        whereArgs: [phone],
      );
    }
    await _dispatchRecentChatsUpdate();
  }

  @override
  Future<List<Message>> getSharedMedia(String roomId) async {
    final db = _db;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'room_id = ? AND type IN (?, ?, ?)',
      whereArgs: [
        roomId,
        MessageType.image.name,
        MessageType.video.name,
        MessageType.file.name,
      ],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  // ── FR-022: Soft delete ──────────────────────────────────────────────────

  @override
  Future<void> markMessageDeleted(String clientMessageId) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'messages',
      {'is_deleted': 1, 'text': ''},
      where: 'client_message_id = ?',
      whereArgs: [clientMessageId],
    );
    // Refresh stream for the affected room
    final rows = await db.query(
      'messages',
      columns: ['room_id'],
      where: 'client_message_id = ?',
      whereArgs: [clientMessageId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final roomId = rows.first['room_id'] as String;
      await _dispatchUpdateForRoom(roomId);
    }
  }

  // ── FR-024: Shared links, docs & counts ─────────────────────────────────

  @override
  Future<List<Message>> getSharedLinks(String roomId) async {
    final db = _db;
    if (db == null) return [];
    // Match messages whose text contains a URL
    final maps = await db.query(
      'messages',
      where: "room_id = ? AND text LIKE '%http%' AND is_deleted = 0",
      whereArgs: [roomId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  @override
  Future<List<Message>> getSharedDocs(String roomId) async {
    final db = _db;
    if (db == null) return [];
    final maps = await db.query(
      'messages',
      where: 'room_id = ? AND type = ? AND is_deleted = 0',
      whereArgs: [roomId, MessageType.file.name],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  @override
  Future<Map<String, int>> getMediaCount(String roomId) async {
    final db = _db;
    if (db == null) return {'photos': 0, 'videos': 0};
    final photoCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM messages WHERE room_id = ? AND type = ? AND is_deleted = 0",
            [roomId, MessageType.image.name],
          ),
        ) ??
        0;
    final videoCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM messages WHERE room_id = ? AND type = ? AND is_deleted = 0",
            [roomId, MessageType.video.name],
          ),
        ) ??
        0;
    return {'photos': photoCount, 'videos': videoCount};
  }
}
