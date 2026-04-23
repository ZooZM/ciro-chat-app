# Implementation Plan: Add Group Chat

**Branch**: `002-add-group-chat` | **Date**: 2026-04-23 | **Spec**: [specs/002-add-group-chat/spec.md](spec.md)
**Input**: Feature specification from `/specs/002-add-group-chat/spec.md` and `group_chat_implementation_guide.md`

## Summary

Implement Group Chat functionality by extending the existing `ChatRoom` entity and integrating new REST endpoints for group lifecycle management (create, add, remove, leave). The feature will leverage the existing Socket.io infrastructure for real-time messaging, typing indicators, and read receipts, with UI updates to differentiate group chats and manage participants.

## Technical Context

**Language/Version**: Dart (Flutter SDK ^3.9.2)
**Primary Dependencies**: `flutter_bloc`, `equatable`, `get_it`, `injectable`, `dio`, `fpdart`
**Storage**: `sqflite` (relational - ChatRoom/Messages), `hive` (key-value)
**Testing**: `flutter_test`, `bloc_test`, `mocktail` (if requested later)
**Target Platform**: Mobile (iOS/Android)
**Project Type**: Mobile App
**Performance Goals**: Instant UI updates via optimistic updates or socket acknowledgements.
**Constraints**: Must strictly follow Clean Architecture and Offline-First principles (store groups in SQLite).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature is split into `presentation`, `domain`, and `data` layers?
- [x] **II. State Management**: Uses `flutter_bloc` (Cubit preferred)? States extend `Equatable`?
- [x] **III. Offline-First**: Relational data uses `sqflite`? Key-value uses `Hive`?
- [x] **IV. Socket.io**: Real-time logic uses singleton `SocketService`? Events are idempotent?
- [x] **V. Teardown**: Proper `dispose`/`cancel` implemented? Logout sequence handled?
- [x] **Code Quality**: Strict linting followed? Naming conventions (snake_case files) met?
- [x] **Error Handling**: Exceptions mapped to `Failure` classes in Data layer?

## Project Structure

### Documentation (this feature)

```text
specs/002-add-group-chat/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

lib/
├── core/
│   ├── network/
│   │   └── socket_service.dart
│   └── error/
│       └── failures.dart
└── features/
    └── chat/
        ├── data/
        │   ├── datasources/
        │   │   ├── chat_remote_data_source.dart
        │   │   └── chat_local_data_source.dart
        │   ├── models/
        │   │   └── chat_room_model.dart
        │   └── repositories/
        │       └── chat_repository_impl.dart
        ├── domain/
        │   ├── entities/
        │   │   └── chat_room.dart
        │   └── repositories/
        │       └── chat_repository.dart
        └── presentation/
            ├── bloc/
            │   └── chat_cubit.dart
            ├── pages/
            │   ├── chat_list_page.dart
            │   ├── chat_detail_page.dart
            │   ├── create_group_page.dart
            │   └── group_info_page.dart
            └── widgets/
                ├── chat_bubble.dart
                └── group_participant_tile.dart

test/
└── features/
    └── chat/

**Structure Decision**: The Group Chat feature will be integrated into the existing `chat` feature module rather than creating a completely isolated `group_chat` feature, as it shares significant models (`ChatRoom`, `Message`), repositories, and UI components (chat lists, bubbles).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | Project strictly adheres to Constitution | N/A |
