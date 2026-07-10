import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/capture_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/reel_trimmer_screen.dart';
import 'package:ciro_chat_app/features/reels/presentation/services/reel_video_export.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/capture_duration_selector.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/record_button.dart';

/// v5 (FR-079/FR-080): the camera-first entry point for reel creation —
/// replaces the earlier source-choice screen. Full-screen live preview, a
/// red record toggle (single continuous clip), a gallery thumbnail, flip +
/// flash only, and the Video | 15s | 30s | 60s duration selector. Every captured
/// or picked source proceeds straight to the trimmer (FR-081), then the
/// post-details step; the final posted [Reel] (or `null` if the flow was
/// abandoned) bubbles back to whoever pushed this screen.
class ReelCaptureScreen extends StatelessWidget {
  const ReelCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CaptureCubit>(),
      child: const _ReelCaptureView(),
    );
  }
}

class _ReelCaptureView extends StatefulWidget {
  const _ReelCaptureView();

  @override
  State<_ReelCaptureView> createState() => _ReelCaptureViewState();
}

/// Stopping a platform recording within the first few hundred ms — before the
/// encoder has a valid segment — crashes the `camera` plugin on both iOS and
/// Android. We never call `stopVideoRecording()` until at least this long has
/// elapsed since it started. Kept below the cubit's 1s "too short" discard
/// threshold so a padded quick tap still discards rather than being posted.
const _minSafeRecordMs = 800;

