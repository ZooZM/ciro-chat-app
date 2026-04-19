import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SocketService {
  IO.Socket? _socket;
  
  // Exposes declarative binding for WhatsApp-style Connecting... banner
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);

  // ── Chat callbacks ────────────────────────────────────────────────────────
  void Function(Map<String, dynamic> data)? onNewMessage;
  void Function(String messageId)? onMessageDelivered;

  // ── Call signaling callbacks (set by CallCubit) ───────────────────────────
  void Function(Map<String, dynamic> data)? onIncomingCall;
  void Function(Map<String, dynamic> data)? onCallAccepted;
  void Function(Map<String, dynamic> data)? onCallRejected;

  /// Connects to the NestJS WebSocket Gateway
  void connect(String token) {
    final url = "https://firstly-perforative-jaylah.ngrok-free.dev";

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      debugPrint('Socket Connected to WS namespace');
      isConnectedNotifier.value = true;
    });

    _socket?.onConnectError((err) {
      debugPrint('Socket Connect Error: $err');
      isConnectedNotifier.value = false;
    });
    
    _socket?.onDisconnect((_) {
      debugPrint('Socket Disconnected');
      isConnectedNotifier.value = false;
    });

    // ── Chat events ───────────────────────────────────────────────────────
    _socket?.on('newMessage', (data) {
      onNewMessage?.call(data as Map<String, dynamic>);
    });

    _socket?.on('messageDelivered', (data) {
      final msgId = (data as Map<String, dynamic>)['messageId'];
      onMessageDelivered?.call(msgId as String);
    });

    // ── Call signaling events ─────────────────────────────────────────────
    _socket?.on('incomingCall', (data) {
      debugPrint('[CALL] incomingCall: $data');
      onIncomingCall?.call(data as Map<String, dynamic>);
    });

    _socket?.on('callAccepted', (data) {
      debugPrint('[CALL] callAccepted: $data');
      onCallAccepted?.call(data as Map<String, dynamic>);
    });

    _socket?.on('callRejected', (data) {
      debugPrint('[CALL] callRejected: $data');
      onCallRejected?.call(data as Map<String, dynamic>);
    });
  }

  // ── Chat emitters ─────────────────────────────────────────────────────────

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
      debugPrint('Socket offline: Cannot send message instantly');
    }
  }

  void markAsRead({required String roomId, required String messageId}) {
    _socket?.emit('markRead', {'chatRoomId': roomId, 'messageId': messageId});
  }

  // ── Call signaling emitters ───────────────────────────────────────────────

  /// Step 1 — Caller initiates call
  void requestCall({required String targetUserId, bool isVideo = true}) {
    debugPrint('[CALL] requestCall: $targetUserId');
    _socket?.emit('requestCall', {
      'targetUserId': targetUserId,
      'isVideo': isVideo,
    });
  }

  /// Step 2a — Receiver accepts
  void acceptCall({required String callerId}) {
    _socket?.emit('acceptCall', {'callerId': callerId});
  }

  /// Step 2b — Receiver declines
  void rejectCall({required String callerId}) {
    _socket?.emit('rejectCall', {'callerId': callerId});
  }

  /// Either side ends the active call
  void endCall() {
    _socket?.emit('endCall', {});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
