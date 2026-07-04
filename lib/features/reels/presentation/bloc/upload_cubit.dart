import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/upload_cancel_token.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';

enum UploadStatus { idle, composing, uploading, success, failure }

/// v3 (FR-060): upload flow state. `picked`/`trimming` (the file-selection
/// and trim steps) live entirely in [UploadReelScreen]/[ReelTrimmerScreen]
/// local state — this cubit only owns the network-facing part (compose →
/// upload → success/failure) once a final ≤60s file is ready to send.
class UploadState extends Equatable {
  const UploadState({
    this.status = UploadStatus.idle,
    this.progress = 0,
    this.errorMessage,
    this.uploadedReel,
  });

  final UploadStatus status;

  /// 0.0–1.0 (bytes sent / total), meaningful only while [status] is
  /// [UploadStatus.uploading].
  final double progress;

  /// Set on [UploadStatus.failure]; the retry action reuses the same file.
  final String? errorMessage;

  final Reel? uploadedReel;

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    Reel? uploadedReel,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      uploadedReel: uploadedReel ?? this.uploadedReel,
    );
  }

  @override
  List<Object?> get props => [status, progress, errorMessage, uploadedReel];
}

/// Owns the network-facing half of the upload flow (FR-060). A failed
/// upload never leaves a phantom reel behind — the backend guarantees this
/// (FR-060), and this cubit surfaces an explicit retryable [UploadState]
/// rather than silently swallowing the error.
@injectable
class UploadCubit extends Cubit<UploadState> {
  UploadCubit(this._repository) : super(const UploadState());

  final ReelsRepository _repository;
  UploadCancelToken? _cancelToken;

  Future<void> upload({
    required String videoPath,
    String? thumbnailPath,
    required String description,
  }) async {
    _cancelToken = UploadCancelToken();
    emit(state.copyWith(status: UploadStatus.uploading, progress: 0));

    final result = await _repository.uploadReel(
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      description: description,
      onSendProgress: (sent, total) {
        if (isClosed || total <= 0) return;
        emit(state.copyWith(status: UploadStatus.uploading, progress: sent / total));
      },
      cancelToken: _cancelToken,
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(status: UploadStatus.failure, errorMessage: failure.message),
      ),
      (reel) => emit(
        state.copyWith(status: UploadStatus.success, uploadedReel: reel, progress: 1),
      ),
    );
  }

  void reset() => emit(const UploadState());

  @override
  Future<void> close() {
    _cancelToken?.cancel();
    return super.close();
  }
}
