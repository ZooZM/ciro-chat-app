import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/upload_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/reel_trimmer_screen.dart';
import 'package:ciro_chat_app/features/reels/presentation/services/reel_video_export.dart';

const _maxUploadDuration = Duration(seconds: 60);

/// v3 (FR-060): the reel upload flow — record or pick a video, trim it if
/// it's longer than 60s (FR-060a), add a description, submit. A failed
/// upload never leaves a phantom reel (FR-060) — this screen surfaces an
/// explicit retry instead.
class UploadReelScreen extends StatelessWidget {
  const UploadReelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<UploadCubit>(),
      child: const _UploadReelView(),
    );
  }
}

class _UploadReelView extends StatefulWidget {
  const _UploadReelView();

  @override
  State<_UploadReelView> createState() => _UploadReelViewState();
}

class _UploadReelViewState extends State<_UploadReelView> {
  final _descriptionController = TextEditingController();
  File? _videoFile;
  String? _thumbnailPath;
  bool _preparingSource = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<Duration?> _probeDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      return controller.value.duration;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  /// `video_editor` 3.0.0 runs `Uri.encodeFull(path)` on iOS when it builds its
  /// internal `VideoPlayerController` (src/controller.dart), so any space or
  /// special char in the picked filename (e.g. "Screen Recording ….mov") becomes
  /// `%20` and the player fails to load a now-nonexistent path (OSStatus -17913).
  /// Copy the source to a space-free name first so that encoding is a no-op.
  Future<File> _copyToSafePath(File source) async {
    final lastDot = source.path.lastIndexOf('.');
    final ext = lastDot != -1 ? source.path.substring(lastDot + 1) : 'mp4';
    final safeName = 'reel_src_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final dest = '${source.parent.path}/$safeName';
    return source.copy(dest);
  }

  /// Best-effort — a thumbnail is optional (FR-060); a failure here (e.g. a
  /// codec `video_thumbnail` can't decode) must never block the user from
  /// reaching the compose screen with their picked video.
  Future<String?> _tryGenerateThumbnail(String videoPath) async {
    try {
      return await vt.VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: vt.ImageFormat.JPEG,
        quality: 80,
      );
    } catch (e) {
      debugPrint('[UploadReelScreen] thumbnail generation failed: $e');
      return null;
    }
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _preparingSource = true);
    try {
      final XFile? picked;
      try {
        picked = source == ImageSource.camera
            ? await ImagePicker().pickVideo(source: source, maxDuration: _maxUploadDuration)
            : await ImagePicker().pickVideo(source: source);
      } catch (e) {
        debugPrint('[UploadReelScreen] pickVideo failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }
      if (picked == null) return; // user cancelled the picker
      final file = File(picked.path);

      // Camera capture is already capped by maxDuration natively, but the
      // OS applies no such limit to a gallery pick — probe either way so a
      // pre-trimmed camera capture still gets its thumbnail below.
      final duration = await _probeDuration(file);

      if (duration != null && duration > _maxUploadDuration) {
        // video_editor 3.0.0 runs Uri.encodeFull() on the path on iOS, which
        // turns spaces in a picked filename (e.g. "Screen Recording ….mov")
        // into %20 and makes its player fail to load (OSStatus -17913). Hand
        // it a copy at a sanitized, space-free path so that encoding is a no-op.
        final safeFile = await _copyToSafePath(file);
        if (!mounted) return;
        final result = await Navigator.of(context).push<TrimResult?>(
          MaterialPageRoute(builder: (_) => ReelTrimmerScreen(sourceFile: safeFile)),
        );
        if (result == null) return;
        setState(() {
          _videoFile = File(result.videoPath);
          _thumbnailPath = result.thumbnailPath;
        });
        return;
      }

      // FR-060: normalize *every* upload — not just >60s trims — through the
      // same ffmpeg re-encode, so the moov atom is moved to the front
      // (+faststart) and the resolution/bitrate is capped. Skipping this for
      // ≤60s clips is what made a large raw upload stutter on its first
      // playback. Falls back to the raw file if the re-encode fails; the
      // backend post-upload remux still guarantees faststart in that case.
      final normalizedPath = await ReelVideoExport.normalizeFullClip(file);
      final videoPath = normalizedPath ?? file.path;
      final thumbnailPath = await _tryGenerateThumbnail(videoPath);
      if (!mounted) return;
      setState(() {
        _videoFile = File(videoPath);
        _thumbnailPath = thumbnailPath;
      });
    } catch (e) {
      debugPrint('[UploadReelScreen] pick flow failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _preparingSource = false);
    }
  }

  void _submit() {
    final file = _videoFile;
    if (file == null) return;
    context.read<UploadCubit>().upload(
          videoPath: file.path,
          thumbnailPath: _thumbnailPath,
          description: _descriptionController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reels.upload_title'.tr())),
      body: BlocConsumer<UploadCubit, UploadState>(
        listener: (context, state) {
          if (state.status == UploadStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('reels.upload_success'.tr())),
            );
            Navigator.of(context).pop(state.uploadedReel);
          }
        },
        builder: (context, state) {
          if (state.status == UploadStatus.uploading) {
            return _UploadProgressView(progress: state.progress);
          }
          if (state.status == UploadStatus.failure) {
            return _UploadFailureView(
              message: state.errorMessage,
              onRetry: _submit,
            );
          }
          return _ComposeView(
            preparingSource: _preparingSource,
            videoFile: _videoFile,
            thumbnailPath: _thumbnailPath,
            descriptionController: _descriptionController,
            onPickCamera: () => _pick(ImageSource.camera),
            onPickGallery: () => _pick(ImageSource.gallery),
            onSubmit: _videoFile == null ? null : _submit,
          );
        },
      ),
    );
  }
}

class _ComposeView extends StatelessWidget {
  const _ComposeView({
    required this.preparingSource,
    required this.videoFile,
    required this.thumbnailPath,
    required this.descriptionController,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onSubmit,
  });

  final bool preparingSource;
  final File? videoFile;
  final String? thumbnailPath;
  final TextEditingController descriptionController;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    if (preparingSource) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (videoFile == null) ...[
            Text('reels.upload_pick_source'.tr()),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onPickCamera,
              icon: const Icon(Icons.videocam),
              label: Text('reels.upload_record'.tr()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onPickGallery,
              icon: const Icon(Icons.photo_library),
              label: Text('reels.upload_gallery'.tr()),
            ),
          ] else ...[
            if (thumbnailPath != null)
              AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(thumbnailPath!), fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              maxLength: 2200,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'reels.upload_description_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onSubmit,
              child: Text('reels.upload_submit'.tr()),
            ),
            TextButton(
              onPressed: onPickGallery,
              child: Text('reels.upload_gallery'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadProgressView extends StatelessWidget {
  const _UploadProgressView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress > 0 ? progress : null),
          const SizedBox(height: 16),
          Text('reels.upload_progress'.tr()),
        ],
      ),
    );
  }
}

class _UploadFailureView extends StatelessWidget {
  const _UploadFailureView({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(message ?? 'reels.upload_failed_retry'.tr()),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('reels.upload_failed_retry'.tr()),
          ),
        ],
      ),
    );
  }
}
