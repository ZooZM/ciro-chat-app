import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/core/utils/auth_token_cache.dart';

class UrlUtils {
  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    // Use the same base URL as DioClient
    final baseUrl = AppConstants.apiBaseUrl;

    // Ensure baseUrl doesn't end with slash if url starts with one, or vice versa
    final cleanedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanedUrl = url.startsWith('/') ? url : '/$url';

    return '$cleanedBaseUrl$cleanedUrl';
  }

  /// Headers to attach to `Image.network`/`CachedNetworkImage` requests for
  /// endpoints that require authentication (e.g. `/status/media/...`, which
  /// is guarded by `JwtAuthGuard` on the backend). Returns `null` if no
  /// token is cached, so callers can pass it straight through.
  static Map<String, String>? get authHeaders {
    final token = AuthTokenCache.token;
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }
}
