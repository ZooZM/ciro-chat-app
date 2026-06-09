import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// FR-035: Saves completed recordings to the device gallery (Photos/Gallery)
/// for video recordings, or the Downloads/Documents folder for audio-only.
@lazySingleton
class GallerySaverService {
  /// Saves [filePath] to the appropriate system location.
  /// [hasVideo] true  → Photos/Gallery (via gal) for MP4/MOV.
  /// [hasVideo] false → Downloads on Android, app Documents on iOS (M4A/AAC).
  /// Returns the saved destination path, or null on failure.
  Future<String?> save(String filePath, {required bool hasVideo}) async {
    try {
      if (hasVideo) {
        await Gal.putVideo(filePath);
        return filePath;
      } else {
        return await _saveAudioToDownloads(filePath);
      }
    } catch (e) {
      debugPrint('[GallerySaverService] save failed: $e');
      return null;
    }
  }

  Future<String?> _saveAudioToDownloads(String sourcePath) async {
    try {
      final Directory destDir;
      if (Platform.isAndroid) {
        // External downloads directory visible in the Files app.
        final List<Directory>? extDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        destDir = extDirs?.firstOrNull ??
            await getApplicationDocumentsDirectory();
      } else {
        // iOS: app Documents directory, visible via Files app.
        destDir = await getApplicationDocumentsDirectory();
      }
      final fileName = p.basename(sourcePath);
      final destPath = p.join(destDir.path, fileName);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('[GallerySaverService] _saveAudioToDownloads failed: $e');
      return null;
    }
  }

  /// Requests the storage permission required by [Gal] for video saves.
  Future<bool> requestPermission() async {
    try {
      return await Gal.requestAccess();
    } catch (e) {
      debugPrint('[GallerySaverService] requestPermission failed: $e');
      return false;
    }
  }
}
