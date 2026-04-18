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
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    // 3. Normalize numbers
    final List<Contact> rawNumbers = contacts;
    // for (var contact in contacts) {
    //   for (var phone in contact.phones) {
    //     // Strip spaces, dashes, parentheses
    //     var normalized = phone.number.replaceAll(RegExp(r'[^\d+]'), '');

    //     // Example logic: Default missing country codes to EG (+20)
    //     if (!normalized.startsWith('+') && normalized.length >= 10) {
    //        if (normalized.startsWith('0')) {
    //          normalized = '+20${normalized.substring(1)}';
    //        } else {
    //          normalized = '+20$normalized';
    //        }
    //     }

    //     if (normalized.isNotEmpty) rawNumbers.add(normalized);
    //   }
    // }

    // Remove duplicates safely
    final uniqueNumbers = rawNumbers.toSet().toList();
    if (uniqueNumbers.isEmpty) return [];

    // 4. Send bulk list to API to cross-reference registered users
    try {
      debugPrint(
        '[ContactsService] Syncing ${uniqueNumbers.length} numbers: $uniqueNumbers',
      );

      final payload = {
        'phoneNumbers': uniqueNumbers
            .map((e) => e.phones.first.number)
            .toList(),
      };

      final response = await _dioClient.dio.post(
        '/users/sync-contacts',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle both array and wrapped { data: [] } response shapes
        final raw = response.data;
        final List<dynamic> data = (raw is List)
            ? raw
            : (raw['data'] ?? raw['users'] ?? []);

        return data
            .map(
              (json) => ChatSession(
                id: json['id'] ?? json['_id'] ?? 'tmp',
                name:
                    rawNumbers
                        .lastWhere(
                          (contact) => contact.phones.any(
                            (phone) => phone.number == json['phoneNumber'],
                          ),
                        )
                        .displayName ??
                    "Unknown",
                lastMessage: 'Tap to start chatting',
                timestamp: DateTime.now(),
                avatarUrl:
                    json['avatarUrl'] ??
                    json['profilePicture'] ??
                    'https://i.pravatar.cc/150?u=${json['id']}',
                isOnline: json['isOnline'] == true,
                phoneNumber: json['phoneNumber'] ?? '',
              ),
            )
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to synchronize contacts: $e');
    }
  }

  Future<String> resolvePrivateChat({
    required String targetPhoneNumber,
    required ChatSession chatSession,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/chat/private/resolve',
        data: {'phoneNumber': targetPhoneNumber},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data['data'] ?? response.data;

        final roomId =
            responseData['roomId'] ?? responseData['_id'] ?? responseData['id'];

        if (roomId != null) {
          return roomId.toString();
        }
      }
      throw Exception('Server failed to return a valid roomId');
    } catch (e) {
      debugPrint('Resolve Chat Error: $e');
      throw Exception('Failed to resolve private chat: $e');
    }
  }
}
