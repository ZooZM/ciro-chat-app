import 'dart:async';

import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/features/status/data/models/ai_image_result_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class StatusRemoteDataSource {
  Stream<StatusModel> get onStatusReceived;
  Future<void> uploadStatus(StatusModel status);
  Future<void> notifyViewed(String statusId);
  Future<void> reactToStatus(String statusId, String reaction);
  Future<void> replyToStatus(String statusId, String message);
  Future<AIImageResultModel> generateAIImage(String prompt);
}

@LazySingleton(as: StatusRemoteDataSource)
class StatusRemoteDataSourceImpl implements StatusRemoteDataSource {
  final SocketService socketService;
  final DioClient dioClient;
  final StreamController<StatusModel> _statusStreamController = StreamController.broadcast();

  StatusRemoteDataSourceImpl(this.socketService, this.dioClient) {
    socketService.onStatusReceived = (data) {
      if (data.isNotEmpty) {
        final statusModel = StatusModel.fromMap(data);
        _statusStreamController.add(statusModel);
      }
    };
  }

  @override
  Stream<StatusModel> get onStatusReceived => _statusStreamController.stream;

  @override
  Future<void> uploadStatus(StatusModel status) async {
    if (status.contentType == StatusContentType.video || status.contentType == StatusContentType.image || status.contentType == StatusContentType.voice) {
      if (status.mediaUrl != null && !status.mediaUrl!.startsWith('http')) {
        // Local file, needs multipart upload
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(status.mediaUrl!),
          ...status.toMap(),
        });
        await dioClient.dio.post('/status/upload', data: formData);
        return;
      }
    }
    socketService.uploadStatus(status.toMap());
  }

  @override
  Future<void> notifyViewed(String statusId) async {
    socketService.notifyStatusViewed(statusId);
  }

  @override
  Future<void> reactToStatus(String statusId, String reaction) async {
    await dioClient.dio.post('/status/$statusId/react', data: {'reaction': reaction});
  }

  @override
  Future<void> replyToStatus(String statusId, String message) async {
    await dioClient.dio.post('/status/$statusId/reply', data: {'message': message});
  }

  @override
  Future<AIImageResultModel> generateAIImage(String prompt) async {
    final response = await dioClient.dio.post('/ai/generate-image', data: {'prompt': prompt});
    return AIImageResultModel.fromJson(response.data);
  }
}
