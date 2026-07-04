import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/reels_constants.dart';

/// Best-effort network warm-up for the video 2 positions ahead of the
/// current one (FR-010). Deliberately independent of `DioClient` — this is
/// a fire-and-forget range request with no auth/interceptor needs and must
/// never surface a failure to the UI (a cold cache on swipe just means a
/// normal buffering indicator, not an error).
@lazySingleton
class ReelsPrefetchService {
  ReelsPrefetchService() : _dio = Dio();

  final Dio _dio;
  final Set<String> _inFlight = {};

  /// Fires a ranged GET for the first [ReelsConstants.prefetchRangeBytes] of
  /// [videoUrl] and discards the body — this warms DNS/TLS/CDN caches so the
  /// eventual `media_kit` `Player.open()` for that video starts faster.
  Future<void> prefetch(String videoUrl) async {
    if (videoUrl.isEmpty || _inFlight.contains(videoUrl)) return;
    _inFlight.add(videoUrl);
    try {
      await _dio.get<List<int>>(
        videoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Range': 'bytes=0-${ReelsConstants.prefetchRangeBytes - 1}'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (e) {
      debugPrint('[ReelsPrefetchService] prefetch failed for $videoUrl: $e');
    } finally {
      _inFlight.remove(videoUrl);
    }
  }
}
