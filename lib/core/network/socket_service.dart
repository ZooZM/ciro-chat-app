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

  // ── Chat callbacks ────────────────────────────────────────────────────────
  void Function(Map<String, dynamic> data)? onNewMessage;
  void Function(String messageId)? onMessageDelivered;

  // ── Call signaling callbacks (set by CallCubit) ───────────────────────────
  void Function(Map<String, dynamic> data)? onIncomingCall;
  void Function(Map<String, dynamic> data)? onCallAccepted;
  void Function(Map<String, dynamic> data)? onCallRejected;

  /// Connects to the NestJS WebSocket Gateway
  void connect(String token) async {
    final authLocal = getIt<AuthLocalDataSource>();
    if (token.isEmpty) return; // Prevent ghost connections
    final isLoggedIn = await authLocal.getLoggedInStatus();
    if (!isLoggedIn) return; // Strictly only connect if Auth flow completed

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

  void joinRoom(String roomId) {
    if (_socket!.connected) {
      _socket!.emit('joinRoom', {'roomId': roomId});
      debugPrint('[Socket] Joined room: $roomId');
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
