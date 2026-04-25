import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_local_data_source.dart';

import '../../../chat/presentation/bloc/chat_cubit.dart';
import '../../../video_call/presentation/bloc/call_cubit.dart';
import '../../../chat/data/datasources/chat_local_data_source.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/di/injection.dart';

part 'auth_state.dart';

@lazySingleton
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;
  final AuthLocalDataSource _localDataSource;

  AuthCubit(this._repository, this._localDataSource)
    : super(const AuthInitial());

  Future<void> verifyAuthStatus() async {
    emit(const AuthLoading());

    // Splash screen minimum display duration removed to fix "jarring delay" bug.
    // If needed, the splash screen should handle its own duration at the UI layer.

    final result = await _repository.checkAuthStatus();

    await result.fold((failure) async => emit(AuthError(failure)), (
      isAuthenticated,
    ) async {
      if (isAuthenticated) {
        final freshToken = await _localDataSource.getAccessToken() ?? '';
        if (freshToken.isNotEmpty) {
          getIt<SocketService>().connect(freshToken);
          debugPrint('[AuthCubit] Socket connected on app start');

          getIt<ChatCubit>().silentSyncContacts().ignore();
        }
        emit(const Authenticated());
      } else {
        getIt<SocketService>().disconnect();
        emit(const Unauthenticated());
      }
    });
  }

  Future<void> submitPhoneNumber(String phone) async {
    emit(const AuthLoading());
    final result = await _repository.sendOtp(phone);

    await result.fold(
      (failure) async => emit(AuthError(failure)),
      (_) async => emit(const Unauthenticated()),
    );
  }

  Future<void> submitOtp(String phone, String code) async {
    emit(const AuthLoading());
    final result = await _repository.verifyOtp(phone, code);

    await result.fold((failure) async => emit(AuthError(failure)), (
      response,
    ) async {
      final freshToken = await _localDataSource.getAccessToken() ?? '';

      if (freshToken.isNotEmpty) {
        getIt<SocketService>().connect(freshToken);
        debugPrint('[AuthCubit] Socket connected after OTP verification');
        getIt<ChatCubit>().silentSyncContacts().ignore();
      }

      emit(Authenticated(userData: response));
    });
  }

  Future<void> logOut() async {
    emit(const AuthLoading());
    try {
      // 1. Reset UI & Streams first
      getIt<ChatCubit>().reset();
      getIt<CallCubit>().reset();

      // 2. Disconnect Network
      getIt<SocketService>().disconnect();

      // 3. Nuke Local Database
      await getIt<ChatLocalDataSource>().clearAllData();

      // 4. Clear Secure Storage Credentials
      final result = await _repository.logout();

      await result.fold(
        (failure) async => emit(AuthError(failure)),
        (_) async => emit(const Unauthenticated()),
      );
    } catch (e) {
      emit(AuthError(ServerFailure(e.toString())));
    }
  }
}
