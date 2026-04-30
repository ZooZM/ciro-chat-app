import 'dart:async';

import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:injectable/injectable.dart';

abstract class StatusRemoteDataSource {
  Stream<StatusModel> get onStatusReceived;
  Future<void> uploadStatus(StatusModel status);
  Future<void> notifyViewed(String statusId);
}

@LazySingleton(as: StatusRemoteDataSource)
class StatusRemoteDataSourceImpl implements StatusRemoteDataSource {
  final SocketService socketService;
  final StreamController<StatusModel> _statusStreamController = StreamController.broadcast();

  StatusRemoteDataSourceImpl(this.socketService) {
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
    socketService.uploadStatus(status.toMap());
  }

  @override
  Future<void> notifyViewed(String statusId) async {
    socketService.notifyStatusViewed(statusId);
  }
}
