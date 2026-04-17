import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ChatApiService {
  final DioClient _dioClient;

  ChatApiService(this._dioClient);

  Future<List<ChatSession>> fetchRooms() async {
    try {
      final response = await _dioClient.dio.get('/chat/rooms');
      final data = response.data['data'] as List;
      return data.map((json) => ChatSession.fromMap(json)).toList();
    } catch (e) {
      // Return empty list if fetch fails or endpoint doesn't exist yet
      return [];
    }
  }
}
