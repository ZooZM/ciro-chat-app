import 'dart:async';
import 'dart:convert';

import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/status/data/models/ai_image_result_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_audience_contact_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_reaction_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_viewer_model.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_reaction.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_viewer.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class StatusRemoteDataSource {
  Stream<StatusModel> get onStatusReceived;
  Stream<Map<String, dynamic>> get onStatusUploaded;

  /// Fired when someone views one of OUR statuses.
  Stream<({String statusId, StatusViewer viewer})> get onStatusViewerAdded;

  /// Fired when someone reacts to one of OUR statuses.
  Stream<({String statusId, StatusReaction reaction})> get onStatusReacted;

  /// Returns the server-confirmed status JSON for media uploads (synchronous REST ACK),
  /// or `null` for text statuses (ACK arrives later via [onStatusUploaded]).
  Future<Map<String, dynamic>?> uploadStatus(StatusModel status);
  Future<void> notifyViewed(String statusId);
  Future<void> react(String statusId, String reaction);

  /// Returns the server-created chat [Message] JSON (with `statusRef`) so the
  /// caller can insert it into the existing chat history (FR-018).
  Future<Map<String, dynamic>> reply(String statusId, String message);
  Future<AIImageResultModel> generateAIImage(String prompt);
  Future<List<StatusModel>> getFeed();
  Future<List<StatusViewerModel>> getViewers(String statusId);
  Future<List<StatusAudienceContactModel>> getDefaultAudience();
}

@LazySingleton(as: StatusRemoteDataSource)
class StatusRemoteDataSourceImpl implements StatusRemoteDataSource {
  final SocketService socketService;
  final DioClient dioClient;
  final StreamController<StatusModel> _statusStreamController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _statusUploadedController = StreamController.broadcast();
  final StreamController<({String statusId, StatusViewer viewer})> _viewerAddedController =
      StreamController.broadcast();
  final StreamController<({String statusId, StatusReaction reaction})> _reactedController =
      StreamController.broadcast();

  StatusRemoteDataSourceImpl(this.socketService, this.dioClient) {
    socketService.onStatusReceived = (data) {
      if (data.isEmpty) return;
      final resolved = Map<String, dynamic>.from(data);
      final rawMediaUrl = resolved['mediaUrl'] as String?;
      resolved['mediaUrl'] = (rawMediaUrl == null || rawMediaUrl.isEmpty)
          ? null
          : UrlUtils.resolveMediaUrl(rawMediaUrl);
      _statusStreamController.add(StatusModel.fromJson(resolved));
    };
    socketService.onStatusUploaded = (data) {
      if (data.isEmpty) return;
      _statusUploadedController.add(data);
    };
    socketService.onStatusViewerAdded = (data) {
      final statusId = data['statusId']?.toString();
      final viewer = data['viewer'];
      if (statusId == null || viewer is! Map) return;
      _viewerAddedController.add((
        statusId: statusId,
        viewer: StatusViewerModel.fromJson({
          ...Map<String, dynamic>.from(viewer),
          'viewedAt': data['viewedAt'],
        }),
      ));
    };
    socketService.onStatusReacted = (data) {
      final statusId = data['statusId']?.toString();
      final from = data['from'];
      if (statusId == null || from is! Map) return;
      _reactedController.add((
        statusId: statusId,
        reaction: StatusReactionModel.fromJson({
          'userId': Map<String, dynamic>.from(from)['userId'],
          'reaction': data['reaction'],
          'createdAt': data['createdAt'],
        }),
      ));
    };
  }

  @override
  Stream<StatusModel> get onStatusReceived => _statusStreamController.stream;

  @override
  Stream<Map<String, dynamic>> get onStatusUploaded => _statusUploadedController.stream;

  @override
  Stream<({String statusId, StatusViewer viewer})> get onStatusViewerAdded =>
      _viewerAddedController.stream;

  @override
  Stream<({String statusId, StatusReaction reaction})> get onStatusReacted =>
      _reactedController.stream;

  @override
  Future<Map<String, dynamic>?> uploadStatus(StatusModel status) async {
    final isMedia = status.contentType == StatusContentType.image ||
        status.contentType == StatusContentType.video ||
        status.contentType == StatusContentType.voice;

    if (isMedia) {
      final fields = <String, dynamic>{
        'clientStatusId': status.clientStatusId,
        'contentType': status.contentType.name,
        'privacy': status.privacy.name,
        if (status.backgroundColor != null) 'backgroundColor': status.backgroundColor!,
        if (status.fontStyle != null) 'fontStyle': status.fontStyle!,
        if (status.musicTrackId != null) 'musicTrackId': status.musicTrackId!,
        if (status.caption != null) 'caption': status.caption!,
        if (status.privacy == StatusPrivacy.private) 'audience': jsonEncode(status.audience),
      };
      final formData = FormData.fromMap({
        ...fields,
        'file': await MultipartFile.fromFile(status.mediaUrl!),
      });
      final response = await dioClient.dio.post('/status/upload', data: formData);
      return Map<String, dynamic>.from(response.data as Map);
    }

    socketService.uploadStatus({
      'clientStatusId': status.clientStatusId,
      'contentType': status.contentType.name,
      'textContent': status.textContent,
      'privacy': status.privacy.name,
      if (status.privacy == StatusPrivacy.private) 'audience': status.audience,
    });
    return null;
  }

  @override
  Future<void> notifyViewed(String statusId) async {
    socketService.notifyStatusViewed(statusId);
  }

  @override
  Future<void> react(String statusId, String reaction) async {
    await dioClient.dio.post('/status/$statusId/react', data: {'reaction': reaction});
  }

  @override
  Future<Map<String, dynamic>> reply(String statusId, String message) async {
    final response = await dioClient.dio.post('/status/$statusId/reply', data: {'message': message});
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<AIImageResultModel> generateAIImage(String prompt) async {
    final response = await dioClient.dio.post('/ai/generate-image', data: {'prompt': prompt});
    return AIImageResultModel.fromJson(response.data);
  }

  @override
  Future<List<StatusModel>> getFeed() async {
    final response = await dioClient.dio.get('/status/feed');
    final data = response.data as List<dynamic>;
    return data.map((e) {
      final json = Map<String, dynamic>.from(e as Map<String, dynamic>);
      final rawMediaUrl = json['mediaUrl'] as String?;
      json['mediaUrl'] = (rawMediaUrl == null || rawMediaUrl.isEmpty)
          ? null
          : UrlUtils.resolveMediaUrl(rawMediaUrl);
      return StatusModel.fromJson(json);
    }).toList();
  }

  @override
  Future<List<StatusViewerModel>> getViewers(String statusId) async {
    final response = await dioClient.dio.get('/status/$statusId/viewers');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => StatusViewerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<StatusAudienceContactModel>> getDefaultAudience() async {
    final response = await dioClient.dio.get('/status/audience/default');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => StatusAudienceContactModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
