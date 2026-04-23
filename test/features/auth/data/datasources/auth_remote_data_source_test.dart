import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ciro_chat_app/core/network/dio_client.dart';

import '../../mocks.dart';

class MockDioClient extends Mock implements DioClient {}

void main() {
  late AuthRemoteDataSourceImpl dataSource;
  late MockDioClient mockDioClient;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    mockDioClient = MockDioClient();
    when(() => mockDioClient.dio).thenReturn(mockDio);
    dataSource = AuthRemoteDataSourceImpl(mockDioClient);
  });

  group('sendOtp', () {
    const tPhone = '1234567890';

    test('should perform a POST request to /auth/send-otp', () async {
      // arrange
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => MockResponse());

      // act
      await dataSource.sendOtp(tPhone);

      // assert
      verify(() => mockDio.post(
            '/auth/send-otp',
            data: {'phoneNumber': tPhone},
          )).called(1);
    });
  });

  group('verifyOtp', () {
    const tPhone = '1234567890';
    const tCode = '1234';
    final tResponse = {
      'data': {
        'accessToken': 'access_token',
        'refreshToken': 'refresh_token',
      }
    };

    test('should perform a POST request to /auth/verify-otp and return data', () async {
      // arrange
      final response = MockResponse();
      when(() => response.data).thenReturn(tResponse);
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => response);

      // act
      final result = await dataSource.verifyOtp(tPhone, tCode);

      // assert
      verify(() => mockDio.post(
            '/auth/verify-otp',
            data: {'phoneNumber': tPhone, 'code': tCode},
          )).called(1);
      expect(result, equals(tResponse['data']));
    });
  });
}
