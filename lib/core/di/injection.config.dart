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
import '../../features/chat/data/datasources/chat_api_service.dart' as _i277;
import '../../features/chat/data/datasources/chat_local_data_source.dart'
    as _i94;
import '../../features/chat/data/datasources/chat_remote_data_source.dart'
    as _i980;
import '../../features/chat/data/repositories/chat_repository_impl.dart'
    as _i504;
import '../../features/chat/domain/repositories/chat_repository.dart' as _i420;
import '../../features/chat/presentation/bloc/chat_cubit.dart' as _i708;
import '../../features/contacts/data/contacts_service.dart' as _i850;
import '../../features/payment/data/datasources/payment_remote_data_source.dart'
    as _i811;
import '../../features/payment/data/repositories/payment_repository_impl.dart'
    as _i265;
import '../../features/payment/domain/repositories/payment_repository.dart'
    as _i639;
import '../../features/payment/presentation/bloc/payment_cubit.dart' as _i420;
import '../../features/video_call/data/datasources/video_call_remote_data_source.dart'
    as _i5;
import '../../features/video_call/data/repositories/livekit_video_call_repository_impl.dart'
    as _i786;
import '../../features/video_call/domain/repositories/video_call_repository.dart'
    as _i220;
import '../../features/video_call/presentation/bloc/video_call_cubit.dart'
    as _i804;
import '../network/dio_client.dart' as _i667;
import '../network/socket_service.dart' as _i917;

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
    gh.lazySingleton<_i917.SocketService>(() => _i917.SocketService());
    gh.lazySingleton<_i852.AuthLocalDataSource>(
      () => _i852.AuthLocalDataSourceImpl(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i94.ChatLocalDataSource>(
      () => _i94.ChatLocalDataSourceImpl(),
    );
    gh.lazySingleton<_i667.DioClient>(
      () => _i667.DioClient(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i980.ChatRemoteDataSource>(
      () => _i980.ChatRemoteDataSourceImpl(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i420.ChatRepository>(
      () => _i504.ChatRepositoryImpl(gh<_i980.ChatRemoteDataSource>()),
    );
    gh.lazySingleton<_i107.AuthRemoteDataSource>(
      () => _i107.AuthRemoteDataSourceImpl(gh<_i667.DioClient>()),
    );
    gh.lazySingleton<_i277.ChatApiService>(
      () => _i277.ChatApiService(
        gh<_i667.DioClient>(),
        gh<_i852.AuthLocalDataSource>(),
      ),
    );
    gh.lazySingleton<_i811.PaymentRemoteDataSource>(
      () => _i811.PaymentRemoteDataSourceImpl(gh<_i667.DioClient>()),
    );
    gh.lazySingleton<_i850.ContactsService>(
      () => _i850.ContactsService(gh<_i667.DioClient>()),
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
    gh.factory<_i708.ChatCubit>(
      () => _i708.ChatCubit(
        gh<_i94.ChatLocalDataSource>(),
        gh<_i917.SocketService>(),
        gh<_i852.AuthLocalDataSource>(),
        gh<_i277.ChatApiService>(),
        gh<_i850.ContactsService>(),
      ),
    );
    gh.factory<_i52.AuthCubit>(
      () => _i52.AuthCubit(gh<_i787.AuthRepository>()),
    );
    gh.lazySingleton<_i639.PaymentRepository>(
      () => _i265.PaymentRepositoryImpl(gh<_i811.PaymentRemoteDataSource>()),
    );
    gh.lazySingleton<_i220.VideoCallRepository>(
      () => _i786.LivekitVideoCallRepositoryImpl(
        gh<_i5.VideoCallRemoteDataSource>(),
      ),
    );
    gh.factory<_i420.PaymentCubit>(
      () => _i420.PaymentCubit(gh<_i639.PaymentRepository>()),
    );
    gh.factory<_i804.VideoCallCubit>(
      () => _i804.VideoCallCubit(gh<_i220.VideoCallRepository>()),
    );
    return this;
  }
}

class _$StorageModule extends _i667.StorageModule {}
