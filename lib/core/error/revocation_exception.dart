/// Thrown by `TokenRefreshService` when the backend explicitly signals that
/// the session is no longer valid (HTTP 401 + a known terminal message).
///
/// Caught by `DioClient`, `SocketService`, and `AuthCubit` to trigger the
/// global logout sequence. NOT a domain `Failure` because it is a side-effect
/// trigger, not a value returned through repositories.
class RevocationException implements Exception {
  final String message;
  const RevocationException([this.message = 'Session revoked by server']);

  @override
  String toString() => 'RevocationException: $message';
}
