# Quickstart: Running Auth Tests

## 1. Prerequisites
Ensure you have the Flutter SDK installed and dependencies fetched:
```bash
flutter pub get
```

## 2. Running Unit Tests
Execute the auth unit tests (Repository, Cubit, DataSources):
```bash
flutter test test/features/auth/
```

## 3. Running with Coverage
To generate coverage reports:
```bash
flutter test --coverage test/features/auth/
# View report (on macOS/Linux)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 4. Test Structure
- `test/features/auth/data/repositories/auth_repository_impl_test.dart`
- `test/features/auth/presentation/bloc/auth_cubit_test.dart`
- `test/features/auth/data/datasources/auth_remote_data_source_test.dart`
- `test/features/auth/data/datasources/auth_local_data_source_test.dart`
