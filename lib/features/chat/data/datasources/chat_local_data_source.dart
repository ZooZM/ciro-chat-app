import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:injectable/injectable.dart';

abstract class ChatLocalDataSource {
  Future<void> initDB();
  Future<void> saveMessage(
    Message message, {
    bool incrementUnread = false,
    String roomName = '',
    String roomAvatarUrl = '',
    String roomPhoneNumber = '',
  });
  Future<void> updateMessageStatus(String messageId, MessageStatus status);

  /// Updates the [fileUrl] and [metadata] of an already-saved message.
  /// Called after a successful upload to replace the optimistic placeholder.
  Future<void> updateMessageMedia(
    String messageId,
    String fileUrl,
    Map<String, dynamic> metadata,
  );

  Future<List<Message>> getRoomMessages(String roomId);
  Stream<List<Message>> watchRoomMessages(String roomId);
  Future<void> saveRoom(ChatSession room);
  Stream<List<ChatSession>> watchRecentChats();
  Stream<List<ChatSession>> watchContacts();
  Future<void> upsertContacts(List<ChatSession> contacts);
  Future<void> resetUnreadCount(String roomId);
  void closeRoomStream(String roomId);
  Future<void> clearAllData();

  /// Returns all messages with [MessageStatus.pending], oldest-first.
  Future<List<Message>> getPendingMessages();

  /// Returns all messages stuck in [pending] OR [sent] state, oldest-first.
  Future<List<Message>> getStuckMessages();

  /// Returns the current [MessageStatus] of a single message by its ID.
  Future<MessageStatus?> getMessageStatus(String messageId);
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
    case MessageType.contact:
      return '👤 Contact';
    case MessageType.text:
      return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

@LazySingleton(as: ChatLocalDataSource)
class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  Database? _db;

  final Map<String, StreamController<List<Message>>> _roomStreamControllers =
      {};
  final StreamController<List<ChatSession>> _recentChatsController =
      StreamController<List<ChatSession>>.broadcast();
  final StreamController<List<ChatSession>> _contactsController =
      StreamController<List<ChatSession>>.broadcast();

  // ── Schema helpers ──────────────────────────────────────────────────────────

  static const _messagesSchema = '''
    CREATE TABLE messages(
      id                TEXT PRIMARY KEY,
      client_message_id TEXT,
      room_id           TEXT,
      sender_id         TEXT,
      text              TEXT,
      timestamp         INTEGER,
      status            TEXT,
      type              TEXT DEFAULT 'text',
      file_url          TEXT DEFAULT '',
      metadata          TEXT DEFAULT ''
    )
  ''';

