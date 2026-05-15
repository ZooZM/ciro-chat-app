import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/network/dio_client.dart' show globalOnUnauthorizedRedirect;

@lazySingleton
class SocketService {
  IO.Socket? _socket;
  bool _isRefreshing = false;

  // Exposes declarative binding for WhatsApp-style Connecting... banner
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);

  /// Synchronous connectivity check for guard clauses.
  bool get isConnected => _socket?.connected ?? false;

  // ── Chat callbacks ────────────────────────────────────────────────────────
  void Function(String userId, bool isOnline)? onUserStatusChanged;

  /// Fired when SERVER confirms it stored our message. pending → sent (1 grey tick)
  void Function(String clientMessageId, DateTime? createdAt)? onMessageSent;

  /// Fired when RECIPIENT device received our message. sent → delivered (2 grey ticks)
  void Function(List<String> clientMessageIds)? onMessageDelivered;

  /// Fired when RECIPIENT read our message. delivered → read (2 blue ticks)
  /// [readByCount] and [participantCount] are present for GROUP rooms only.
  void Function(
    List<String> clientMessageIds, {
    int? readByCount,
    int? participantCount,
  })? onMessageRead;

  /// Fired when WE receive a new message from another user.
  void Function(Map<String, dynamic> data)? onNewMessage;

  /// Fired after a successful socket reconnect — use to trigger REST status sync.
  void Function()? onReconnected;

  /// Fired when another user in the active room is typing.
  void Function(
    String roomId,
    String userId,
    String phoneNumber,
    bool isTyping,
  )?
  onUserTyping;

  // ── Call signaling callbacks (set by CallCubit) ───────────────────────────
  void Function(Map<String, dynamic> data)? onIncomingCall;
  void Function(Map<String, dynamic> data)? onCallAccepted;
  void Function(Map<String, dynamic> data)? onCallRejected;

  /// Fired when an admin updates the group name or avatar via PATCH /chat/group/:roomId.
  void Function(Map<String, dynamic> data)? onChatRoomUpdated;

  /// Fired when the current user is added to a brand-new chat room (e.g.
  /// someone else created a group and included them). Payload: `{ room: {...} }`.
  void Function(Map<String, dynamic> data)? onNewChatRoom;

  // ── Group call callbacks (set by CallCubit) ───────────────────────────────
  void Function(Map<String, dynamic> data)? onIncomingGroupCall;
  void Function(Map<String, dynamic> data)? onGroupCallParticipantJoined;
  void Function(Map<String, dynamic> data)? onGroupCallParticipantLeft;
  void Function(Map<String, dynamic> data)? onGroupCallRecordingStateChanged;

  // ── Status updates callbacks ──────────────────────────────────────────────
  void Function(Map<String, dynamic> data)? onStatusReceived;

  /// FR-022: Fired when someone deletes a message for everyone.
  void Function(String clientMessageId)? onMessageDeleted;

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

    _socket = IO.io(
      AppConstants.apiBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      debugPrint('[SocketService] Connected');
      isConnectedNotifier.value = true;
      _isRefreshing = false;
      // Notify Cubit so it can trigger the REST status sync for missed events.
      onReconnected?.call();
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
    // NOTE: socket.io-client (Dart) delivers event payloads as Map<dynamic,dynamic>,
    // NOT Map<String,dynamic>. Never use `data as Map<String,dynamic>` or
    // `data is Map<String,dynamic>` — both fail silently at runtime.
    // Always guard with `data is! Map`, then use Map<String,dynamic>.from(data as Map).

    // SERVER confirmed storage: pending → sent (1 grey tick)
    _socket?.on('messageSent', (data) {
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final id = map['clientMessageId']?.toString();
      final createdAtStr = map['createdAt']?.toString();
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      if (id != null && id.isNotEmpty) onMessageSent?.call(id, createdAt);
    });

    // RECIPIENT device acknowledged receipt: sent → delivered (2 grey ticks)
    _socket?.on('messageDelivered', (data) {
      debugPrint('[SocketService] Message delivered: $data');
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final ids = map['clientMessageIds'] as List<dynamic>?;
      if (ids != null) onMessageDelivered?.call(ids.map((e) => e.toString()).toList());
    });

    // RECIPIENT read the message: delivered → read (2 blue ticks)
    _socket?.on('messageRead', (data) {
      debugPrint('[SocketService] Message read: $data');
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final ids = map['clientMessageIds'] as List<dynamic>?;
      if (ids != null) {
        final readByCount = map['readByCount'] as int?;
        final participantCount = map['participantCount'] as int?;
        onMessageRead?.call(
          ids.map((e) => e.toString()).toList(),
          readByCount: readByCount,
          participantCount: participantCount,
        );
      }
    });

    // Inbound message from another user.
    _socket?.on('receiveMessage', (data) {
      if (data == null || data is! Map) return;
      onNewMessage?.call(Map<String, dynamic>.from(data));
    });
    // Legacy name — keep both until backend is fully migrated.
    _socket?.on('newMessage', (data) {
      if (data == null || data is! Map) return;
      onNewMessage?.call(Map<String, dynamic>.from(data));
    });

    // Inbound typing indicator
    _socket?.on('userTyping', (data) {
      if (data == null || data is! Map) return;
      final roomId = data['chatRoomId']?.toString() ?? '';
      final userId = data['userId']?.toString() ?? '';
      final phoneNumber = data['phoneNumber']?.toString() ?? '';
      final isTyping = data['isTyping'] == true;
      onUserTyping?.call(roomId, userId, phoneNumber, isTyping);
    });

    // ── Call signaling events ─────────────────────────────────────────────
    _socket?.on('incomingCall', (data) {
      debugPrint('[CALL] incomingCall: $data');
      if (data == null || data is! Map) return;
      onIncomingCall?.call(Map<String, dynamic>.from(data));
    });

    _socket?.on('callAccepted', (data) {
      debugPrint('[CALL] callAccepted: $data');
      if (data == null || data is! Map) return;
      onCallAccepted?.call(Map<String, dynamic>.from(data));
    });

    _socket?.on('callRejected', (data) {
      debugPrint('[CALL] callRejected: $data');
      if (data == null || data is! Map) return;
      onCallRejected?.call(Map<String, dynamic>.from(data));
    });

    _socket?.on('userStatus', (data) {
      if (data == null || data is! Map) return;
      final userId = data['userId']?.toString() ?? '';
      final isOnline = data['isOnline'] == true;
      if (userId.isNotEmpty) onUserStatusChanged?.call(userId, isOnline);
    });

    // ── Status events ─────────────────────────────────────────────────────
    _socket?.on('statusReceived', (data) {
      debugPrint('[STATUS] statusReceived: $data');
      if (data == null || data is! Map) return;
      onStatusReceived?.call(Map<String, dynamic>.from(data));
    });

    // ── FR-022: Message deletion ──────────────────────────────────────────
    _socket?.on('messageDeleted', (data) {
      debugPrint('[DELETE] messageDeleted: $data');
      if (data == null || data is! Map) return;
      final clientMsgId = data['clientMessageId']?.toString() ?? '';
      if (clientMsgId.isNotEmpty) onMessageDeleted?.call(clientMsgId);
    });

    // ── Group call signaling events ───────────────────────────────────────
    _socket?.on('incomingGroupCall', (data) {
      debugPrint('[GROUP CALL] incomingGroupCall: $data');
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      onIncomingGroupCall?.call(map);
    });

    _socket?.on('groupCallParticipantJoined', (data) {
      debugPrint('[GROUP CALL] participantJoined: $data');
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      onGroupCallParticipantJoined?.call(map);
    });

    _socket?.on('groupCallParticipantLeft', (data) {
      debugPrint('[GROUP CALL] participantLeft: $data');
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      onGroupCallParticipantLeft?.call(map);
    });

    _socket?.on('groupCallRecordingStateChanged', (data) {
      debugPrint('[GROUP CALL] recordingStateChanged: $data');
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      onGroupCallRecordingStateChanged?.call(map);
    });

    // ── Group/room metadata updates ───────────────────────────────────────────
    _socket?.on('chatRoomUpdated', (data) {
      debugPrint('[SocketService] chatRoomUpdated: $data');
      if (data == null || data is! Map) return;
      onChatRoomUpdated?.call(Map<String, dynamic>.from(data));
    });

    _socket?.on('newChatRoom', (data) {
      debugPrint('[SocketService] newChatRoom: $data');
      if (data == null || data is! Map) return;
      onNewChatRoom?.call(Map<String, dynamic>.from(data));
    });
  }

  // ── Chat emitters ─────────────────────────────────────────────────────────

  /// Joins a chat room's socket channel. Call this immediately after a JIT
  /// room is created so the backend starts routing messages to this client.
  void joinRoom(String roomId) {
    _socket?.emit('joinRoom', {'roomId': roomId});
    debugPrint('[SocketService] Joined room: $roomId');
  }

  /// Emits a typing indicator event for the specified room.
  void emitTyping(String roomId, bool isTyping) {
    if (roomId.isNotEmpty && (_socket?.connected ?? false)) {
      _socket?.emit('typing', {'roomId': roomId, 'isTyping': isTyping});
    }
  }

  void sendMessage({
    required String roomId,
    required String messageId,
    required String text,
    required String type,
    String? fileUrl,
    Map<String, dynamic>? metadata,
  }) {
    if (_socket != null && _socket!.connected) {
      final payload = <String, dynamic>{
        'chatRoomId': roomId,
        'clientMessageId': messageId,
        'content': text,
        'type': type,
      };
      if (fileUrl != null && fileUrl.isNotEmpty) payload['fileUrl'] = fileUrl;
      if (metadata != null && metadata.isNotEmpty) {
        payload['metadata'] = metadata;
      }

      _socket!.emit('sendMessage', payload);
    } else {
      debugPrint('Socket offline: Cannot send message instantly');
    }
  }

  /// Emits `markDelivered` so the SENDER's UI promotes to 2 grey ticks.
  /// Call this immediately when WE receive a message (recipient side).
  void markDelivered({
    required String roomId,
    required List<String> messageIds,
  }) {
    _socket?.emit('markDelivered', {
      'chatRoomId': roomId,
      'clientMessageIds': messageIds,
    });
  }

  /// Emits `markRead` so the SENDER's UI promotes to 2 blue ticks.
  /// Only call this when the user is ACTIVELY viewing the room.
  void markRead({required String roomId, required List<String> messageIds}) {
    _socket?.emit('markRead', {
      'chatRoomId': roomId,
      'clientMessageIds': messageIds,
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

  // ── Group call emitters ───────────────────────────────────────────────────

  /// Caller initiates a group call — backend fans out `incomingGroupCall` to room members.
  void requestGroupCall({required String chatRoomId, required bool isVideo}) {
    _socket?.emit('requestGroupCall', {'chatRoomId': chatRoomId, 'isVideo': isVideo});
  }

  /// Invited member accepts the group call — backend issues a LiveKit token.
  void acceptGroupCall({required String chatRoomId}) {
    _socket?.emit('acceptGroupCall', {'chatRoomId': chatRoomId});
  }

  /// Member declines the invitation — no broadcast to others.
  void declineGroupCall({required String chatRoomId}) {
    _socket?.emit('declineGroupCall', {'chatRoomId': chatRoomId});
  }

  /// Participant leaves an active group call.
  void leaveGroupCall({required String chatRoomId}) {
    _socket?.emit('leaveGroupCall', {'chatRoomId': chatRoomId});
  }

  /// Notifies all participants that this client started or stopped local recording.
  void emitGroupCallRecordingStateChanged({
    required String chatRoomId,
    required bool isRecording,
  }) {
    _socket?.emit('groupCallRecordingStateChanged', {
      'chatRoomId': chatRoomId,
      'isRecording': isRecording,
    });
  }

  // ── Status emitters ─────────────────────────────────────────────────────
  void uploadStatus(Map<String, dynamic> statusPayload) {
    _socket?.emit('uploadStatus', statusPayload);
  }

  void notifyStatusViewed(String statusId) {
    _socket?.emit('statusViewed', {'statusId': statusId});
  }

  // ── FR-022: Message Deletion ─────────────────────────────────────────────
  void deleteMessageForEveryone(String clientMessageId) {
    _socket?.emit('deleteForEveryone', {'clientMessageId': clientMessageId});
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
        final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));

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
      globalOnUnauthorizedRedirect?.call();
    } finally {
      _isRefreshing = false;
    }
  }
}
