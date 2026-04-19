import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:injectable/injectable.dart';

import 'package:ciro_chat_app/core/network/dio_client.dart';

// TOP LEVEL: Safe Isolate Context Execution stripping UI boundaries natively
Future<Map<String, String>> _normalizeContactsIsolate(
  Map<String, dynamic> params,
) async {
  final List<Contact> rawContacts = params['contacts'] as List<Contact>;
  final String defaultCountryCode = params['defaultCountryCode'] as String;

  final Map<String, String> phoneToName = {};

  for (var contact in rawContacts) {
    if (contact.phones.isEmpty) continue;

    for (var phone in contact.phones) {
      String normalized = phone.number.replaceAll(RegExp(r'[^\d+]'), '');
      if (normalized.isEmpty) continue;

      if (normalized.startsWith('00')) {
        normalized = '+${normalized.substring(2)}';
      }

      if (!normalized.startsWith('+')) {
        if (normalized.startsWith('0')) {
          normalized = '$defaultCountryCode${normalized.substring(1)}';
        } else {
          normalized = '$defaultCountryCode$normalized';
        }
      }

      if (normalized.length >= 8) {
        phoneToName[normalized] = contact.displayName ?? '';
      }
    }
  }
  return phoneToName;
}

@lazySingleton
class ContactsService {
  final DioClient _dioClient;

  ContactsService(this._dioClient);

  Future<List<ChatSession>> syncContacts({
    String defaultCountryCode = '+20',
  }) async {
    // 1. Request Permission
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      throw Exception('Contact permission denied');
    }

    // 2. Fetch raw device contacts (with phones)
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    // 3. Normalize numbers & Create a Lookup Map purely inside a Background Isolate Thread protecting 60fps!
    final Map<String, String> phoneToName = await compute(
      _normalizeContactsIsolate,
      {'contacts': contacts, 'defaultCountryCode': defaultCountryCode},
    );

    if (phoneToName.isEmpty) return [];

    // 4. Send bulk list to API
    try {
      debugPrint(
        '[ContactsService] Syncing ${phoneToName.length} numbers exclusively via Background Isolate payload',
      );

      final payload = {'phoneNumbers': phoneToName.keys.toList()};

      final response = await _dioClient.dio.post(
        '/users/sync-contacts',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data;
        final List<dynamic> data = (raw is List)
            ? raw
            : (raw['data'] ?? raw['users'] ?? []);

        return data.map((json) {
          // Extract the exact phone number returned from your backend
          final String phoneFromApi = json['phoneNumber'] ?? '';

          // Match it instantly natively
          final String resolvedName = phoneToName[phoneFromApi] ?? "Unknown";

          return ChatSession(
            id: json['id'] ?? json['_id'] ?? 'tmp',
            // Fallback: 1. Contact Name -> 2. Backend Name -> 3. "Unknown"
            name: resolvedName.isNotEmpty && resolvedName != "Unknown"
                ? resolvedName
                : (json['name'] ?? "Unknown"),
            lastMessage: 'Tap to start chatting',
            timestamp: DateTime.now(),
            avatarUrl:
                json['avatarUrl'] ??
                json['profilePicture'] ??
                'https://i.pravatar.cc/150?u=${json['id'] ?? json['_id']}',
            isOnline: json['isOnline'] == true,
            phoneNumber: phoneFromApi,
          );
        }).toList();
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
