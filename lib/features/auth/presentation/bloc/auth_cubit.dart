import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/auth_repository.dart';

import '../../../chat/presentation/bloc/chat_cubit.dart';
import '../../../video_call/presentation/bloc/call_cubit.dart';
import '../../../chat/data/datasources/chat_local_data_source.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/di/injection.dart';

part 'auth_state.dart';

@lazySingleton
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(const AuthInitial());

  Future<void> verifyAuthStatus() async {
    emit(const AuthLoading());
    try {
      final isAuthenticated = await _repository.checkAuthStatus();
      if (isAuthenticated) {
        emit(const Authenticated());
      } else {
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
      final response = await _repository.verifyOtp(phone, code);
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
