# Research: Auth Feature Audit for Testing

## Findings

### 1. AuthCubit Implementation Audit
- **State Transitions**: Emits `AuthLoading`, `Authenticated`, `Unauthenticated`, and `AuthError`.
- **Dependencies**: 
    - `AuthRepository` (Mocking target)
    - `AuthLocalDataSource` (Mocking target)
    - `SocketService` (via `getIt` - Mocking target)
    - `ChatCubit` (via `getIt` - Mocking target)
    - `CallCubit` (via `getIt` - Mocking target)
    - `ChatLocalDataSource` (via `getIt` - Mocking target)
- **Observations**: 
    - `verifyAuthStatus` has a hardcoded `Duration(seconds: 2)` delay which will slow down tests unless mocked or handled.
    - Extensive use of `getIt` for cross-cubit/service communication, requiring registration of mocks in `getIt` during test setup.
    - Error handling uses `try-catch` and emits `AuthError(e.toString())`, which is loose compared to the Constitution's `Either<Failure, T>` recommendation.

### 2. AuthRepository Implementation Audit
- **Location**: `lib/features/auth/data/repositories/auth_repository_impl.dart`.
- **Dependencies**: `AuthRemoteDataSource`, `AuthLocalDataSource`.
- **Current Status**: Does **not** return `Either<Failure, T>`. It throws `Exception` on error.
- **Refactoring Requirement**: MUST refactor to return `Either<Failure, T>` using `fpdart` as per Constitution.

### 3. Data Sources Audit
- **RemoteDataSource**: Uses `DioClient`. Needs mocking of `Dio` or `DioClient`.
- **LocalDataSource**: Uses `FlutterSecureStorage`. Needs mocking of `FlutterSecureStorage`.

### 4. Identified Bugs/Risks
- **Bug 1**: `AuthRepositoryImpl.verifyOtp` throws raw `Exception` with diagnostic strings. This leaks implementation details and doesn't follow the `Failure` pattern.
- **Bug 2**: `AuthCubit` catches all exceptions and calls `toString()`. This loses type safety on errors.
- **Bug 3**: `AuthCubit` manually manages `SocketService`, `ChatCubit`, etc., in `logOut`. Failure in one step might leave the system in a partial logout state.

## Decisions

- **Decision 1**: Refactor `AuthRepository` to use `Either<Failure, T>` BEFORE writing full unit tests.
- **Decision 2**: Use `mocktail` for all dependency mocking.
- **Decision 3**: Mock `getIt` singletons using `getIt.registerLazySingleton<T>(() => mockT)`.
- **Decision 4**: Introduce domain `Failure` classes in `lib/core/error/failures.dart` if not already present.

## Alternatives Considered

- **Mockito**: Rejected in favor of `mocktail` for its better handling of type-safe argument matching without code generation.
- **Dartz**: Rejected in favor of `fpdart` as it is more modern and better maintained in the Flutter ecosystem.
