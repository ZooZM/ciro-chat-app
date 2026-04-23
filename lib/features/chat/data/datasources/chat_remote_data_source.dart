import 'dart:async';
import 'package:dio/dio.dart'; // Import Dio
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/core/error/failures.dart'; // Assuming Failure types are needed for API calls
import 'package:fpdart/fpdart.dart'; // Assuming Either is used for API call results

abstract class ChatRemoteDataSource {
  Future<void> connect();
  Future<void> disconnect();
  void sendMessage(String text);
  Stream<Message> get messageStream;

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
          text: data['text']?.toString() ?? '',
          timestamp: data['timestamp'] != null
              ? DateTime.tryParse(data['timestamp'].toString()) ??
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
}
