import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SocketService {
  IO.Socket? _socket;

  // Callbacks for business logic
  void Function(Map<String, dynamic> data)? onNewMessage;
  void Function(String messageId)? onMessageDelivered;

  /// Connects to the NestJS WebSocket Gateway
  void connect(String token) {
    // For local dev, use 10.0.2.2 on android emulator or localhost on web/iOS
    final url ="https://firstly-perforative-jaylah.ngrok-free.dev";

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token}) // Standard NestJS WebSocket Auth Context
          .build(),
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      print('Socket Connected to WS namespace');
    });

    _socket?.onConnectError((err) => print('Socket Connect Error: $err'));

    _socket?.onDisconnect((_) => print('Socket Disconnected'));

    // NestJS Gateway Responders
    _socket?.on('newMessage', (data) {
      if (onNewMessage != null) {
        onNewMessage!(data as Map<String, dynamic>);
      }
    });

    _socket?.on('messageDelivered', (data) {
      if (onMessageDelivered != null) {
        final msgId = (data as Map<String, dynamic>)['messageId'];
        onMessageDelivered!(msgId);
      }
    });
  }

  /// Sends a local message up to the server
  void sendMessage({
    required String roomId,
    required String messageId,
    required String text,
    required String type,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('sendMessage', {
        'chatRoomId': roomId,
        'messageId': messageId,
        'content': text,
        'type': type,
      });
    } else {
      print('Socket offline: Cannot send message instantly');
    }
  }

  void markAsRead({required String roomId, required String messageId}) {
    _socket?.emit('markRead', {'chatRoomId': roomId, 'messageId': messageId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
