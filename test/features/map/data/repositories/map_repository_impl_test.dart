import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/map/data/datasources/map_remote_data_source.dart';
import 'package:ciro_chat_app/features/map/data/models/map_user_model.dart';
import 'package:ciro_chat_app/features/map/data/repositories/map_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockMapRemoteDataSource extends Mock implements MapRemoteDataSource {}

void main() {
  late MapRepositoryImpl repository;
  late MockMapRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockRemoteDataSource = MockMapRemoteDataSource();
    repository = MapRepositoryImpl(mockRemoteDataSource);
  });

  MapUserModel buildModel(String id) => MapUserModel(
        id: id,
        name: 'User $id',
        isOnline: true,
        latitude: 30.0,
        longitude: 31.0,
        lastUpdatedAt: DateTime(2026, 1, 1),
      );

  group('getVisibleUsers (T032)', () {
    test('maps a successful remote fetch to Right(List<MapUser>)', () async {
      when(() => mockRemoteDataSource.getVisibleUsers())
          .thenAnswer((_) async => [buildModel('u1'), buildModel('u2')]);

      final result = await repository.getVisibleUsers();

      expect(result, isA<Right<Failure, List<dynamic>>>());
      final users = result.fold((_) => null, (r) => r);
      expect(users, isNotNull);
      expect(users!.map((u) => u.id), ['u1', 'u2']);
    });

    test('maps a DioException to Left(ServerFailure) via fromDioException', () async {
      when(() => mockRemoteDataSource.getVisibleUsers()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/map/visible'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await repository.getVisibleUsers();

      expect(result, isA<Left<Failure, List<dynamic>>>());
      final failure = result.fold((l) => l, (_) => null);
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).message, contains('Connection Timeout'));
    });

    test('maps a non-Dio exception to Left(ServerFailure) with the error message', () async {
      when(() => mockRemoteDataSource.getVisibleUsers())
          .thenThrow(Exception('socket closed'));

      final result = await repository.getVisibleUsers();

      final failure = result.fold((l) => l, (_) => null);
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).message, contains('socket closed'));
    });
  });

  group('getExploreUsers (T032)', () {
    test('maps a successful remote fetch to Right(List<MapUser>), including coarse entries', () async {
      when(() => mockRemoteDataSource.getExploreUsers()).thenAnswer(
        (_) async => [
          buildModel('contact1'),
          MapUserModel(
            id: 'noncontact1',
            name: 'Stranger',
            isOnline: true,
            latitude: 30.01,
            longitude: 31.01,
            lastUpdatedAt: DateTime(2026, 1, 1),
            isCoarse: true,
          ),
        ],
      );

      final result = await repository.getExploreUsers();

      final users = result.fold((_) => null, (r) => r);
      expect(users, isNotNull);
      expect(users!.singleWhere((u) => u.id == 'noncontact1').isCoarse, isTrue);
      expect(users.singleWhere((u) => u.id == 'contact1').isCoarse, isFalse);
    });

    test('maps a remote failure to Left(ServerFailure)', () async {
      when(() => mockRemoteDataSource.getExploreUsers())
          .thenThrow(Exception('unreachable'));

      final result = await repository.getExploreUsers();

      expect(result, isA<Left<Failure, List<dynamic>>>());
    });
  });
}
