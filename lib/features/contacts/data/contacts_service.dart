import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:injectable/injectable.dart';

import 'package:ciro_chat_app/core/network/dio_client.dart';

@lazySingleton
class ContactsService {
  final DioClient _dioClient;

  ContactsService(this._dioClient);

  Future<List<ChatSession>> syncContacts() async {
    // 1. Request Permission using standard permission_handler
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      throw Exception('Contact permission denied');
    }

    // 2. Fetch raw device contacts (with phones)
    final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});

    // 3. Normalize numbers
    final List<String> rawNumbers = [];
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        // Strip spaces, dashes, parentheses
        var normalized = phone.number.replaceAll(RegExp(r'[^\d+]'), '');
        
        // Example logic: Default missing country codes to EG (+20)
        if (!normalized.startsWith('+') && normalized.length >= 10) {
           if (normalized.startsWith('0')) {
             normalized = '+20${normalized.substring(1)}';
           } else {
             normalized = '+20$normalized';
           }
        }
        
        if (normalized.isNotEmpty) rawNumbers.add(normalized);
      }
    }

    // Remove duplicates safely
    final uniqueNumbers = rawNumbers.toSet().toList();
    if (uniqueNumbers.isEmpty) return [];

    // 4. Send bulk list to API to cross-reference registered users
    try {
      // ⚠️ CHECK: Confirm the field name matches your NestJS DTO exactly.
      // Common variants: 'phones', 'phoneNumbers', 'contacts'
      // Log payload for debugging:
      debugPrint('[ContactsService] Syncing ${uniqueNumbers.length} numbers: $uniqueNumbers');

      final payload = {
        'phoneNumbers': uniqueNumbers, // ← adjust this key to match your NestJS DTO
      };

      final response = await _dioClient.dio.post('/users/sync-contacts', data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle both array and wrapped { data: [] } response shapes
        final raw = response.data;
        final List<dynamic> data = (raw is List) ? raw : (raw['data'] ?? raw['users'] ?? []);
        
        return data.map((json) => ChatSession(
           id: json['id'] ?? json['_id'] ?? 'tmp',
           name: json['name'] ?? json['displayName'] ?? 'Unknown',
           lastMessage: 'Tap to start chatting',
           timestamp: DateTime.now(),
           avatarUrl: json['avatarUrl'] ?? json['profilePicture'] ?? 'https://i.pravatar.cc/150?u=${json['id']}',
           isOnline: json['isOnline'] == true,
        )).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to synchronize contacts: $e');
    }
  }

  Future<String> resolvePrivateChat(String targetPhoneNumber) async {
    try {
      final response = await _dioClient.dio.post('/chat/private/resolve', data: {
         'phoneNumber': targetPhoneNumber
      });
      
      if (response.statusCode == 200 || response.statusCode == 201) {
         // Should return the unique roomId for this 1on1 session
         return response.data['roomId'] as String;
      }
      throw Exception('Server failed to resolve chat root');
    } catch (e) {
      throw Exception('Failed to resolve private chat: $e');
    }
  }
}
