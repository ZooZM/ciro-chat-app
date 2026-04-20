import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

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

  AuthCubit(this._repository, this._localDataSource) : super(const AuthInitial());

  Future<void> verifyAuthStatus() async {
    emit(const AuthLoading());

    // Splash screen minimum display duration — prevents jarring flash on fast devices.
    await Future.delayed(const Duration(seconds: 2));

    try {
      final isAuthenticated = await _repository.checkAuthStatus();

      if (isAuthenticated) {
        // Always read the CURRENT token from secure storage after the repository
        // has had a chance to silently refresh it, then hand it to the socket.
        final freshToken = await _localDataSource.getAccessToken() ?? '';
        if (freshToken.isNotEmpty) {
          getIt<SocketService>().connect(freshToken);
          debugPrint('[AuthCubit] Socket connected on app start with fresh token');

          // Fire-and-forget: pre-warm the contacts cache BEFORE the user
          // opens ContactsScreen so there is zero empty-state flash.
          // This runs fully in the background — Authenticated() emits immediately.
          getIt<ChatCubit>().silentSyncContacts().ignore();
        }
        emit(const Authenticated());
      } else {
        // Safety: ensure no stale socket is left open when the user is not authenticated.
        getIt<SocketService>().disconnect();
        emit(const Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> submitPhoneNumber(String phone) async {
    emit(const AuthLoading());
    try {
      await _repository.sendOtp(phone);
      // We remain unauthenticated until they submit the OTP specifically
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> submitOtp(String phone, String code) async {
    emit(const AuthLoading());
    try {
      // AuthRepositoryImpl.verifyOtp() saves the new token to secure storage internally.
      final response = await _repository.verifyOtp(phone, code);

      // Read the token back from secure storage so we use exactly what was saved
      // (handles any normalisation the repository does before persisting).
      final freshToken = await _localDataSource.getAccessToken() ?? '';

      // Connect the socket BEFORE emitting Authenticated so the home screen
      // never has a window where the router has navigated but the socket is offline.
      if (freshToken.isNotEmpty) {
        getIt<SocketService>().connect(freshToken);
        debugPrint('[AuthCubit] Socket connected after OTP verification');

        // Fire-and-forget: pre-warm the contacts cache immediately after login.
        // .ignore() suppresses the unawaited-future lint without blocking navigation.
        getIt<ChatCubit>().silentSyncContacts().ignore();
      }

      emit(Authenticated(userData: response));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logOut() async {
    emit(const AuthLoading());
    try {
      // 1. Reset UI & Streams first (Close the apps)
      getIt<ChatCubit>().reset();
      getIt<CallCubit>().reset();

      // 2. Disconnect Network (Sever the connection)
      getIt<SocketService>().disconnect();

      // 3. Nuke Local Database (Format the hard drive)
      await getIt<ChatLocalDataSource>().clearAllData();

      // 4. Clear Secure Storage Credentials (Destroy the passport)
      await _repository.logout();

      // 5. Trigger Routing Guard (Kick the user out)
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