  static const _roomsSchema = '''
    CREATE TABLE rooms(
      id                  TEXT PRIMARY KEY,
      name                TEXT,
      lastMessage         TEXT,
      timestamp           TEXT,
      unreadCount         INTEGER,
      isOnline            INTEGER,
      avatarUrl           TEXT,
      phoneNumber         TEXT DEFAULT '',
      lastMessageSenderId TEXT DEFAULT '',
      lastMessageStatus   TEXT DEFAULT 'pending'
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

  // ── DB lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> initDB() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ciro_chat.db_v1');

    _db = await openDatabase(
      path,
      // Version 7: adds type, file_url, metadata columns to messages table.
      version: 7,
      onCreate: (db, version) async {
        await db.execute(_messagesSchema);
        await db.execute(_roomsSchema);
        await db.execute(_contactsSchema);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Development-mode strategy: drop & recreate for a clean slate.
        await db.execute('DROP TABLE IF EXISTS rooms');
        await db.execute('DROP TABLE IF EXISTS messages');
        await db.execute('DROP TABLE IF EXISTS contacts');
        await db.execute(_messagesSchema);
        await db.execute(_roomsSchema);
        await db.execute(_contactsSchema);
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

    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Determine a human-readable last-message preview for the inbox.
    final lastMsgPreview = message.type == MessageType.text
        ? message.text
        : _mediaPreview(message.type);

    // GHOST CHAT FIX: UPSERT the room row so JIT rooms appear immediately.
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO rooms
        (id, name, avatarUrl, phoneNumber, lastMessage, timestamp, unreadCount, isOnline, lastMessageSenderId, lastMessageStatus)
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
      {
        'file_url': fileUrl,
        'metadata': jsonEncode(metadata),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );

    if (records.isNotEmpty) {
      final roomId = records.first['room_id'] as String;
      await _dispatchUpdateForRoom(roomId);
      await _dispatchRecentChatsUpdate();
    }
  }

  // ── updateMessageStatus ─────────────────────────────────────────────────────

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    final records = await db.query(
      'messages',
      columns: ['room_id'],
      where: 'id = ?',
      whereArgs: [messageId],
    );

    await db.update(
      'messages',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [messageId],
    );

    if (records.isNotEmpty) {
      final roomId = records.first['room_id'] as String;
      await db.update(
        'rooms',
        {'lastMessageStatus': status.name},
        where: 'id = ?',
        whereArgs: [roomId],
      );
      await _dispatchUpdateForRoom(roomId);
      await _dispatchRecentChatsUpdate();
    }
  }

  // ── getRoomMessages ─────────────────────────────────────────────────────────

  @override
  Future<List<Message>> getRoomMessages(String roomId) async {
    final db = _db;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp DESC',
      limit: 20,
    );

    return maps.map((e) => Message.fromMap(e)).toList().reversed.toList();
  }

  // ── watchRoomMessages ───────────────────────────────────────────────────────

  @override
  Stream<List<Message>> watchRoomMessages(String roomId) {
    if (!_roomStreamControllers.containsKey(roomId)) {
      _roomStreamControllers[roomId] =
          StreamController<List<Message>>.broadcast();
    }
    getRoomMessages(roomId).then(
      (msgs) => _roomStreamControllers[roomId]!.add(msgs),
    );
    return _roomStreamControllers[roomId]!.stream;
  }

  Future<void> _dispatchUpdateForRoom(String roomId) async {
    if (_roomStreamControllers.containsKey(roomId)) {
      final messages = await getRoomMessages(roomId);
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

  // ── saveRoom ────────────────────────────────────────────────────────────────

  @override
  Future<void> saveRoom(ChatSession room) async {
    final db = _db;
    if (db == null) return;

    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO rooms (id, name, lastMessage, timestamp, unreadCount, isOnline, avatarUrl, phoneNumber, lastMessageSenderId, lastMessageStatus)
      VALUES (?, ?, ?, ?, COALESCE((SELECT unreadCount FROM rooms WHERE id = ?), 0), ?, ?, ?, ?, ?)
    ''',
      [
        room.id,
        room.name,
        room.lastMessage,
        room.timestamp.toIso8601String(),
        room.id,
        room.isOnline ? 1 : 0,
        room.avatarUrl,
        room.phoneNumber,
        room.lastMessageSenderId,
        room.lastMessageStatus.name,
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
        r.timestamp,
        r.unreadCount,
        r.isOnline,
        COALESCE(NULLIF(c.avatarUrl, ''), NULLIF(r.avatarUrl, '')) AS avatarUrl,
        r.phoneNumber,
        r.lastMessageSenderId,
        r.lastMessageStatus
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
      batch.insert(
        'contacts',
        {
          'id': contact.id,
          'name': contact.name,
          'phoneNumber': contact.phoneNumber,
          'avatarUrl': contact.avatarUrl,
          'isOnline': contact.isOnline ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    final maps =
        await db.query('contacts', orderBy: 'name COLLATE NOCASE ASC');
    if (!_contactsController.isClosed) {
      _contactsController.add(
        maps.map((e) => ChatSession.fromMap(e)).toList(),
      );
    }
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

  // ── closeRoomStream ─────────────────────────────────────────────────────────

  @override
  void closeRoomStream(String roomId) {
    if (_roomStreamControllers.containsKey(roomId)) {
      _roomStreamControllers[roomId]?.close();
      _roomStreamControllers.remove(roomId);
    }
  }

  // ── clearAllData ────────────────────────────────────────────────────────────

  @override
  Future<void> clearAllData() async {
    final db = _db;
    if (db == null) return;

    await db.delete('messages');
    await db.delete('rooms');
    await db.delete('contacts');

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
}
