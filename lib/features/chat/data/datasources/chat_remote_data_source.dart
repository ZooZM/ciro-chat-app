import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';

abstract class ChatRemoteDataSource {
  Future<void> connect();
  Future<void> disconnect();
  void sendMessage(String text);
  Stream<Message> get messageStream;

  Future<Either<Failure, String>> createPrivateChatRoom(String targetUserId);
  Future<Either<Failure, Map<String, String>>> syncMessageStatuses(
    List<String> clientMessageIds,
  );
  Future<Either<Failure, Map<String, dynamic>>> uploadFile(File file);
  Future<Either<Failure, List<ChatSession>>> fetchRooms();

  // Group chat API endpoints
  Future<Either<Failure, Map<String, dynamic>>> createGroup(
    String groupName,
    List<String> participants,
    String? avatarUrl,
  );
  Future<Either<Failure, void>> addParticipants(
    String roomId,
    List<String> participants,
  );
  Future<Either<Failure, void>> removeParticipant(
    String roomId,
    String participantId,
  );
  Future<Either<Failure, void>> leaveGroup(String roomId);
}

@LazySingleton(as: ChatRemoteDataSource)
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final DioClient _dioClient;
  final SocketService _socketService;
  final AuthLocalDataSource _authLocalDataSource;
  final _messageController = StreamController<Message>.broadcast();

  ChatRemoteDataSourceImpl(
    this._dioClient,
    this._socketService,
    this._authLocalDataSource,
  ) {
    _socketService.onNewMessage = (data) {
      final message = Message(
        id: data['id']?.toString() ?? '',
        clientMessageId:
            data['clientMessageId']?.toString() ??
            data['id']?.toString() ??
            '',
        roomId: data['chatRoomId']?.toString() ?? data['roomId']?.toString() ?? 'unknown',
        senderId: data['senderId']?.toString() ?? '',
        text: data['content']?.toString() ?? '',
        timestamp: data['createdAt'] != null
            ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
      _messageController.add(message);
    };
  }

  @override
  Future<void> connect() async {
    // SocketService manages the connection globally, so we no longer manually connect here.
    // The AuthCubit calls _socketService.connect(token) directly.
  }

  @override
  Future<void> disconnect() async {
    // SocketService manages the connection globally.
  }

  @override
  void sendMessage(String text) {
    // Left empty. The Cubit uses _socketService directly to send messages
    // with correct roomId, messageId, etc.
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;

  // ── Helper ──────────────────────────────────────────────────────────────

  Dio get _dio => _dioClient.dio;

  // ── Group Chat API Endpoints ──────────────────────────────────────────────

  @override
  Future<Either<Failure, Map<String, dynamic>>> createGroup(
    String groupName,
    List<String> participants,
    String? avatarUrl,
  ) async {
    try {
      final response = await _dio.post(
        '/chat/group/create', // Assuming standard modular monolith path
        data: {
          'name': groupName,
          'participants': participants,
          'avatarUrl': avatarUrl,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final raw = response.data;
        final payload = (raw is Map && raw.containsKey('data'))
            ? raw['data'] as Map<String, dynamic>
            : raw as Map<String, dynamic>;
        return Right(payload);
      }
      return Left(
        ServerFailure(response.data['message'] ?? 'Failed to create group'),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addParticipants(
    String roomId,
    List<String> participants,
  ) async {
    try {
      final response = await _dio.post(
        '/chat/group/$roomId/participants',
        data: {'participants': participants},
      );
      if (response.statusCode == 200) {
        return const Right(null);
      }
      return Left(
        ServerFailure(response.data['message'] ?? 'Failed to add participants'),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeParticipant(
    String roomId,
    String participantId,
  ) async {
    try {
      final response = await _dio.delete('/chat/group/$roomId/participants/$participantId');
      if (response.statusCode == 200) {
        return const Right(null);
      }
      return Left(
        ServerFailure(
          response.data['message'] ?? 'Failed to remove participant',
        ),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> leaveGroup(String roomId) async {
    try {
      final response = await _dio.post('/chat/group/$roomId/leave');
      if (response.statusCode == 200) {
        return const Right(null);
      }
      return Left(
        ServerFailure(response.data['message'] ?? 'Failed to leave group'),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Private Chat API Endpoints ──────────────────────────────────────────────

  @override
  Future<Either<Failure, String>> createPrivateChatRoom(
    String targetUserId,
  ) async {
    try {
      final response = await _dio.post(
        '/chat/private/resolve',
        data: {'userId': targetUserId},
      );
      final data = response.data['data'] ?? response.data;
      final roomId = data['roomId'] ?? data['_id'] ?? data['id'];
      if (roomId == null) {
        return const Left(ServerFailure('Backend returned no roomId'));
      }
      return Right(roomId.toString());
    } on DioException catch (e) {
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> syncMessageStatuses(
    List<String> clientMessageIds,
  ) async {
    if (clientMessageIds.isEmpty) return const Right({});
    try {
      debugPrint(
        '[ChatRemoteDataSource] syncStatuses → sending ${clientMessageIds.length} ids',
      );
      final response = await _dio.post(
        '/chat/messages/sync-statuses',
        data: {'clientMessageIds': clientMessageIds},
      );

      final rawData = response.data;
      List<dynamic> rawList;
      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map) {
        final inner = rawData['data'] ?? rawData['statuses'];
        if (inner is List) {
          rawList = inner;
        } else {
          return const Right({});
        }
      } else {
        return const Right({});
      }

      return Right({
        for (final item in rawList)
          if (item is Map &&
              item['clientMessageId'] != null &&
              item['status'] != null)
            item['clientMessageId'].toString(): item['status'].toString(),
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> uploadFile(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });
    try {
      final response = await _dio.post(
        '/chat/upload',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      final raw = response.data;
      final payload = (raw is Map && raw.containsKey('data'))
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      return Right(payload);
    } on DioException catch (e) {
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChatSession>>> fetchRooms() async {
    try {
      final currentUserPhone =
          await _authLocalDataSource.getUserPhone() ?? '';
      final response = await _dio.get('/chat/rooms');

      final raw = response.data;
      final List<dynamic> roomsJson = (raw is List)
          ? raw
          : (raw['data'] ?? raw['rooms'] ?? []);
      debugPrint('[ChatRemoteDataSource] Fetched ${roomsJson.length} room(s)');

      final List<ChatSession> chatSessions = [];
      for (final json in roomsJson) {
        try {
          chatSessions.add(
            ChatSession.fromJson(
              json as Map<String, dynamic>,
              currentUserPhone,
            ),
          );
        } catch (parseError) {
          debugPrint(
            '[ChatRemoteDataSource] Skipped malformed room: $parseError',
          );
        }
      }
      return Right(chatSessions);
    } on DioException catch (e) {
      debugPrint('[ChatRemoteDataSource] fetchRooms failed: $e');
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      debugPrint('[ChatRemoteDataSource] fetchRooms failed: $e');
      return Left(ServerFailure(e.toString()));
    }
  }
}
