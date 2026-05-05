import 'package:ciro_chat_app/core/theme/app_constants.dart';

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
}
