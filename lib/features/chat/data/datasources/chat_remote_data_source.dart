import 'dart:async';
import 'package:dio/dio.dart'; // Import Dio
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/core/error/failures.dart'; // Assuming Failure types are needed for API calls
import 'package:fpdart/fpdart.dart'; // Assuming Either is used for API call results
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';

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

  // New group chat API endpoints
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
  final FlutterSecureStorage _secureStorage;
  final Dio _dio; // Add Dio dependency
  IO.Socket? _socket;
  final _messageController = StreamController<Message>.broadcast();

  ChatRemoteDataSourceImpl(this._secureStorage, this._dio); // Initialize Dio

  @override
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _secureStorage.read(key: 'accessToken');

    _socket = IO.io(
      'http://localhost:3000',
      IO.OptionBuilder().setTransports(['websocket']).setExtraHeaders({
        'Authorization': 'Bearer $token',
      }).build(),
    );

    _socket!.onConnect((_) {
      // You can add logic here if needed handling successful connection
    });

    _socket!.on('receive_message', (data) {
      if (data is Map<String, dynamic>) {
        final message = Message(
          id: data['id']?.toString() ?? '',
          clientMessageId:
              data['clientMessageId']?.toString() ??
              data['id']?.toString() ??
              '',
          roomId: data['roomId']?.toString() ?? 'unknown',
          senderId: data['senderId']?.toString() ?? '',
          text: data['content']?.toString() ?? '',
          timestamp: data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'].toString()) ??
                    DateTime.now()
              : DateTime.now(),
        );
        _messageController.add(message);
      }
    });

    _socket!.onDisconnect((_) {
      // Handle socket disconnect
    });
  }

  @override
  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  @override
  void sendMessage(String text) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_message', {'text': text});
    }
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;

  // ── Group Chat API Endpoints ────────────────────────────────────────────────

  String _apiUrl(String path) => 'http://localhost:3000/api/v1/chat$path';

  Future<Options> _getAuthOptions() async {
    final token = await _secureStorage.read(key: 'accessToken');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createGroup(
    String groupName,
    List<String> participants,
    String? avatarUrl,
  ) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        _apiUrl('/group/create'),
        data: {
          'name': groupName,
          'participants': participants,
          'avatarUrl': avatarUrl,
        },
        options: options,
      );
      if (response.statusCode == 201) {
        return Right(response.data as Map<String, dynamic>);
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
      final options = await _getAuthOptions();
      final response = await _dio.post(
        _apiUrl('/group/$roomId/add'),
        data: {'participants': participants},
        options: options,
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
      final options = await _getAuthOptions();
      final response = await _dio.delete(
        _apiUrl('/group/$roomId/remove'),
        data: {'participantId': participantId},
        options: options,
      );
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
      final options = await _getAuthOptions();
      final response = await _dio.post(
        _apiUrl('/group/$roomId/leave'),
        options: options,
      );
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

  // ── Private Chat API Endpoints (Moved from ChatApiService) ──────────────────

  @override
  Future<Either<Failure, String>> createPrivateChatRoom(
    String targetUserId,
  ) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        _apiUrl('/private/resolve'),
        data: {'userId': targetUserId},
        options: options,
      );
      final data = response.data['data'] ?? response.data;
      final roomId = data['roomId'] ?? data['_id'] ?? data['id'];
      if (roomId == null) {
        return Left(ServerFailure('Backend returned no roomId'));
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
      final options = await _getAuthOptions();
      final response = await _dio.post(
        _apiUrl('/messages/sync-statuses'),
        data: {'clientMessageIds': clientMessageIds},
        options: options,
      );

      final rawData = response.data;
      debugPrint(
        '[ChatRemoteDataSource] syncStatuses ← type: ${rawData.runtimeType}, body: $rawData',
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
            '[ChatRemoteDataSource] syncStatuses: unexpected map. Keys: ${rawData.keys.toList()}',
          );
          return const Right({});
        }
      } else {
        debugPrint(
          '[ChatRemoteDataSource] syncStatuses: unexpected type ${rawData.runtimeType}',
        );
        return const Right({});
      }

      debugPrint(
        '[ChatRemoteDataSource] syncStatuses: parsed ${rawList.length} update(s)',
      );

      return Right({
        for (final item in rawList)
          if (item is Map &&
              item['clientMessageId'] != null &&
              item['status'] != null)
            item['clientMessageId'].toString(): item['status'].toString(),
      });
    } on DioException catch (e, st) {
      debugPrint('[ChatRemoteDataSource] syncMessageStatuses failed: $e $st');
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e, st) {
      debugPrint('[ChatRemoteDataSource] syncMessageStatuses failed: $e $st');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> uploadFile(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });
    debugPrint('[ChatRemoteDataSource] Uploading file: $fileName');
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        _apiUrl('/upload'),
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Authorization': options.headers!['Authorization'],
          },
        ),
      );
      final raw = response.data;
      final payload = (raw is Map && raw.containsKey('data'))
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      debugPrint(
        '[ChatRemoteDataSource] Upload success: ${payload['fileUrl']}',
      );
      return Right(payload);
    } on DioException catch (e) {
      debugPrint('[ChatRemoteDataSource] Upload failed: $e');
      if (e.response != null) {
        return Left(
          ServerFailure(
            e.response?.data['message'] ?? e.message ?? 'Server error',
          ),
        );
      }
      return Left(NetworkFailure(e.message ?? 'Network error'));
    } catch (e) {
      debugPrint('[ChatRemoteDataSource] Upload failed: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChatSession>>> fetchRooms() async {
    try {
      final currentUserPhone =
          await _secureStorage.read(key: 'userPhone') ?? '';
      final options = await _getAuthOptions();
      final response = await _dio.get(_apiUrl('/rooms'), options: options);

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
