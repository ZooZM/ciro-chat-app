import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ciro_chat_app/core/helpers/permission_service.dart';

enum CaptureStatus { idle, recording, captured, permissionDenied }

/// v5 (FR-079/FR-080): camera-first capture state. This cubit owns only the
/// recording status/elapsed/cap/permission state machine — the actual
/// `CameraController` (a rendering resource, like `VideoEditorController` in
/// [ReelTrimmerScreen]) lives in the capture screen's `State`, which drives
/// this cubit via [startRecording]/[stopRecording] and reads [elapsed]/[cap]
/// to render the progress ring.
class CaptureState extends Equatable {
  const CaptureState({
    this.status = CaptureStatus.idle,
    this.elapsed = Duration.zero,
    this.cap = const Duration(seconds: 60),
    this.videoPath,
    this.discardCount = 0,
  });

  final CaptureStatus status;
  final Duration elapsed;
  final Duration cap;
  final String? videoPath;

  /// Incremented every time a sub-1s take is discarded (FR-080) — a nonce so
  /// `BlocListener`'s `listenWhen` can fire the "too short" notice exactly
  /// once per discard without depending on wall-clock time.
  final int discardCount;

  bool get isRecording => status == CaptureStatus.recording;

  CaptureState copyWith({
    CaptureStatus? status,
    Duration? elapsed,
    Duration? cap,
    String? videoPath,
    bool clearVideoPath = false,
    int? discardCount,
  }) {
    return CaptureState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      cap: cap ?? this.cap,
      videoPath: clearVideoPath ? null : (videoPath ?? this.videoPath),
      discardCount: discardCount ?? this.discardCount,
    );
  }

  @override
  List<Object?> get props => [status, elapsed, cap, videoPath, discardCount];
}

const _minRecordingDuration = Duration(seconds: 1);
const _tick = Duration(milliseconds: 100);

/// Drives the FR-079/FR-080 capture lifecycle: a single continuous clip
/// (no pause/resume segments, clarified), auto-stopped at the selected
/// 15s/30s/60s cap, with sub-1s takes discarded rather than proceeding to the
/// trimmer (binding rule 13).
@injectable
class CaptureCubit extends Cubit<CaptureState> {
  CaptureCubit({
    @ignoreParam Future<bool> Function()? requestCameraPermission,
    @ignoreParam Future<bool> Function()? requestMicrophonePermission,
  })  : _requestCameraPermission =
            requestCameraPermission ?? _defaultRequestCameraPermission,
        _requestMicrophonePermission =
            requestMicrophonePermission ?? _defaultRequestMicrophonePermission,
        super(const CaptureState());

  final Future<bool> Function() _requestCameraPermission;
  final Future<bool> Function() _requestMicrophonePermission;
  Timer? _ticker;
  VoidCallback? _onCapReached;

  static Future<bool> _defaultRequestCameraPermission() =>
      PermissionService.requestSingle(Permission.camera);
  static Future<bool> _defaultRequestMicrophonePermission() =>
      PermissionService.requestSingle(Permission.microphone);

  /// FR-079: pre-flight check before the camera preview renders. Returns
  /// `true` iff both camera and microphone are granted.
  Future<bool> requestPermissions() async {
    final cameraGranted = await _requestCameraPermission();
    final micGranted = cameraGranted ? await _requestMicrophonePermission() : false;
    if (!cameraGranted || !micGranted) {
      emit(state.copyWith(status: CaptureStatus.permissionDenied));
      return false;
    }
    if (state.status == CaptureStatus.permissionDenied) {
      emit(state.copyWith(status: CaptureStatus.idle));
    }
    return true;
  }

  /// FR-080: the Video | 15s | 30s | 60s selector — a no-op while recording.
  void setCap(Duration cap) {
    if (state.isRecording) return;
    emit(state.copyWith(cap: cap));
  }

  /// Called by the capture screen immediately after
  /// `CameraController.startVideoRecording()` succeeds. [onCapReached] is
  /// invoked exactly once, when the elapsed time reaches [CaptureState.cap]
  /// — the screen must call `stopRecording` (via its own controller stop)
  /// in response, mirroring a manual tap-to-stop.
  void startRecording({required VoidCallback onCapReached}) {
    _onCapReached = onCapReached;
    _ticker?.cancel();
    emit(state.copyWith(status: CaptureStatus.recording, elapsed: Duration.zero));
    _ticker = Timer.periodic(_tick, (_) {
      final elapsed = state.elapsed + _tick;
      if (elapsed >= state.cap) {
        _ticker?.cancel();
        _ticker = null;
        emit(state.copyWith(elapsed: state.cap));
        _onCapReached?.call();
        return;
      }
      emit(state.copyWith(elapsed: elapsed));
    });
  }

  /// Called once the platform recording has actually stopped — either a
  /// manual tap or the [startRecording] cap callback. [path] is the captured
  /// file, or `null` if the platform stop itself failed (e.g. an app-paused
  /// interruption before recording could even start meaningfully).
  ///
  /// Idempotent: a manual stop tap and the cap auto-stop can race, and both
  /// route here — only the first (while still `recording`) takes effect, so a
  /// late second call can never overwrite a `captured` clip with a discard.
  void stopRecording(String? path) {
    if (state.status != CaptureStatus.recording) return;
    _ticker?.cancel();
    _ticker = null;
    final tooShort = state.elapsed < _minRecordingDuration;
    if (path == null || tooShort) {
      emit(state.copyWith(
        status: CaptureStatus.idle,
        elapsed: Duration.zero,
        clearVideoPath: true,
        discardCount: state.discardCount + 1,
      ));
      return;
    }
    emit(state.copyWith(status: CaptureStatus.captured, videoPath: path));
  }

  /// Back-out from the trimmer, or any other reset to the idle capture
  /// screen (FR-081 discard-confirmation path).
  void reset() {
    _ticker?.cancel();
    _ticker = null;
    emit(state.copyWith(
      status: CaptureStatus.idle,
      elapsed: Duration.zero,
      clearVideoPath: true,
    ));
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
