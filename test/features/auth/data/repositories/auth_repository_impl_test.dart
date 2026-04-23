import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ciro_chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ciro_chat_app/core/error/failures.dart';

import '../../mocks.dart';

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockAuthLocalDataSource mockLocalDataSource;

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockLocalDataSource = MockAuthLocalDataSource();
    repository = AuthRepositoryImpl(mockRemoteDataSource, mockLocalDataSource);
  });

  group('sendOtp', () {
    const tPhone = '1234567890';

    test('should return Right(null) when remote call is successful', () async {
      // arrange
      when(() => mockRemoteDataSource.sendOtp(any())).thenAnswer((_) async => {});

      // act
      final result = await repository.sendOtp(tPhone);

      // assert
      expect(result, equals(const Right(null)));
      verify(() => mockRemoteDataSource.sendOtp(tPhone)).called(1);
    });

    test('should return Left(ServerFailure) when remote call fails', () async {
      // arrange
      when(() => mockRemoteDataSource.sendOtp(any())).thenThrow(Exception('Server Error'));

      // act
      final result = await repository.sendOtp(tPhone);

      // assert
      expect(result, isA<Left<Failure, void>>());
      final failure = result.fold((l) => l, (r) => null);
      expect(failure, isA<ServerFailure>());
    });
  });

  group('verifyOtp', () {
    const tPhone = '1234567890';
    const tCode = '1234';
    final tResponse = {
      'accessToken': 'at',
      'refreshToken': 'rt',
      'user': {'_id': 'u123'}
    };

    test('should save tokens and return Right(response) when verification is successful', () async {
      // arrange
      when(() => mockRemoteDataSource.verifyOtp(any(), any())).thenAnswer((_) async => tResponse);
      when(() => mockLocalDataSource.saveUserPhone(any())).thenAnswer((_) async => {});
      when(() => mockLocalDataSource.saveUserId(any())).thenAnswer((_) async => {});
      when(() => mockLocalDataSource.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          )).thenAnswer((_) async => {});
      when(() => mockLocalDataSource.setLoggedInStatus(any())).thenAnswer((_) async => {});

      // act
      final result = await repository.verifyOtp(tPhone, tCode);

      // assert
      expect(result, equals(Right(tResponse)));
      verify(() => mockRemoteDataSource.verifyOtp(tPhone, tCode)).called(1);
      verify(() => mockLocalDataSource.saveTokens(accessToken: 'at', refreshToken: 'rt')).called(1);
      verify(() => mockLocalDataSource.setLoggedInStatus(true)).called(1);
    });

    test('should return Left(AuthFailure) when response is missing accessToken', () async {
      // arrange
      when(() => mockRemoteDataSource.verifyOtp(any(), any())).thenAnswer((_) async => {});

      // act
      final result = await repository.verifyOtp(tPhone, tCode);

      // assert
      expect(result, isA<Left<Failure, Map<String, dynamic>>>());
      final failure = result.fold((l) => l, (r) => null);
      expect(failure, isA<AuthFailure>());
    });

    test('should return Left(ServerFailure) when remote call fails', () async {
      // arrange
      when(() => mockRemoteDataSource.verifyOtp(any(), any())).thenThrow(Exception('Verify Error'));

      // act
      final result = await repository.verifyOtp(tPhone, tCode);

      // assert
      expect(result, isA<Left<Failure, Map<String, dynamic>>>());
    });
  });

  group('checkAuthStatus', () {
    test('should return Right(true) when token exists and logged in', () async {
      // arrange
      when(() => mockLocalDataSource.getAccessToken()).thenAnswer((_) async => 'at');
      when(() => mockLocalDataSource.getLoggedInStatus()).thenAnswer((_) async => true);

      // act
      final result = await repository.checkAuthStatus();

      // assert
      expect(result, equals(const Right(true)));
    });

    test('should return Right(false) when token is missing', () async {
      // arrange
      when(() => mockLocalDataSource.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockLocalDataSource.getLoggedInStatus()).thenAnswer((_) async => true);

      // act
      final result = await repository.checkAuthStatus();

      // assert
      expect(result, equals(const Right(false)));
    });
  });
}
