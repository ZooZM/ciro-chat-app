abstract class AuthRepository {
  Future<void> sendOtp(String phoneNumber);
  Future<void> verifyOtp(String phoneNumber, String code);
  Future<void> logout();
  Future<bool> checkAuthStatus();
}
