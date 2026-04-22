import 'dart:io';
import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ChatApiService {
  final DioClient _dioClient;
  final AuthLocalDataSource _authLocalDataSource;

  ChatApiService(this._dioClient, this._authLocalDataSource);

  // ── fetchRooms ──────────────────────────────────────────────────────────────

  Future<List<ChatSession>> fetchRooms() async {
    try {
      final currentUserPhone = await _authLocalDataSource.getUserPhone() ?? '';
      final response = await _dioClient.dio.get('/chat/rooms');

      final raw = response.data;
      final List<dynamic> roomsJson =
          (raw is List) ? raw : (raw['data'] ?? raw['rooms'] ?? []);

      debugPrint('[ChatApiService] Fetched ${roomsJson.length} room(s)');

      final List<ChatSession> chatSessions = [];
      for (final json in roomsJson) {
        try {
          chatSessions.add(
            ChatSession.fromJson(json as Map<String, dynamic>, currentUserPhone),
          );
        } catch (parseError) {
          debugPrint('[ChatApiService] Skipped malformed room: $parseError');
        }
      }
      return chatSessions;
    } catch (e) {
      debugPrint('[ChatApiService] fetchRooms failed: $e');
      return [];
    }
  }

  // ── createRoom ──────────────────────────────────────────────────────────────

  /// Just-In-Time room resolution — called only when the very first message
  /// is sent. Returns the canonical MongoDB room _id from the backend.
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

  // ── syncMessageStatuses ─────────────────────────────────────────────────────

  /// Polls the backend for the latest status of messages stuck in
  /// [pending] or [sent] state locally (i.e., we may have missed socket events).
  ///
  /// POST /chat/messages/sync-statuses
  /// Body:     { "clientMessageIds": ["uuid1", "uuid2", ...] }
  /// Response: Array<{ clientMessageId: string, status: string }>
  Future<Map<String, String>> syncMessageStatuses(
    List<String> clientMessageIds,
  ) async {
    if (clientMessageIds.isEmpty) return {};
    try {
      debugPrint(
        '[ChatApiService] syncStatuses → sending ${clientMessageIds.length} ids',
      );

      final response = await _dioClient.dio.post(
        '/chat/messages/sync-statuses',
        data: {'clientMessageIds': clientMessageIds},
      );

      final rawData = response.data;
      debugPrint(
        '[ChatApiService] syncStatuses ← type: ${rawData.runtimeType}, body: $rawData',
      );

      List<dynamic> rawList;
      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map) {
        final inner = rawData['data'] ?? rawData['statuses'];
        if (inner is List) {
          rawList = inner;
        } else {
          debugPrint(
            '[ChatApiService] syncStatuses: unexpected map. Keys: ${rawData.keys.toList()}',
          );
          return {};
        }
      } else {
        debugPrint(
          '[ChatApiService] syncStatuses: unexpected type ${rawData.runtimeType}',
        );
        return {};
      }

      debugPrint(
        '[ChatApiService] syncStatuses: parsed ${rawList.length} update(s)',
      );

      return {
        for (final item in rawList)
          if (item is Map &&
              item['clientMessageId'] != null &&
              item['status'] != null)
            item['clientMessageId'].toString(): item['status'].toString(),
      };
    } catch (e, st) {
      debugPrint('[ChatApiService] syncMessageStatuses failed: $e\n$st');
      return {};
    }
  }

  // ── uploadFile ──────────────────────────────────────────────────────────────

  /// Uploads [file] to POST /chat/upload as multipart/form-data.
  ///
  /// Returns a map with at minimum:
  ///   { fileUrl: String, fileName: String, fileSize: int, mimeType: String }
  ///
  /// Throws on any network or HTTP error so the caller can handle the
  /// optimistic bubble revert.
  Future<Map<String, dynamic>> uploadFile(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    debugPrint('[ChatApiService] Uploading file: $fileName');

    final response = await _dioClient.dio.post(
      '/chat/upload',
      data: formData,
      options: Options(
        headers: {
          // Override the default JSON content-type; Dio sets multipart
          // boundary automatically when FormData is used.
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    final raw = response.data;
    // Unwrap NestJS global interceptor envelope if present.
    final payload = (raw is Map && raw.containsKey('data'))
        ? raw['data'] as Map<String, dynamic>
        : raw as Map<String, dynamic>;

    debugPrint(
      '[ChatApiService] Upload success: ${payload['fileUrl']}',
    );

    return payload;
  }
}
