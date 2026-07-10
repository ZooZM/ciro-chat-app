import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';

import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/upload_reel_screen.dart';
import 'package:ciro_chat_app/features/reels/presentation/services/reel_video_export.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reel_trimmer_skeleton.dart';

/// WhatsApp-Status-style segment selector — every captured/picked source now
/// passes through this screen regardless of length (v5, FR-081, supersedes
/// the earlier >60s-only rule). [maxDuration] is the capture-time cap
/// (15s/30s/60s) for an in-app recording, or 60s for a gallery pick (binding
/// rule 15). The confirm CTA reads "Next"; on tap it exports the trimmed clip
/// and pushes the post-details step directly (B3 — never popping back to the
/// live camera first), then returns the posted [Reel] up to the capture screen.
/// Uses `video_editor`'s [VideoEditorController]/[TrimSlider] for the UI and
/// `ffmpeg_kit_flutter_new` directly for the cut (video_editor stopped bundling
/// ffmpeg as of 3.0.0).
class ReelTrimmerScreen extends StatefulWidget {
  const ReelTrimmerScreen({
    super.key,
    required this.sourceFile,
    this.maxDuration = const Duration(seconds: 60),
  });

  final File sourceFile;
  final Duration maxDuration;

  @override
  State<ReelTrimmerScreen> createState() => _ReelTrimmerScreenState();
}

class _ReelTrimmerScreenState extends State<ReelTrimmerScreen> {
  late final VideoEditorController _controller;
  bool _initialized = false;
  bool _exporting = false;
  FFmpegSession? _exportSession;

  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(
      widget.sourceFile,
      minDuration: const Duration(seconds: 1),
      maxDuration: widget.maxDuration,
    );
    _controller.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
    }).catchError((Object e) {
      // Surface a user-facing reason and return to the picker rather than
      // silently popping to an unchanged screen (which reads as "nothing
      // happened"). See upload_reel_screen for the space-in-path root cause.
      debugPrint('[ReelTrimmerScreen] initialize failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('reels.trim_export_failed'.tr())),
        );
        Navigator.of(context).pop<Reel?>(null);
      }
    });
  }

  @override
  void dispose() {
    // Constitution V: cancel any in-flight ffmpeg session on route pop so a
    // background export never outlives this screen.
    final session = _exportSession;
    if (session != null) {
      FFmpegKit.cancel(session.getSessionId());
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      // FR-060: re-encode instead of the default `-c copy` stream copy. A raw
      // 60s cut of a high-bitrate source (e.g. a screen recording, ~15 Mbps)
      // is ~109MB and blows past the server's 100MB cap. Downscale to ≤720px
      // wide and cap bitrate via CRF so a 60s reel lands around 15–30MB.
      final videoConfig = VideoFFmpegVideoEditorConfig(
        _controller,
        commandBuilder: (config, videoPath, outputPath) {
          final start = config.controller.startTrim;
          final duration = config.controller.trimmedDuration;
          final filters = config.getExportFilters()
            ..add(ReelVideoExport.scaleFilter);
          final vf = '-vf "${filters.join(',')}"';
          return "-ss $start -i $videoPath -t $duration $vf "
              '${ReelVideoExport.encodeArgs} -y $outputPath';
        },
      );
      final videoExec = await videoConfig.getExecuteConfig();
      final videoSession = await FFmpegKit.execute(videoExec.command);
      if (!mounted) return;
      _exportSession = videoSession;
      final videoCode = await videoSession.getReturnCode();
      if (!ReturnCode.isSuccess(videoCode)) {
        final logs = await videoSession.getAllLogsAsString();
        debugPrint('[ReelTrimmerScreen] ffmpeg export FAILED (code=$videoCode):\n$logs');
        throw Exception('ffmpeg trim export failed');
      }
      final outBytes = await File(videoExec.outputPath).length();
      debugPrint('[ReelTrimmerScreen] export OK: '
          '${(outBytes / 1048576).toStringAsFixed(1)}MB at ${videoExec.outputPath}');

      String? thumbnailPath;
      final coverExec = await CoverFFmpegVideoEditorConfig(_controller).getExecuteConfig();
      if (coverExec != null) {
        final coverSession = await FFmpegKit.execute(coverExec.command);
        final coverCode = await coverSession.getReturnCode();
        if (ReturnCode.isSuccess(coverCode)) {
          thumbnailPath = coverExec.outputPath;
        }
      }

      if (!mounted) return;
      // B3: push the post-details step on top of this trimmer (not popping
      // back to the live camera first). The posted Reel (or null if the user
      // backs out of the post screen) flows back here.
      final reel = await Navigator.of(context).push<Reel?>(
        MaterialPageRoute(
          builder: (_) => UploadReelScreen(
            videoPath: videoExec.outputPath,
            thumbnailPath: thumbnailPath,
          ),
        ),
      );
      if (!mounted) return;
      if (reel != null) {
        // Bubble the posted reel up to the capture screen (which pops on to
        // the profile). The unwind is synchronous — no camera frame renders.
        Navigator.of(context).pop<Reel?>(reel);
      } else {
        // Backed out of the post screen — stay on the trimmer, re-enabled.
        setState(() => _exporting = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reels.trim_export_failed'.tr())),
      );
    }
  }

  /// v5 (binding rule 15): backing out of the trimmer discards the captured
  /// clip — confirm first so a stray tap doesn't silently lose the recording.
  Future<bool> _confirmDiscard() async {
    if (_exporting) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('reels.capture_discard_title'.tr()),
        content: Text('reels.capture_discard_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('reels.capture_discard_action'.tr()),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscard();
        if (!context.mounted || !shouldDiscard) return;
        Navigator.of(context).pop<Reel?>(null);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('reels.trim_title'.tr()),
          actions: [
            if (_initialized && !_exporting)
              TextButton(
                onPressed: _confirm,
                child: Text(
                  'reels.trim_next'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        body: !_initialized
            ? const ReelTrimmerSkeleton()
            : _exporting
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _controller.video.value.aspectRatio,
                              child: VideoPlayer(_controller.video),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'reels.trim_duration_hint'.tr(),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: TrimSlider(
                            controller: _controller,
                            height: 60,
                            horizontalMargin: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
