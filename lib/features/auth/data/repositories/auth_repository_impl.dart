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
    
    // Assuming backend returns {"accessToken": "...", "refreshToken": "..."}
    final accessToken = response['accessToken'] as String?;
    final refreshToken = response['refreshToken'] as String?;

    if (accessToken != null) {
      await _localDataSource.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
      );
    } else {
      throw Exception('Invalid token payload from server');
    }
  }

  @override
  Future<void> logout() async {
    await _localDataSource.deleteTokens();
  }

  @override
  Future<bool> checkAuthStatus() async {
    final token = await _localDataSource.getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
