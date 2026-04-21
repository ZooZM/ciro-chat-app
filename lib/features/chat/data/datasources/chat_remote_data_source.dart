import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';

abstract class ChatRemoteDataSource {
  Future<void> connect();
  Future<void> disconnect();
  void sendMessage(String text);
  Stream<Message> get messageStream;
}

@LazySingleton(as: ChatRemoteDataSource)
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final FlutterSecureStorage _secureStorage;
  IO.Socket? _socket;
  final _messageController = StreamController<Message>.broadcast();

  ChatRemoteDataSourceImpl(this._secureStorage);

  @override
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _secureStorage.read(key: 'accessToken');

    _socket = IO.io('http://localhost:3000', IO.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build());

    _socket!.onConnect((_) {
      // You can add logic here if needed handling successful connection
    });

    _socket!.on('receive_message', (data) {
      if (data is Map<String, dynamic>) {
        final message = Message(
          id: data['id']?.toString() ?? '',
          clientMessageId: data['clientMessageId']?.toString() ?? data['id']?.toString() ?? '',
          roomId: data['roomId']?.toString() ?? 'unknown',
          senderId: data['senderId']?.toString() ?? '',
          text: data['text']?.toString() ?? '',
          timestamp: data['timestamp'] != null 
              ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now() 
              : DateTime.now(),
        );
        _messageController.add(message);
      }
    });

    _socket!.onDisconnect((_) {
      // Handle socket disconnect
    });
  }

  @override
  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  @override
  void sendMessage(String text) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_message', {'text': text});
    }
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;
}
