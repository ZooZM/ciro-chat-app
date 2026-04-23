part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final Map<String, dynamic>? userData;
  const Authenticated({this.userData});

  @override
  List<Object?> get props => [userData];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final Failure failure;
  const AuthError(this.failure);

  @override
  List<Object?> get props => [failure];
}
