import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/auth_repository.dart';

part 'auth_state.dart';

@injectable
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
      await _repository.logout();
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
