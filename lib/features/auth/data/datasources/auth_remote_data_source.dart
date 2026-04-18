import 'package:injectable/injectable.dart';

import '../../../../core/network/dio_client.dart';

abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String phoneNumber);
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String code);
}

@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient _dioClient;

  AuthRemoteDataSourceImpl(this._dioClient);

  @override
  Future<void> sendOtp(String phoneNumber) async {
    await _dioClient.dio.post(
      '/auth/send-otp',
      data: {'phoneNumber': phoneNumber},
    );
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String phoneNumber,
    String code,
  ) async {
    final response = await _dioClient.dio.post(
      '/auth/verify-otp',
      data: {'phoneNumber': phoneNumber, 'code': code},
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