class _ReelCaptureViewState extends State<_ReelCaptureView> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _flashOn = false;
  bool _pickingGallery = false;

  // Serializes the record button: a start or stop platform call is in flight.
  // Prevents a second tap during the async start window from calling
  // `startVideoRecording()` twice (B1).
  bool _recordBusy = false;
  // Optimistic "recording" visual from the moment of tap until the platform
  // `startVideoRecording()` resolves, so the button never appears frozen while
  // the (100–500 ms) platform call runs (B1).
  bool _starting = false;
  // Wall-clock instant the platform recorder actually started (B2 stop pad).
  DateTime? _recordStartedAt;
  // Guards the capture -> trimmer -> post chain against a double entry (e.g.
  // the `captured` listener firing while a flow is already navigating) (B3).
  bool _inCreationFlow = false;

  CaptureCubit get _cubit => context.read<CaptureCubit>();

  bool get _isFrontCamera =>
      _cameras.isNotEmpty && _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final granted = await _cubit.requestPermissions();
    if (!granted || !mounted) return;
    await _initializeCamera();
  }

  Future<void> _initializeCamera({int? preferredIndex}) async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint('[ReelCaptureScreen] availableCameras failed: $e');
      return;
    }
    if (_cameras.isEmpty) return;
    var index = preferredIndex ?? _cameraIndex;
    if (index >= _cameras.length) index = 0;

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await controller.initialize();
    } catch (e) {
      debugPrint('[ReelCaptureScreen] camera initialize failed: $e');
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    final previous = _cameraController;
    setState(() {
      _cameraController = controller;
      _cameraIndex = index;
      _flashOn = false;
    });
    await previous?.dispose();
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _cubit.state.isRecording) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera(preferredIndex: nextIndex);
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || _isFrontCamera) return;
    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _flashOn = next);
    } catch (e) {
      debugPrint('[ReelCaptureScreen] setFlashMode failed: $e');
    }
  }

  Future<void> _handleRecordTap() async {
    // B1: ignore taps while a start/stop platform call is already in flight —
    // otherwise a second tap during the async start window calls the platform
    // twice and crashes.
    if (_recordBusy) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final wasRecording = _cubit.state.isRecording;
    _recordBusy = true;
    // B1: flip to the recording visual immediately so the button doesn't look
    // frozen while `startVideoRecording()` runs.
    if (!wasRecording) setState(() => _starting = true);
    try {
      if (wasRecording) {
        await _stopRecording();
      } else {
        await controller.startVideoRecording();
        _recordStartedAt = DateTime.now();
        if (mounted) {
          _cubit.startRecording(onCapReached: () => unawaited(_stopRecording()));
        }
      }
    } catch (e) {
      debugPrint('[ReelCaptureScreen] record tap failed: $e');
    } finally {
      _recordBusy = false;
      if (mounted) {
        setState(() => _starting = false);
      } else {
        _starting = false;
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;
    // B2: never call stopVideoRecording() before the platform recorder has a
    // valid segment — stopping within the first few hundred ms crashes the
    // plugin. Pad a too-early stop up to the safe minimum; the cubit still
    // discards it as "too short" (the pad stays under the 1s threshold).
    final startedAt = _recordStartedAt;
    if (startedAt != null) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final remainingMs = _minSafeRecordMs - elapsedMs;
      if (remainingMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: remainingMs));
      }
    }
    if (!mounted) return;
    // Re-check after the pad — the cap auto-stop may have already stopped it.
    if (!controller.value.isRecordingVideo) return;
    String? path;
    try {
      final file = await controller.stopVideoRecording();
      path = file.path;
    } catch (e) {
      debugPrint('[ReelCaptureScreen] stopVideoRecording failed: $e');
    }
    if (!mounted) return;
    _cubit.stopRecording(path);
  }

  Future<void> _pickFromGallery() async {
    if (_cubit.state.isRecording || _pickingGallery) return;
    setState(() => _pickingGallery = true);
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      await _proceedToTrimmer(File(picked.path), const Duration(seconds: 60));
    } catch (e) {
      debugPrint('[ReelCaptureScreen] gallery pick failed: $e');
    } finally {
      if (mounted) setState(() => _pickingGallery = false);
    }
  }

  /// FR-081/binding rule 14: safe-copy → trimmer ("Next") → post-details →
  /// bubble the final [Reel] (or `null`) back to this screen's caller.
  ///
  /// B3: the trimmer pushes the post-details screen on top of *itself* (rather
  /// than popping back here first and re-showing the live camera between the
  /// two), and returns the posted [Reel] — so the forward transition never
  /// flashes the camera screen. The unwind (post → trimmer → camera → profile)
  /// is a chain of synchronous pops, so no intermediate screen renders either.
  Future<void> _proceedToTrimmer(File source, Duration maxDuration) async {
    if (_inCreationFlow) return;
    _inCreationFlow = true;
    try {
      final safeFile = await ReelVideoExport.copyToSafePath(source);
      if (!mounted) return;
      final reel = await Navigator.of(context).push<Reel?>(
        MaterialPageRoute(
          builder: (_) => ReelTrimmerScreen(sourceFile: safeFile, maxDuration: maxDuration),
        ),
      );
      if (!mounted) return;
      await ReelVideoExport.purgeReelsTmp();
      if (!mounted) return;
      if (reel != null) {
        Navigator.of(context).pop<Reel?>(reel);
      } else {
        _cubit.reset();
      }
    } finally {
      _inCreationFlow = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_handleLifecycleChange(state));
  }

  Future<void> _handleLifecycleChange(AppLifecycleState state) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Binding rule 13: an in-progress recording must stop safely (never
      // silently keep recording in the background) before we tear the
      // controller down; `_stopRecording` routes through the cubit's
      // existing ≥1s/<1s split, same as a manual tap-to-stop.
      if (controller.value.isRecordingVideo) {
        await _stopRecording();
      }
      await controller.dispose();
      if (mounted) setState(() => _cameraController = null);
    } else if (state == AppLifecycleState.resumed && _cameraController == null) {
      await _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MultiBlocListener(
        listeners: [
          BlocListener<CaptureCubit, CaptureState>(
            listenWhen: (prev, curr) => curr.discardCount != prev.discardCount,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('reels.capture_too_short'.tr())),
              );
            },
          ),
          BlocListener<CaptureCubit, CaptureState>(
            listenWhen: (prev, curr) =>
                curr.status == CaptureStatus.captured && curr.videoPath != null,
            listener: (context, state) {
              _proceedToTrimmer(File(state.videoPath!), state.cap);
            },
          ),
        ],
        child: BlocBuilder<CaptureCubit, CaptureState>(
          builder: (context, state) {
            if (state.status == CaptureStatus.permissionDenied) {
              return _PermissionDeniedView(onOpenSettings: openAppSettings, onRetry: _bootstrap);
            }
            return SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: _CameraPreviewOrLoading(controller: _cameraController)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (_cameras.length > 1)
                          _TopIconButton(icon: Icons.cameraswitch, onTap: _flipCamera),
                        if (!_isFrontCamera)
                          _TopIconButton(
                            icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                            onTap: _toggleFlash,
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CaptureDurationSelector(
                          cap: state.cap,
                          enabled: !state.isRecording,
                          onCapSelected: _cubit.setCap,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RecordButton(
                                isRecording: state.isRecording || _starting,
                                progress: state.cap.inMilliseconds == 0
                                    ? 0
                                    : state.elapsed.inMilliseconds / state.cap.inMilliseconds,
                                onTap: _handleRecordTap,
                              ),
                              Positioned(
                                left: 24,
                                child: _GalleryThumbnailButton(
                                  enabled: !state.isRecording && !_pickingGallery,
                                  onTap: _pickFromGallery,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CameraPreviewOrLoading extends StatelessWidget {
  const _CameraPreviewOrLoading({required this.controller});

  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, shadows: const [
        Shadow(blurRadius: 6, color: Colors.black54),
      ]),
    );
  }
}

class _GalleryThumbnailButton extends StatelessWidget {
  const _GalleryThumbnailButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
            color: Colors.white24,
          ),
          child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onOpenSettings, required this.onRetry});

  final Future<bool> Function() onOpenSettings;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              'reels.capture_permission_title'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'reels.capture_permission_body'.tr(),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onOpenSettings,
              child: Text('reels.capture_permission_open_settings'.tr()),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
