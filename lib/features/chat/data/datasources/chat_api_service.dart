import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ChatApiService {
  final DioClient _dioClient;
  final AuthLocalDataSource _authLocalDataSource;

  ChatApiService(this._dioClient, this._authLocalDataSource);

  Future<List<ChatSession>> fetchRooms() async {
    try {
      // Needed to resolve which participant is "the other person" in PRIVATE rooms.
      final currentUserPhone = await _authLocalDataSource.getUserPhone() ?? '';

      final response = await _dioClient.dio.get('/chat/rooms');

      // Backend wraps the list inside { success: true, data: [...] }
      final raw = response.data;
      final List<dynamic> roomsJson = (raw is List)
          ? raw
          : (raw['data'] ?? raw['rooms'] ?? []);

      debugPrint('[ChatApiService] Fetched ${roomsJson.length} room(s)');

      // Parse each room individually. Use a fold so a single malformed room
      // never crashes the entire list — it is silently skipped with a log.
      final List<ChatSession> chatSessions = [];
      for (final json in roomsJson) {
        try {
          final chatSession = ChatSession.fromJson(
            json as Map<String, dynamic>,
            currentUserPhone,
          );
          chatSessions.add(chatSession);
        } catch (parseError) {
          // One bad room must not kill the rest.
          debugPrint('[ChatApiService] Skipped malformed room: $parseError');
        }
      }

      // Contact name resolution is intentionally NOT done here.
      // The SQLite LEFT JOIN in _dispatchRecentChatsUpdate already overlays
      // the saved contact name/avatar at query time — no FlutterContacts call needed.
      return chatSessions;
    } catch (e) {
      debugPrint('[ChatApiService] fetchRooms failed: $e');
      return [];
    }
  }

  /// Just-In-Time room resolution — called only when the very first message is sent.
  /// Returns the canonical MongoDB room _id from the backend.
  Future<String> createRoom(String targetUserId) async {
    final response = await _dioClient.dio.post(
      '/chat/private/resolve',
      data: {'userId': targetUserId},
    );
    final data = response.data['data'] ?? response.data;
    final roomId = data['roomId'] ?? data['_id'] ?? data['id'];
    if (roomId == null) throw Exception('Backend returned no roomId');
    return roomId.toString();
  }
}
