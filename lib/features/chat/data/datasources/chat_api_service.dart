import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

@lazySingleton
class ChatApiService {
  final DioClient _dioClient;
  final AuthLocalDataSource _authLocalDataSource;

  ChatApiService(this._dioClient, this._authLocalDataSource);

  Future<List<ChatSession>> fetchRooms() async {
    try {
      // Needed to resolve which participant is "the other person" in PRIVATE rooms
      final currentUserPhone = await _authLocalDataSource.getUserPhone() ?? '';

      final response = await _dioClient.dio.get('/chat/rooms');

      // Backend wraps the list inside { success: true, data: [...] }
      final raw = response.data;
      final List<dynamic> roomsJson = (raw is List)
          ? raw
          : (raw['data'] ?? raw['rooms'] ?? []);

      debugPrint('[ChatApiService] Fetched ${roomsJson.length} room(s)');
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        throw Exception('Contact permission denied');
      }

      // 2. Fetch raw device contacts (with phones)
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );

      // 3. Normalize numbers
      final List<Contact> rawNumbers = contacts;
      final List<ChatSession> chatSessions = [];
      for (var json in roomsJson) {
        final contact = rawNumbers.firstWhere(
          (contact) => contact.phones.any(
            (phone) => phone.number == json['participants'][1]['phoneNumber'],
          ),
        );
        json['participants'][1]['name'] = contact.displayName;
        final chatSession = ChatSession.fromJson(
          json as Map<String, dynamic>,
          currentUserPhone,
        );
        chatSessions.add(chatSession);
      }
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
