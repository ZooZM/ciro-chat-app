import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';

import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_api_service.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/contacts/data/contacts_service.dart';

part 'chat_state.dart';

@injectable
class ChatCubit extends Cubit<ChatState> {
  final ChatLocalDataSource _localDataSource;
  final SocketService _socketService;
  final AuthLocalDataSource _authLocalDataSource;
  final ChatApiService _chatApiService;
  final ContactsService _contactsService;

  StreamSubscription<List<Message>>? _roomStreamSub;
  String? _activeRoomId;
  String currentUserId = ''; // Statically exposed to frontend wrappers
  final _uuid = const Uuid();

  ChatCubit(
    this._localDataSource,
    this._socketService,
    this._authLocalDataSource,
    this._chatApiService,
    this._contactsService,
  ) : super(ChatInitial()) {
    _initServices();
  }

  // Getter mapping the native stream completely to the ChatListScreen
  Stream<List<ChatSession>> get recentChatsStream =>
      _localDataSource.watchRecentChats();

  Future<void> _initServices() async {
    // 1. Organic local identity resolution
    currentUserId = await _authLocalDataSource.getUserPhone() ?? '';

    // 2. Initialize SQL
    await _localDataSource.initDB();

    // Wire socket callbacks
    _socketService.onMessageDelivered = (messageId) async {
      // Server ACKed the message!
      await _localDataSource.updateMessageStatus(messageId, MessageStatus.sent);
    };

    _socketService.onNewMessage = (data) async {
      final incoming = Message(
        id: data['id'] ?? _uuid.v4(),
        roomId: data['chatRoomId'] ?? 'unknown',
        senderId: data['senderId'] ?? 'them',
        text: data['content'] ?? '',
        timestamp: DateTime.now(), // Real app: parse data['timestamp']
        status: MessageStatus.delivered,
      );

      await _localDataSource.saveMessage(incoming);

      // Tell server we received it locally
      _socketService.markAsRead(
        roomId: incoming.roomId,
        messageId: incoming.id,
      );
    };
  }

  /// Called when User opens a ChatRoom
  void openRoom(String roomId) {
    if (_activeRoomId == roomId) return;

    _activeRoomId = roomId;
    _roomStreamSub?.cancel();
    emit(ChatLoading());

    // Listen to our reactive local database slice
    _roomStreamSub = _localDataSource
        .watchRoomMessages(roomId)
        .listen(
          (messages) {
            emit(ChatRoomActive(roomId, messages));
          },
          onError: (e) {
            emit(ChatError(e.toString()));
          },
        );
  }

  /// Sends a local-first message
  Future<void> sendLocalMessage(String text) async {
    if (_activeRoomId == null) return;
    final roomId = _activeRoomId!;

    final msgId = _uuid.v4();
    final newMsg = Message(
      id: msgId,
      roomId: roomId,
      senderId: currentUserId.isNotEmpty
          ? currentUserId
          : 'me', // Real dynamically resolved user!
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.pending, // Offline-first pending start!
    );

    // 1. Immediately inject to local DB -> UI rebuilds instantly via Stream!
    await _localDataSource.saveMessage(newMsg);

    // 2. Transmit async via WebSockets
    _socketService.sendMessage(
      roomId: roomId,
      messageId: msgId,
      text: text,
      type: 'text',
    );
  }

  Future<void> syncContacts() async {
    emit(ChatLoading());
    try {
      final contacts = await _contactsService.syncContacts();
      emit(ChatContactsSynced(contacts));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  /// Triggered via manual connect/login payload
  void connectNetwork(String jwtToken) async {
    _socketService.connect(jwtToken);
    await hydrateRooms(); // Always sync rooms after connecting
  }

  /// Fetches rooms from the API and saves to local SQLite.
  /// Safe to call on every ChatListScreen open — rooms table uses REPLACE conflict.
  Future<void> hydrateRooms() async {
    try {
      final rooms = await _chatApiService.fetchRooms();
      for (final room in rooms) {
        await _localDataSource.saveRoom(room);
      }
      debugPrint('[ChatCubit] Hydrated ${rooms.length} room(s) into SQLite');
    } catch (e) {
      debugPrint('[ChatCubit] Hydration silent fail: $e');
    }
  }

  @override
  Future<void> close() {
    _roomStreamSub?.cancel();
    _socketService.disconnect();
    return super.close();
  }
}
