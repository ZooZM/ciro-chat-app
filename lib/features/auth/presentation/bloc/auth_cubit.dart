import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_constants.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_local_data_source.dart';

import '../../../chat/presentation/bloc/chat_cubit.dart';
import '../../../video_call/presentation/bloc/call_cubit.dart';
import '../../../call_recording/presentation/bloc/call_recording_cubit.dart';
import '../../../chat/data/datasources/chat_local_data_source.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/push_notification_service.dart';

part 'auth_state.dart';

@lazySingleton
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;
  final AuthLocalDataSource _localDataSource;

  AuthCubit(this._repository, this._localDataSource)
    : super(const AuthInitial());

  Future<bool> verifyAuthStatus() async {
    emit(const AuthLoading());

    final result = await _repository.checkAuthStatus();

    await result.fold((failure) async => emit(AuthError(failure)), (
      isAuthenticated,
    ) async {
      if (isAuthenticated) {
        // Proactively refresh the access token if it is close to expiry so the
        // socket connects with a fresh JWT and avoids an immediate reconnect cycle.
        await _proactiveTokenRefreshIfNeeded();

        final freshToken = await _localDataSource.getAccessToken() ?? '';
        if (freshToken.isNotEmpty) {
          getIt<SocketService>().connect(freshToken);
          debugPrint('[AuthCubit] Socket connected on app start');

          getIt<ChatCubit>().silentSyncContacts().ignore();
          getIt<PushNotificationService>().init().ignore();
        }
        emit(const Authenticated());
        return true;
      } else {
        getIt<SocketService>().disconnect();
        emit(const Unauthenticated());
        return false;
      }
    });

    if (state is AuthError) return false;
    return state is Authenticated;
  }

  /// Decodes the JWT payload without verifying the signature.
  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final padded = base64Url.normalize(parts[1]);
      return json.decode(utf8.decode(base64Url.decode(padded)))
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Refreshes the access token if it expires within 5 minutes.
  Future<void> _proactiveTokenRefreshIfNeeded() async {
    try {
      final accessToken = await _localDataSource.getAccessToken() ?? '';
      if (accessToken.isEmpty) return;

      final payload = _decodeJwtPayload(accessToken);
      final exp = payload['exp'] as int?;
      if (exp == null) return;

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      final remaining = expiresAt.difference(DateTime.now().toUtc());
      if (remaining > const Duration(minutes: 5)) return;

      debugPrint('[AuthCubit] Access token expires in ${remaining.inSeconds}s — proactive refresh');

      final refreshToken = await _localDataSource.getRefreshToken() ?? '';
      if (refreshToken.isEmpty) return;

      final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final newAccess = response.data['accessToken'] as String?;
      final newRefresh =
          response.data['refreshToken'] as String? ?? refreshToken;

      if (newAccess != null && newAccess.isNotEmpty) {
        await _localDataSource.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );
        debugPrint('[AuthCubit] Proactive token refresh successful');
      }
    } catch (e) {
      debugPrint('[AuthCubit] Proactive token refresh failed (non-fatal): $e');
    }
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
        getIt<PushNotificationService>().init().ignore();
      }

      emit(Authenticated(userData: response));
    });
  }

  Future<void> logOut() async {
    emit(const AuthLoading());
    try {
      // 1. Reset UI & Streams first — stop recording before DB is wiped
      final recCubit = getIt<CallRecordingCubit>();
      if (recCubit.state is RecordingActive) await recCubit.stop();
      getIt<ChatCubit>().reset();
      getIt<CallCubit>().reset();

      // 2. Disconnect Network & unregister push
      getIt<SocketService>().disconnect();
      await getIt<PushNotificationService>().dispose();

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
