import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:injectable/injectable.dart';

abstract class ChatLocalDataSource {
  Future<void> initDB();
  Future<void> saveMessage(Message message);
  Future<void> updateMessageStatus(String messageId, MessageStatus status);
  Future<List<Message>> getRoomMessages(String roomId);
  Stream<List<Message>> watchRoomMessages(String roomId);
  Future<void> saveRoom(ChatSession room);
  Stream<List<ChatSession>> watchRecentChats();
}

@LazySingleton(as: ChatLocalDataSource)
class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  Database? _db;
  
  // Local stream controllers for reactive UI updates per room
  final Map<String, StreamController<List<Message>>> _roomStreamControllers = {};
  final StreamController<List<ChatSession>> _recentChatsController = StreamController<List<ChatSession>>.broadcast();

  @override
  Future<void> initDB() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ciro_chat.db');

    _db = await openDatabase(
      path,
      version: 2, // Bumped: added phoneNumber column to rooms
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
            phoneNumber TEXT DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add phoneNumber to existing installations
          await db.execute(
            "ALTER TABLE rooms ADD COLUMN phoneNumber TEXT DEFAULT ''",
          );
        }
      },
    );
  }

  @override
  Future<void> saveMessage(Message message) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');
    
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Notify reactive listeners
    await _dispatchUpdateForRoom(message.roomId);
  }

  @override
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');
    
    // We need to find the room id to notify the stream. 
    // Faster query:
    final records = await db.query('messages', columns: ['room_id'], where: 'id = ?', whereArgs: [messageId]);
    
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
      orderBy: 'timestamp ASC', // oldest first (List bottom is newest)
    );
    
    return maps.map((e) => Message.fromMap(e)).toList();
  }

  @override
  Stream<List<Message>> watchRoomMessages(String roomId) {
    if (!_roomStreamControllers.containsKey(roomId)) {
      _roomStreamControllers[roomId] = StreamController<List<Message>>.broadcast();
    }
    // Seed initial data
    getRoomMessages(roomId).then((msgs) => _roomStreamControllers[roomId]!.add(msgs));
    
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
    await db.insert('rooms', room.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    final maps = await db.query('rooms', orderBy: 'timestamp DESC');
    final rooms = maps.map((e) => ChatSession.fromMap(e)).toList();
    _recentChatsController.add(rooms);
  }
}
