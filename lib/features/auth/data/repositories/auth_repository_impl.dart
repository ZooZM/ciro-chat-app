import 'package:injectable/injectable.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_local_data_source.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<void> sendOtp(String phoneNumber) async {
    await _remoteDataSource.sendOtp(phoneNumber);
  }

  @override
  Future<void> verifyOtp(String phoneNumber, String code) async {
    final response = await _remoteDataSource.verifyOtp(phoneNumber, code);
    
    // Capture the response structure for debugging if it fails
    final keys = response.keys.toList();
    
    // Robust extraction: check both root and nested 'data' field
    String? accessToken = response['accessToken'] as String?;
    String? refreshToken = response['refreshToken'] as String?;
    
    if (accessToken == null && response.containsKey('data')) {
      final data = response['data'] as Map<String, dynamic>?;
      accessToken = data?['accessToken'] as String?;
      refreshToken = data?['refreshToken'] as String?;
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      await _localDataSource.saveUserPhone(phoneNumber); // Core dynamic identifier 
      await _localDataSource.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
      );
      await _localDataSource.setLoggedInStatus(true);
    } else {
      // Provide more diagnostic information in the error message
      throw Exception('Invalid token payload. Found keys: $keys. Expected "accessToken" or "data.accessToken"');
    }
  }

  @override
  Future<void> logout() async {
    await _localDataSource.deleteTokens();
  }

  @override
  Future<bool> checkAuthStatus() async {
    final token = await _localDataSource.getAccessToken();
    final isLoggedIn = await _localDataSource.getLoggedInStatus();
    return token != null && token.isNotEmpty && isLoggedIn;
  }
}
