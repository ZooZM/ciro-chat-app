# Data Model: Status Updates

## Entities

### `StatusEntity` (Domain)
```dart
class StatusEntity extends Equatable {
  final String id;
  final String authorName;
  final String authorAvatar; // URL, file path, or initials
  final DateTime timestamp;
  final DateTime expiresAt;
  final bool isViewed;
  final bool isMine; // True if created by the current user
  
  // ... constructor and props
}
```

### `StatusModel` (Data)
Extends `StatusEntity` and implements `fromJson`, `toJson`, `fromMap` (SQLite), and `toMap` (SQLite).

## SQLite Schema

### Table: `statuses`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | TEXT | PRIMARY KEY | Unique status identifier |
| `author_name` | TEXT | NOT NULL | Contact name |
| `author_avatar` | TEXT | | Avatar string |
| `timestamp` | INTEGER | NOT NULL | Epoch time of creation |
| `expires_at` | INTEGER | NOT NULL | Epoch time of expiration |
| `is_viewed` | INTEGER | NOT NULL | 0 for false, 1 for true |
| `is_mine` | INTEGER | NOT NULL | 0 for false, 1 for true |

*Index*: Create an index on `expires_at` to efficiently query and purge expired statuses.

## Contracts & Interfaces

### `StatusRepository` (Domain Interface)
```dart
abstract class StatusRepository {
  Future<Either<Failure, List<StatusEntity>>> getRecentStatuses();
  Future<Either<Failure, List<StatusEntity>>> getViewedStatuses();
  Future<Either<Failure, StatusEntity>> getMyStatus();
  Future<Either<Failure, void>> markAsViewed(String statusId);
  Future<Either<Failure, void>> addStatus(StatusEntity status);
  Stream<StatusEntity> get statusStream; 
  Future<void> purgeExpiredStatuses();
}
```

### `StatusLocalDataSource` (Data Interface)
```dart
abstract class StatusLocalDataSource {
  Future<List<StatusModel>> getStatuses({required bool isViewed});
  Future<StatusModel?> getMyStatus();
  Future<void> cacheStatus(StatusModel status);
  Future<void> markAsViewed(String statusId);
  Future<void> deleteExpiredStatuses();
}
```

### `StatusRemoteDataSource` (Data Interface)
```dart
abstract class StatusRemoteDataSource {
  Stream<StatusModel> get onStatusReceived;
  Future<void> uploadStatus(StatusModel status);
  Future<void> notifyViewed(String statusId);
}
```
