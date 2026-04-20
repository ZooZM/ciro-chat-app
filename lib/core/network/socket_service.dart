import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/core/di/injection.dart';

@lazySingleton
class SocketService {
  IO.Socket? _socket;
  bool _isRefreshing = false;

  // Exposes declarative binding for WhatsApp-style Connecting... banner
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);

  /// Synchronous connectivity check for guard clauses.
  bool get isConnected => _socket?.connected ?? false;

  // ── Chat callbacks ────────────────────────────────────────────────────────

  /// Fired when the SERVER confirms it stored our message (sender side).
  /// Promotes: pending → sent (1 grey tick)
  void Function(String messageId)? onMessageDelivered;

  /// Fired when the RECIPIENT's device received our message.
  /// Promotes: sent → delivered (2 grey ticks)
  void Function(String messageId)? onMessageDeliveryUpdate;

  /// Fired when the RECIPIENT read our message.
  /// Promotes: delivered → read (2 blue ticks)
  void Function(String messageId)? onMessageReadUpdate;

  /// Fired when WE receive a new message from another user.
  void Function(Map<String, dynamic> data)? onNewMessage;

  // ── Call signaling callbacks (set by CallCubit) ───────────────────────────
  void Function(Map<String, dynamic> data)? onIncomingCall;
  void Function(Map<String, dynamic> data)? onCallAccepted;
  void Function(Map<String, dynamic> data)? onCallRejected;

  /// Connects to the NestJS WebSocket Gateway.
  /// ONLY call this after the backend has definitively verified the token
  /// (i.e., inside AuthCubit after checkAuthStatus() or verifyOtp() succeeds).
  /// This method is a pure primitive — it trusts its caller completely.
  void connect(String token) {
    if (token.isEmpty) {
      debugPrint('[SocketService] connect() called with empty token — ignored');
      return;
    }

    // Tear down any previous socket cleanly before creating a new one.
    // This prevents duplicate listeners if connect() is called more than once
    // (e.g., during mid-session token refresh via DioClient).
    disconnect();

    final url = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'https://firstly-perforative-jaylah.ngrok-free.dev',
    );

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
      _isRefreshing = false; // Reset lock strictly on successful pass
    });

    _socket?.onConnectError((err) async {
      debugPrint('Socket Connect Error: $err');
      isConnectedNotifier.value = false;

      final errorStr = err.toString().toLowerCase();
      if (errorStr.contains('jwt expired') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('401')) {
        await _handleTokenRefresh();
      }
    });

    _socket?.onDisconnect((reason) async {
      debugPrint('Socket Disconnected: $reason');
      isConnectedNotifier.value = false;

      final reasonStr = reason.toString().toLowerCase();
      if (reasonStr.contains('jwt expired') ||
          reasonStr.contains('unauthorized') ||
          reasonStr.contains('401')) {
        await _handleTokenRefresh();
      }
    });

    // ── Chat events ───────────────────────────────────────────────────────

    // Sender receives this when the SERVER has stored the message.
    // pending → sent
    _socket?.on('messageDelivered', (data) {
      final msgId = (data as Map<String, dynamic>)['messageId'] as String?;
      if (msgId != null) onMessageDelivered?.call(msgId);
    });

    // Sender receives this when the RECIPIENT's device acknowledged receipt.
    // sent → delivered
    _socket?.on('messageDeliveredUpdate', (data) {
      final msgId = (data as Map<String, dynamic>)['messageId'] as String?;
      if (msgId != null) onMessageDeliveryUpdate?.call(msgId);
    });

    // Sender receives this when the RECIPIENT has read the message.
    // delivered → read
    _socket?.on('messageReadUpdate', (data) {
      final msgId = (data as Map<String, dynamic>)['messageId'] as String?;
      if (msgId != null) onMessageReadUpdate?.call(msgId);
    });

    // WE receive a new inbound message.
    _socket?.on('receiveMessage', (data) {
      onNewMessage?.call(data as Map<String, dynamic>);
    });
    // Legacy event name — keep both so backend naming doesn't matter.
    _socket?.on('newMessage', (data) {
      onNewMessage?.call(data as Map<String, dynamic>);
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

  /// Joins a chat room's socket channel. Call this immediately after a JIT
  /// room is created so the backend starts routing messages to this client.
  void joinRoom(String roomId) {
    _socket?.emit('joinRoom', {'chatRoomId': roomId});
    debugPrint('[SocketService] Joined room: $roomId');
  }

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

  /// Emits `markDelivered` so the SENDER's UI promotes to 2 grey ticks.
  /// Call this immediately when WE receive a message (recipient side).
  void markDelivered({required String roomId, required String messageId}) {
    _socket?.emit('markDelivered', {
      'chatRoomId': roomId,
      'messageId': messageId,
    });
  }

  /// Emits `markRead` so the SENDER's UI promotes to 2 blue ticks.
  /// Only call this when the user is ACTIVELY viewing the room.
  void markRead({required String roomId, required String messageId}) {
    _socket?.emit('markRead', {
      'chatRoomId': roomId,
      'messageId': messageId,
    });
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

  Future<void> _handleTokenRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    debugPrint(
      '[SocketService] Token expired. Pausing reconnection and triggering refresh...',
    );
    _socket
        ?.disconnect(); // Ensure socket stops hammering the server while we cleanly HTTP refresh

    final authLocal = getIt<AuthLocalDataSource>();

    try {
      final refreshToken = await authLocal.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        // Launch isolated network payload identical to DioClient interceptor logic
        final refreshDio = Dio(
          BaseOptions(
            baseUrl: const String.fromEnvironment(
              'API_URL',
              defaultValue: 'https://firstly-perforative-jaylah.ngrok-free.dev',
            ),
          ),
        );

        final response = await refreshDio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );

        final newAccess = response.data['accessToken'];
        final newRefresh = response.data['refreshToken'] ?? refreshToken;

        await authLocal.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        debugPrint(
          '[SocketService] Refresh successful. Resuming socket connection...',
        );
        if (_socket != null) {
          _socket!.auth = {'token': newAccess};
          _socket!.connect();
        }
      } else {
        await authLocal.deleteTokens();
      }
    } catch (e) {
      debugPrint('[SocketService] Socket Token Refresh Failed: $e');
      await authLocal.deleteTokens();
    } finally {
      _isRefreshing = false;
    }
  }
}
