<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0
- List of modified principles:
  - Redined Principles I-VII to exactly match speckit.constitution structure and rules.
- Added sections:
  - Feature Folder Structure Template
- Templates requiring updates:
  - ✅ updated: .specify/templates/plan-template.md
  - ✅ updated: .specify/templates/spec-template.md
  - ✅ updated: .specify/templates/tasks-template.md
- Follow-up TODOs: None.
-->

# Ciro Chat App Constitution

This document serves as the absolute source of truth for the architectural, structural, and behavioral patterns within the Ciro Chat App codebase. All AI assistants and human developers MUST adhere strictly to these rules.

## Core Principles

### I. Strict Clean Architecture
The project strictly enforces a Clean Architecture approach to ensure separation of concerns, testability, and independence from UI or frameworks. Each feature must be encapsulated within its own directory and strictly divided into three layers:
- **Presentation Layer** (`presentation/`): Contains UI elements (`pages/`, `widgets/`) and BLoC (`bloc/`). Widgets MUST NOT contain business logic.
- **Domain Layer** (`domain/`): Contains `entities/` and abstract `repositories/`. MUST NOT have dependencies on Flutter, external packages (except `equatable`), or other layers.
- **Data Layer** (`data/`): Contains `models/`, `datasources/` (local/remote), and repository implementations.

#### Feature Folder Structure Template
```text
lib/
  core/
    error/
    network/
    theme/
    utils/
  features/
    [feature_name]/
      data/
        datasources/
        models/
        repositories/
      domain/
        entities/
        repositories/
      presentation/
        bloc/
        pages/
        widgets/
```

### II. State Management: STRICTLY flutter_bloc (Cubit)
- **Cubit over Bloc**: Use `Cubit` unless complex stream transformations (debounce/throttle) require `Bloc`.
- **State Classes**: MUST extend `Equatable`.
- **Single Responsibility**: Each Cubit manages a single feature or logical UI component.
- **Dependency Injection**: Dependencies MUST be received via constructor injection (using `get_it` and `injectable`).

### III. Data Storage: Offline-First Approach
The app must function seamlessly without a network connection.
- **SQLite (sqflite)**: Strictly for relational, heavily queried data (Messages, Rooms, Contacts).
- **Hive**: Strictly for fast key-value pairs and secure document storage (Preferences, Tokens).
- **Offline Queue**: Write operations performed while offline MUST be saved locally with `pending` status and queued for synchronization.

### IV. Real-Time Communication: Socket.io
- **Single Connection**: Managed by a singleton `SocketService`.
- **Lifecycle Awareness**: Connect upon authentication; strictly disconnect upon logout/expiration.
- **Event Delegation**: Service exposes Streams/callbacks; MUST NOT contain UI or business logic.
- **Idempotency**: Frontend MUST handle duplicate events gracefully.

### V. Memory Leak Prevention & Logout Teardown
- **Subscriptions**: ALL `StreamSubscription` MUST be explicitly `.cancel()`ed in `close()` or `dispose()`.
- **Controllers**: All controllers (`TextEditingController`, `ScrollController`, etc.) MUST be disposed.
- **Async Gap Safety**: Always check `if (!mounted) return;` before calling `setState` or using `context` after an async operation.
- **Global Logout**: MUST sever WebSocket, cancel all Streams/Timers, purge local data (Hive/SQLite), and reset singleton Cubits.

### VI. Code Formatting & Dart Lints
- **Strict Linting**: Use `flutter_lints`; all warnings are treated as errors.
- **Immutability**: Prefer `const` constructors and `final` variables.
- **Naming**: `PascalCase` for classes, `camelCase` for methods/variables, `snake_case` for files/folders.

### VII. Error Handling
- **Structured Errors**: Data layer MUST catch exceptions and map them to domain `Failure` classes.
- **Return Types**: Repositories should return `Either<Failure, Type>` (using `fpdart` or `dartz`).
- **User Feedback**: Presentation layer listens for error states and displays user-friendly SnackBars/Dialogs.

## Governance
This Constitution supersedes all other practices. Amendments require documentation and approval. All PRs and reviews must verify compliance with these principles.

**Version**: 1.1.0 | **Ratified**: 2026-04-23 | **Last Amended**: 2026-04-23
