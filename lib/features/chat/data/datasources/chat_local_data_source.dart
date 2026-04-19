import 'dart:async';
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
  Future<List<Message>> getRoomMessages(String roomId);
  Stream<List<Message>> watchRoomMessages(String roomId);
  Future<void> saveRoom(ChatSession room);
  Stream<List<ChatSession>> watchRecentChats();
  Stream<List<ChatSession>> watchContacts();
  Future<void> upsertContacts(List<ChatSession> contacts);
  Future<void> resetUnreadCount(String roomId);
  void closeRoomStream(String roomId);
  Future<void> clearAllData();
}

@LazySingleton(as: ChatLocalDataSource)
class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  Database? _db;

  // Local stream controllers for reactive UI updates per room
  final Map<String, StreamController<List<Message>>> _roomStreamControllers =
      {};
  final StreamController<List<ChatSession>> _recentChatsController =
      StreamController<List<ChatSession>>.broadcast();
  final StreamController<List<ChatSession>> _contactsController =
      StreamController<List<ChatSession>>.broadcast();

  @override
  Future<void> initDB() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ciro_chat.db');

    _db = await openDatabase(
      path,
      version: 4, // Bumped: mapped contacts table directly
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            room_id TEXT,
            sender_id TEXT,
            text TEXT,
            timestamp INTEGER,
            status TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE rooms(
            id TEXT PRIMARY KEY,
            name TEXT,
            lastMessage TEXT,
            timestamp TEXT,
            unreadCount INTEGER,
            isOnline INTEGER,
            avatarUrl TEXT,
            phoneNumber TEXT DEFAULT '',
            lastMessageSenderId TEXT DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts(
            id TEXT PRIMARY KEY,
            name TEXT,
            phoneNumber TEXT,
            avatarUrl TEXT,
            isOnline INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Strict development mode constraint — Drop completely mapping to clear migrations natively
        await db.execute('DROP TABLE IF EXISTS rooms');
        await db.execute('DROP TABLE IF EXISTS messages');
        await db.execute('DROP TABLE IF EXISTS contacts');

        // Re-execute onCreate directly bridging logic
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            room_id TEXT,
            sender_id TEXT,
            text TEXT,
            timestamp INTEGER,
            status TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE rooms(
            id TEXT PRIMARY KEY,
            name TEXT,
            lastMessage TEXT,
            timestamp TEXT,
            unreadCount INTEGER,
            isOnline INTEGER,
            avatarUrl TEXT,
            phoneNumber TEXT DEFAULT '',
            lastMessageSenderId TEXT DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts(
            id TEXT PRIMARY KEY,
            name TEXT,
            phoneNumber TEXT,
            avatarUrl TEXT,
            isOnline INTEGER
          )
        ''');
      },
    );
  }

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

    await db.transaction((txn) async {
      // 1. Insert the message row — replace on id conflict (idempotent retry-safe).
      await txn.insert(
        'messages',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Bulletproof room UPSERT inside the same transaction.
      //    ON CONFLICT(id) DO UPDATE ensures we never lose an existing row AND
      //    CASE WHEN guards prevent empty strings from wiping stored name/avatar.
      await txn.rawInsert(
        '''
        INSERT INTO rooms
          (id, name, avatarUrl, phoneNumber, lastMessage, timestamp, unreadCount, isOnline, lastMessageSenderId)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
        ON CONFLICT(id) DO UPDATE SET
          name             = CASE WHEN excluded.name     != '' THEN excluded.name     ELSE rooms.name     END,
          avatarUrl        = CASE WHEN excluded.avatarUrl != '' THEN excluded.avatarUrl ELSE rooms.avatarUrl END,
          phoneNumber      = CASE WHEN excluded.phoneNumber != '' THEN excluded.phoneNumber ELSE rooms.phoneNumber END,
          lastMessage      = excluded.lastMessage,
          timestamp        = excluded.timestamp,
          unreadCount      = rooms.unreadCount + ${incrementUnread ? 1 : 0},
          lastMessageSenderId = excluded.lastMessageSenderId
        ''',
        [
          message.roomId,
          roomName,
          roomAvatarUrl,
          roomPhoneNumber,
          message.text,
          message.timestamp.toIso8601String(),
          0,               // unreadCount seed for brand-new rows
          message.senderId,
        ],
      );
    });

    // Push reactive updates outside the transaction so subscribers see a
    // fully committed state, never a partial write.
    await _dispatchUpdateForRoom(message.roomId);
    await _dispatchRecentChatsUpdate();
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    // We need to find the room id to notify the stream.
    // Faster query:
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
      await _dispatchUpdateForRoom(roomId);
    }
  }

  @override
  Future<List<Message>> getRoomMessages(String roomId) async {
    final db = _db;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp DESC', // Read newest messages
      limit: 20, // Strict buffer constraint
    );

    // Reverse memory stack so chronological flow is restored for ListView bottom-gravity
    return maps.map((e) => Message.fromMap(e)).toList().reversed.toList();
  }

  @override
  Stream<List<Message>> watchRoomMessages(String roomId) {
    if (!_roomStreamControllers.containsKey(roomId)) {
      _roomStreamControllers[roomId] =
          StreamController<List<Message>>.broadcast();
    }
    // Seed initial data
    getRoomMessages(
      roomId,
    ).then((msgs) => _roomStreamControllers[roomId]!.add(msgs));

    return _roomStreamControllers[roomId]!.stream;
  }

  Future<void> _dispatchUpdateForRoom(String roomId) async {
    if (_roomStreamControllers.containsKey(roomId)) {
      final messages = await getRoomMessages(roomId);
      _roomStreamControllers[roomId]!.add(messages);
    }
  }

  @override
  Future<void> saveRoom(ChatSession room) async {
    final db = _db;
    if (db == null) return;

    // Natively protect unreadCount preventing API calls from erasing unread badges
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO rooms (id, name, lastMessage, timestamp, unreadCount, isOnline, avatarUrl, phoneNumber, lastMessageSenderId)
      VALUES (?, ?, ?, ?, COALESCE((SELECT unreadCount FROM rooms WHERE id = ?), 0), ?, ?, ?, ?)
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
      ],
    );

    await _dispatchRecentChatsUpdate();
  }

  @override
  Stream<List<ChatSession>> watchRecentChats() {
    _dispatchRecentChatsUpdate();
    return _recentChatsController.stream;
  }

  Future<void> _dispatchRecentChatsUpdate() async {
    final db = _db;
    if (db == null) return;
    final maps = await db.query('rooms', orderBy: 'timestamp DESC', limit: 20);
    final rooms = maps.map((e) => ChatSession.fromMap(e)).toList();
    if (!_recentChatsController.isClosed) {
      _recentChatsController.add(rooms);
    }
  }

  @override
  Stream<List<ChatSession>> watchContacts() async* {
    final db = _db;
    if (db != null) {
      // Yield strictly synchronously blocking logic cleanly before joining streams natively!
      final maps = await db.query('contacts', orderBy: 'name COLLATE NOCASE ASC');
      yield maps.map((e) => ChatSession.fromMap(e)).toList();
    } else {
      yield <ChatSession>[];
    }
    yield* _contactsController.stream;
  }

  @override
  Future<void> upsertContacts(List<ChatSession> contacts) async {
    final db = _db;
    if (db == null || contacts.isEmpty) return;

    Batch batch = db.batch();
    for (var contact in contacts) {
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

    // Refresh memory cache instantly avoiding lag arrays
    final maps = await db.query('contacts', orderBy: 'name COLLATE NOCASE ASC');
    if (!_contactsController.isClosed) {
      _contactsController.add(maps.map((e) => ChatSession.fromMap(e)).toList());
    }
  }

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

  @override
  void closeRoomStream(String roomId) {
    if (_roomStreamControllers.containsKey(roomId)) {
      _roomStreamControllers[roomId]?.close();
      _roomStreamControllers.remove(roomId);
    }
  }

  @override
  Future<void> clearAllData() async {
    final db = _db;
    if (db == null) return;

    // 1. Physically nuke the tables
    await db.delete('messages');
    await db.delete('rooms');
    await db.delete('contacts');

    // 2. Tear down reactive stream infra
    for (final controller in _roomStreamControllers.values) {
      if (!controller.isClosed) {
        controller.add([]); // Push clean state
        await controller.close(); // Sever listener
      }
    }
    _roomStreamControllers.clear();

    // 3. Flush the global inbox state
    if (!_recentChatsController.isClosed) {
      _recentChatsController.add([]);
    }
    if (!_contactsController.isClosed) {
      _contactsController.add([]);
    }
  }
}
