# Implementation Plan: Optimize Chat Lifecycle

**Branch**: `003-optimize-chat-lifecycle` | **Date**: April 24, 2026 | **Spec**: [specs/003-optimize-chat-lifecycle/spec.md](spec.md)
**Input**: Feature specification from `/specs/003-optimize-chat-lifecycle/spec.md`

## Summary

Optimize the Chat feature by strictly aligning with the `AGENT_CHAT_LIFECYCLE.md`, refactoring `ChatCubit` and `SocketService` to prevent unnecessary UI rebuilds, and implementing a distinct Call State (Voice/Video) that acts as an overlay to avoid interrupting P2P text flow.

## Technical Context

**Language/Version**: Dart 3 / Flutter  
**Primary Dependencies**: flutter_bloc, get_it, injectable, sqflite, hive, socket.io-client  
**Storage**: SQLite for relational data, Hive for fast KV  
**Testing**: flutter_test, bloc_test  
**Target Platform**: iOS/Android  
**Project Type**: mobile-app  
**Performance Goals**: 60 fps, targeted UI rebuilds during real-time socket updates  
**Constraints**: Offline-capable, strict clean architecture, replace all hardcoded values with `lib/core/` constants  
**Scale/Scope**: Refactoring existing ChatCubit and SocketService, adding Call Overlay

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
specs/003-optimize-chat-lifecycle/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

lib/
├── core/
│   ├── bloc/
│   ├── di/
│   ├── helpers/
│   ├── network/
│   ├── routing/
│   └── theme/
└── features/
    └── chat/
        ├── data/
        │   ├── datasources/
        │   ├── models/
        │   └── repositories/
        ├── domain/
        │   ├── entities/
        │   └── repositories/
        └── presentation/
            ├── bloc/
            ├── pages/
            └── widgets/

test/
└── features/
    └── chat/

**Structure Decision**: Utilizing existing `chat` feature directory under `lib/features/chat/`, with calls managed via a global overlay wrapper communicating with `SocketService`.
