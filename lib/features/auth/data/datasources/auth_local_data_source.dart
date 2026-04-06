import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

abstract class AuthLocalDataSource {
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> deleteTokens();
}

@LazySingleton(as: AuthLocalDataSource)
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage _storage;

  AuthLocalDataSourceImpl(this._storage);

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    // You might also want to save a refreshToken if your backend generates one
    await _storage.write(key: 'refreshToken', value: refreshToken);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'accessToken');
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refreshToken');
  }

  @override
  Future<void> deleteTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }
}
