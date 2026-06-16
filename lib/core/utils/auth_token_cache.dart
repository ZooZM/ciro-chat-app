/// In-memory cache of the current access token.
///
/// Image widgets (`Image.network`, `CachedNetworkImage`, etc.) need request
/// headers synchronously, but [AuthLocalDataSource] reads the token from
/// secure storage asynchronously. [AuthLocalDataSourceImpl] keeps this cache
/// in sync with storage so callers can attach an `Authorization` header to
/// authenticated media requests (e.g. `/status/media/...`) without an
/// `await`.
class AuthTokenCache {
  static String? _token;

  static String? get token => _token;

  static void set(String? token) => _token = token;
}
