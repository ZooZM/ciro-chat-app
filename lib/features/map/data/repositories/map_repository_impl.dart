import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import '../datasources/map_remote_data_source.dart';
import '../../domain/entities/map_user.dart';
import '../../domain/entities/map_group.dart';
import '../../domain/repositories/map_repository.dart';

@LazySingleton(as: MapRepository)
class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl(this._remoteDataSource);

  final MapRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<MapUser>>> getVisibleUsers() async {
    try {
      final users = await _remoteDataSource.getVisibleUsers();
      return Right(users.map((u) => u.toEntity()).toList());
    } on DioException catch (e) {
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MapUser>>> getNearbyUsers({
    required double longitude,
    required double latitude,
    required double radiusKm,
  }) async {
    try {
      final users = await _remoteDataSource.getNearbyUsers(
        longitude: longitude,
        latitude: latitude,
        radiusKm: radiusKm,
      );
      return Right(users.map((u) => u.toEntity()).toList());
    } on DioException catch (e) {
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MapUser>>> getExploreUsers() async {
    try {
      final users = await _remoteDataSource.getExploreUsers();
      return Right(users.map((u) => u.toEntity()).toList());
    } on DioException catch (e) {
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MapGroup>>> getGroups() async {
    try {
      final groups = await _remoteDataSource.getGroups();
      return Right(groups.map((g) => g.toEntity()).toList());
    } on DioException catch (e) {
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> setGhostMode(bool enabled) async {
    try {
      final result = await _remoteDataSource.setGhostMode(enabled);
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> getGhostMode() async {
    try {
      final result = await _remoteDataSource.getGhostMode();
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure.fromDioException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  void shareLocation({required double longitude, required double latitude}) {
    _remoteDataSource.shareLocation(longitude: longitude, latitude: latitude);
  }

  @override
  Stream<PresenceUpdate> get presenceUpdates =>
      _remoteDataSource.onUserStatusChanged;

  @override
  Stream<List<LocationUpdate>> get locationUpdates => _remoteDataSource
      .onLocationUpdate
      .map((updates) => updates.map((u) => u.toEntity()).toList());

  @override
  Stream<String> get locationHidden => _remoteDataSource.onLocationHidden;

  @override
  void dispose() {
    _remoteDataSource.dispose();
  }
}
