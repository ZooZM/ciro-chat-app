import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';

import '../../mocks.dart';

void main() {
  late AuthLocalDataSourceImpl dataSource;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    dataSource = AuthLocalDataSourceImpl(mockStorage);
  });

  group('saveTokens', () {
    test('should call FlutterSecureStorage to save tokens', () async {
      // arrange
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async => {});

      // act
      await dataSource.saveTokens(accessToken: 'at', refreshToken: 'rt');

      // assert
      verify(() => mockStorage.write(key: 'accessToken', value: 'at')).called(1);
      verify(() => mockStorage.write(key: 'refreshToken', value: 'rt')).called(1);
    });
  });

  group('getAccessToken', () {
    test('should return access token from storage', () async {
      // arrange
      when(() => mockStorage.read(key: 'accessToken')).thenAnswer((_) async => 'at');

      // act
      final result = await dataSource.getAccessToken();

      // assert
      expect(result, 'at');
    });
  });

  group('deleteTokens', () {
    test('should call FlutterSecureStorage to delete all auth data', () async {
      // arrange
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async => {});

      // act
      await dataSource.deleteTokens();

      // assert
      verify(() => mockStorage.delete(key: 'accessToken')).called(1);
      verify(() => mockStorage.delete(key: 'refreshToken')).called(1);
      verify(() => mockStorage.delete(key: 'userPhone')).called(1);
      verify(() => mockStorage.delete(key: 'userId')).called(1);
      verify(() => mockStorage.delete(key: 'isLoggedIn')).called(1);
    });
  });

  group('getLoggedInStatus', () {
    test('should return true when isLoggedIn is "true"', () async {
      // arrange
      when(() => mockStorage.read(key: 'isLoggedIn')).thenAnswer((_) async => 'true');

      // act
      final result = await dataSource.getLoggedInStatus();

      // assert
      expect(result, isTrue);
    });

    test('should return false when isLoggedIn is not "true"', () async {
      // arrange
      when(() => mockStorage.read(key: 'isLoggedIn')).thenAnswer((_) async => 'false');

      // act
      final result = await dataSource.getLoggedInStatus();

      // assert
      expect(result, isFalse);
    });
  });
}
