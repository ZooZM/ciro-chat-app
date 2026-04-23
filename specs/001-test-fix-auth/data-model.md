# Data Model: Auth Feature Testing & Refactoring

## 1. Domain Failures
To comply with the Constitution, we define standard failures in `lib/core/error/failures.dart`.

- **ServerFailure**: For HTTP 5xx or general backend errors.
- **NetworkFailure**: For connectivity issues.
- **AuthFailure**: For invalid credentials, expired OTPs, or token errors.
- **CacheFailure**: For local storage (SecureStorage/Hive) errors.

## 2. Refactored Repository Interface
`lib/features/auth/domain/repositories/auth_repository.dart` will be updated to:

```dart
abstract class AuthRepository {
  Future<Either<Failure, void>> sendOtp(String phoneNumber);
  Future<Either<Failure, Map<String, dynamic>>> verifyOtp(String phoneNumber, String code);
  Future<Either<Failure, void>> logout();
  Future<bool> checkAuthStatus(); // Returns bool for simple guard checks
}
```

## 3. AuthState Transitions
`lib/features/auth/presentation/bloc/auth_state.dart`

- `AuthInitial`: Initial state.
- `AuthLoading`: Operation in progress.
- `Authenticated`: User is logged in. Contains `userData`.
- `Unauthenticated`: User is logged out or needs to log in.
- `AuthError`: Contains `Failure` object (instead of raw String).
