// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/auth/data/datasources/auth_local_data_source.dart'
    as _i852;
import '../../features/auth/data/datasources/auth_remote_data_source.dart'
    as _i107;
import '../../features/auth/data/repositories/auth_repository_impl.dart'
    as _i153;
import '../../features/auth/domain/repositories/auth_repository.dart' as _i787;
import '../../features/auth/presentation/bloc/auth_cubit.dart' as _i52;
import '../../features/video_call/data/datasources/video_call_remote_data_source.dart'
    as _i5;
import '../../features/video_call/data/repositories/livekit_video_call_repository_impl.dart'
    as _i786;
import '../../features/video_call/domain/repositories/video_call_repository.dart'
    as _i220;
import '../../features/video_call/presentation/bloc/video_call_cubit.dart'
    as _i804;
import '../network/dio_client.dart' as _i667;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final storageModule = _$StorageModule();
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => storageModule.secureStorage,
    );
    gh.lazySingleton<_i852.AuthLocalDataSource>(
      () => _i852.AuthLocalDataSourceImpl(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i667.DioClient>(
      () => _i667.DioClient(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i107.AuthRemoteDataSource>(
      () => _i107.AuthRemoteDataSourceImpl(gh<_i667.DioClient>()),
    );
    gh.lazySingleton<_i787.AuthRepository>(
      () => _i153.AuthRepositoryImpl(
        gh<_i107.AuthRemoteDataSource>(),
        gh<_i852.AuthLocalDataSource>(),
      ),
    );
    gh.lazySingleton<_i5.VideoCallRemoteDataSource>(
      () => _i5.VideoCallRemoteDataSourceImpl(gh<_i667.DioClient>()),
    );
    gh.factory<_i52.AuthCubit>(
      () => _i52.AuthCubit(gh<_i787.AuthRepository>()),
    );
    gh.lazySingleton<_i220.VideoCallRepository>(
      () => _i786.LivekitVideoCallRepositoryImpl(
        gh<_i5.VideoCallRemoteDataSource>(),
      ),
    );
    gh.factory<_i804.VideoCallCubit>(
      () => _i804.VideoCallCubit(gh<_i220.VideoCallRepository>()),
    );
    return this;
  }
}

class _$StorageModule extends _i667.StorageModule {}
