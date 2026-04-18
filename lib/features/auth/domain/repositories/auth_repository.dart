abstract class AuthRepository {
  Future<void> sendOtp(String phoneNumber);
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String code);
  Future<void> logout();
  Future<bool> checkAuthStatus();
}
