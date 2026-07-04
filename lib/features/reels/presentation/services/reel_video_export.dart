import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Shared ffmpeg export settings for reel uploads. Both the trim path
/// ([ReelTrimmerScreen], source >60s) and the no-trim path ([UploadReelScreen],
/// source ≤60s) run the *same* re-encode so every uploaded reel is normalized
/// identically — not just the ones that happen to need trimming.
///
/// The critical flag is `-movflags +faststart`, which relocates the MP4 `moov`
/// atom to the front of the file. Without it, a progressively-downloaded clip
/// whose `moov` sits at the end stutters badly on the first playback (the
/// player can't begin decoding until it has fetched the tail of the file) and
/// only plays smoothly once fully cached. The `scale`/CRF settings additionally
/// cap resolution and bitrate so a heavy source doesn't outrun the player's
/// buffer on the first pass.
class ReelVideoExport {
  ReelVideoExport._();

  /// libx264/aac re-encode settings shared by both export paths.
  static const String encodeArgs =
      '-c:v libx264 -preset veryfast -crf 28 -pix_fmt yuv420p '
      '-c:a aac -b:a 128k -movflags +faststart';

  /// Downscale to ≤720px wide, preserving aspect ratio (`-2` keeps the height
  /// even, as the yuv420p pixel format requires).
  static const String scaleFilter = "scale='min(720,iw)':-2";

  /// Re-encodes an entire ≤60s [source] clip (no trimming) with [encodeArgs]
  /// and [scaleFilter], writing a faststart-optimized MP4 to a temp path.
  ///
  /// Returns the output path, or `null` on any failure — callers fall back to
  /// uploading [source] as-is. A transient ffmpeg failure must never block the
  /// user from posting; the backend's post-upload remux is the safety net that
  /// still guarantees faststart in that case.
  static Future<String?> normalizeFullClip(File source) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/reel_norm_${DateTime.now().millisecondsSinceEpoch}.mp4';
      // Quote both paths — a gallery pick can contain spaces (e.g.
      // "Screen Recording ….mov"); ffmpeg_kit splits the command on
      // whitespace, so an unquoted path with a space breaks arg parsing.
      final command =
          '-i "${source.path}" -vf "$scaleFilter" $encodeArgs -y "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (ReturnCode.isSuccess(code)) {
        final bytes = await File(outputPath).length();
        debugPrint('[ReelVideoExport] normalize OK: '
            '${(bytes / 1048576).toStringAsFixed(1)}MB at $outputPath');
        return outputPath;
      }
      final logs = await session.getAllLogsAsString();
      debugPrint('[ReelVideoExport] normalize FAILED (code=$code):\n$logs');
      return null;
    } catch (e) {
      debugPrint('[ReelVideoExport] normalize threw: $e');
      return null;
    }
  }
}
