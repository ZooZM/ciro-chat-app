import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/socket_service.dart';
import '../../domain/entities/recording.dart';
import '../../domain/repositories/recordings_repository.dart';

// ── States ────────────────────────────────────────────────────────────────────

abstract class CallRecordingState extends Equatable {
  const CallRecordingState();
  @override
  List<Object?> get props => [];
}

class RecordingIdle extends CallRecordingState {
  const RecordingIdle();
}

class RecordingActive extends CallRecordingState {
  final DateTime startedAt;
  final String callRoomId;

  const RecordingActive({required this.startedAt, required this.callRoomId});

  @override
  List<Object?> get props => [startedAt, callRoomId];
}

class RecordingStopping extends CallRecordingState {
  const RecordingStopping();
}

class RecordingSaved extends CallRecordingState {
  final Recording recording;
  const RecordingSaved(this.recording);

  @override
  List<Object?> get props => [recording];
}

class RecordingFailure extends CallRecordingState {
  final String message;
  const RecordingFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

@lazySingleton
class CallRecordingCubit extends Cubit<CallRecordingState> {
  final RecordingsRepository _repository;
  final SocketService _socketService;
  final AudioRecorder _recorder;

  CallRecordingCubit(this._repository, this._socketService)
      : _recorder = AudioRecorder(),
        super(const RecordingIdle());

  Future<void> start({
    required String callRoomId,
    required String callRoomName,
  }) async {
    if (state is RecordingActive) return;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      emit(const RecordingFailure('Microphone permission denied'));
      return;
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recDir = Directory('${docsDir.path}/recordings');
      if (!recDir.existsSync()) recDir.createSync(recursive: true);

      final filePath = '${recDir.path}/${const Uuid().v4()}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: filePath,
      );

      _socketService.emitGroupCallRecordingStateChanged(
        chatRoomId: callRoomId,
        isRecording: true,
      );

      emit(RecordingActive(startedAt: DateTime.now(), callRoomId: callRoomId));
    } catch (e) {
      emit(RecordingFailure(e.toString()));
    }
  }

  Future<void> stop({String callRoomName = ''}) async {
    final s = state;
    if (s is! RecordingActive) return;

    emit(const RecordingStopping());

    try {
      final filePath = await _recorder.stop();
      if (filePath == null) {
        emit(const RecordingFailure('Recording file not found after stop'));
        return;
      }

      final file = File(filePath);
      final sizeBytes = file.existsSync() ? file.lengthSync() : 0;
      final durationMs =
          DateTime.now().difference(s.startedAt).inMilliseconds;
      final now = DateTime.now();
      final displayName =
          '${callRoomName.isNotEmpty ? callRoomName : 'Group Call'} — '
          '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
          '${_pad(now.hour)}:${_pad(now.minute)}';

      final recording = Recording(
        id: const Uuid().v4(),
        callRoomId: s.callRoomId,
        callRoomName: callRoomName,
        filePath: filePath,
        durationMs: durationMs,
        hasVideo: false,
        sizeBytes: sizeBytes,
        createdAt: now,
        displayName: displayName,
      );

      _socketService.emitGroupCallRecordingStateChanged(
        chatRoomId: s.callRoomId,
        isRecording: false,
      );

      final result = await _repository.save(recording);
      result.fold(
        (failure) => emit(RecordingFailure(failure.message)),
        (_) => emit(RecordingSaved(recording)),
      );
    } catch (e) {
      debugPrint('[CallRecordingCubit] stop error: $e');
      emit(RecordingFailure(e.toString()));
    }
  }

  Future<List<Recording>> listRecordings() async {
    final result = await _repository.list();
    return result.fold((_) => [], (list) => list);
  }

  Future<void> deleteRecording(String id) async {
    await _repository.delete(id);
  }

  Future<void> renameRecording(String id, String newName) async {
    await _repository.rename(id, newName);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Future<void> close() async {
    if (state is RecordingActive) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    return super.close();
  }
}
