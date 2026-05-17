import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/helpers/permission_service.dart';
import '../../../../core/network/socket_service.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../../data/datasources/gallery_saver_service.dart';
import '../../data/datasources/recording_capture_service.dart';
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
  final bool hasVideo;

  const RecordingActive({
    required this.startedAt,
    required this.callRoomId,
    required this.hasVideo,
  });

  @override
  List<Object?> get props => [startedAt, callRoomId, hasVideo];
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

class RecordingSharing extends CallRecordingState {
  final Recording recording;
  const RecordingSharing(this.recording);

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
  final RecordingCaptureService _captureService;
  final GallerySaverService _gallerySaver;
  final ChatRepository _chatRepository;

  CallRecordingCubit(
    this._repository,
    this._socketService,
    this._captureService,
    this._gallerySaver,
    this._chatRepository,
  ) : super(const RecordingIdle());

  /// FR-032a: starts a screen + audio recording (always video/MP4).
  Future<void> start({
    required String callRoomId,
    required String callRoomName,
  }) async {
    if (state is RecordingActive) return;

    final granted = await PermissionService.requestSingle(Permission.microphone);
    if (!granted) {
      emit(const RecordingFailure('Microphone permission denied'));
      return;
    }

    try {
      final filePath = await _captureService.start();
      if (filePath == null) {
        emit(const RecordingFailure('Failed to start recording'));
        return;
      }

      _socketService.emitGroupCallRecordingStateChanged(
        chatRoomId: callRoomId,
        isRecording: true,
        hasVideo: true,
      );

      emit(RecordingActive(
        startedAt: DateTime.now(),
        callRoomId: callRoomId,
        hasVideo: true,
      ));
    } catch (e) {
      emit(RecordingFailure(e.toString()));
    }
  }

  /// FR-035: stops recording, saves to gallery, uploads, and shares as a
  /// group chat message to all call participants.
  Future<void> stop({String callRoomName = ''}) async {
    final s = state;
    if (s is! RecordingActive) return;

    emit(const RecordingStopping());

    try {
      final filePath = await _captureService.stop();
      if (filePath == null) {
        emit(const RecordingFailure('Recording file not found after stop'));
        return;
      }

      final file = File(filePath);
      final sizeBytes = file.existsSync() ? file.lengthSync() : 0;
      final durationMs = DateTime.now().difference(s.startedAt).inMilliseconds;
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
        hasVideo: s.hasVideo,
        sizeBytes: sizeBytes,
        createdAt: now,
        displayName: displayName,
        shareStatus: ShareStatus.idle,
      );

      _socketService.emitGroupCallRecordingStateChanged(
        chatRoomId: s.callRoomId,
        isRecording: false,
        hasVideo: s.hasVideo,
      );

      final saveResult = await _repository.save(recording);
      final saved = saveResult.fold(
        (f) {
          emit(RecordingFailure(f.message));
          return null;
        },
        (_) => recording,
      );
      if (saved == null) return;

      emit(RecordingSaved(saved));

      // FR-035 pipeline: gallery save → upload → share (non-blocking for UI)
      _runSharePipeline(saved).ignore();
    } catch (e) {
      debugPrint('[CallRecordingCubit] stop error: $e');
      emit(RecordingFailure(e.toString()));
    }
  }

  /// FR-035: gallery → upload → group chat message pipeline.
  Future<void> _runSharePipeline(Recording recording) async {
    // 1. Save to gallery / Downloads
    await _gallerySaver.requestPermission();
    final galleryPath = await _gallerySaver.save(
      recording.filePath,
      hasVideo: recording.hasVideo,
    );
    if (galleryPath != null) {
      await _repository.updateGalleryPath(recording.id, galleryPath);
    }

    // 2. Mark as uploading
    await _repository.updateShareStatus(recording.id, ShareStatus.uploading);

    // 3. Upload file to CDN
    final uploadResult = await _chatRepository.uploadFile(File(recording.filePath));
    await uploadResult.fold(
      (failure) async {
        debugPrint('[CallRecordingCubit] upload failed: ${failure.message}');
        await _repository.updateShareStatus(recording.id, ShareStatus.failed);
      },
      (serverMeta) async {
        final fileUrl = serverMeta['fileUrl'] as String? ?? '';
        if (fileUrl.isEmpty) {
          await _repository.updateShareStatus(recording.id, ShareStatus.failed);
          return;
        }

        // 4. Send as a group chat message — socket sendMessage to room
        final msgId = const Uuid().v4();
        final msgType = recording.hasVideo ? 'video' : 'audio';
        final msgText = recording.hasVideo
            ? '🎬 Call Recording — ${recording.displayName}'
            : '🎙️ Call Recording — ${recording.displayName}';

        _socketService.sendMessage(
          roomId: recording.callRoomId,
          messageId: msgId,
          text: msgText,
          type: msgType,
          fileUrl: fileUrl,
          metadata: {
            'mimeType': recording.hasVideo ? 'video/mp4' : 'audio/m4a',
            'fileName': recording.displayName,
            'fileSize': recording.sizeBytes,
            'durationMs': recording.durationMs,
            'isCallRecording': true,
          },
        );

        await _repository.updateShareStatus(
          recording.id,
          ShareStatus.shared,
          sharedMessageId: msgId,
        );
        debugPrint('[CallRecordingCubit] Recording shared as message $msgId');
      },
    );
  }

  /// T106: Retry the share pipeline for a recording that previously failed.
  Future<void> retryShare(Recording recording) async {
    if (recording.shareStatus != ShareStatus.failed) return;
    await _runSharePipeline(recording);
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
      await _captureService.stop();
    }
    await _captureService.dispose();
    return super.close();
  }
}
