# Implementation Plan: Status Updates Screen

## Summary
Implement the Status Updates screen in the Flutter application following Clean Architecture, strict offline-first principles (SQLite caching), and real-time Socket.io updates, exactly matching the provided `image_0.png` design.

## Proposed Changes

### Domain Layer (`lib/features/status/domain/`)
#### [NEW] `entities/status_entity.dart`
Define `StatusEntity` with properties: `id`, `authorName`, `authorAvatar`, `timestamp`, `expiresAt`, `isViewed`, `isMine`.

#### [NEW] `repositories/status_repository.dart`
Define abstract interface for `StatusRepository`.

### Data Layer (`lib/features/status/data/`)
#### [NEW] `models/status_model.dart`
Data transfer object extending `StatusEntity` with JSON and SQLite mapping methods.

#### [NEW] `datasources/status_local_data_source.dart`
Implement SQLite queries for creating the `statuses` table, inserting statuses, retrieving viewed vs unviewed statuses, and purging expired statuses (older than 24 hours).

#### [NEW] `datasources/status_remote_data_source.dart`
Implement Socket.io listeners for incoming statuses and API calls for uploading new statuses.

#### [NEW] `repositories/status_repository_impl.dart`
Implementation that coordinates between local and remote data sources, prioritizing SQLite for immediate loads and syncing with the remote source.

### Presentation Layer (`lib/features/status/presentation/`)
#### [NEW] `bloc/status_cubit.dart`
Implement `StatusCubit` and `StatusState`.
- Manages states: `Loading`, `Loaded(recent, viewed, myStatus, filteredRecent, filteredViewed)`, `Error`.
- Methods: `loadStatuses()`, `searchStatuses(query)`, `markAsViewed(id)`, `purgeExpired()`.

#### [NEW] `pages/updates_screen.dart`
Build the main UI layout matching the design exactly:
- `Scaffold` with custom styling.
- `AppBar` (or custom header) with "Updates" title and Search Bar.
- `ListView` with sections: "Status", "Recent status", and "Status that were presented".
- Two Floating Action Buttons (`Pencil` and `Camera`) positioned vertically.

#### [NEW] `widgets/status_tile.dart`
Custom list tile for rendering an individual status, featuring a custom `CircularAvatar` with an active/inactive status ring (green for recent, grey for viewed).

#### [NEW] `widgets/status_search_bar.dart`
A customized search bar styled exactly like the design.

### Core & Navigation
#### [MODIFY] `lib/main.dart` or Routing file
Register the `StatusCubit` and route for `UpdatesScreen`. Connect it to the existing Bottom Navigation Bar's "Updates" tab.

#### [MODIFY] `lib/core/services/database_helper.dart` (if applicable)
Add the table creation query for the `statuses` table.

## Verification Plan
### Automated Tests
- Write unit tests for `StatusCubit` to verify offline-loading, filtering, and state transitions.
- Write unit tests for `StatusLocalDataSource` to verify SQLite CRUD operations and expiration purging.

### Manual Verification
- Open the Updates tab and verify the layout matches `image_0.png` precisely.
- Tap a recent status, return, and verify it moves to the "presented" list.
- Disconnect internet, restart app, and verify statuses load instantly from SQLite.
- Type in the search bar and verify list filters correctly.
- Set device time 25 hours ahead and verify expired statuses are purged from the UI and DB.
