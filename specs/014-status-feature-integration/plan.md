# Implementation Plan: Status Feature Backend & Logic Integration

**Branch**: `014-status-feature-integration` | **Date**: 2026-06-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/014-status-feature-integration/spec.md`

## Summary

The Status (ephemeral "stories") UI already exists on the Flutter client (specs
004-status-updates, 005-status-creation-flow) but is backed only by local SQLite
and mocked network calls. This feature adds the missing server-side capability in
the NestJS backend (`chat-app-backend`) - a new `StatusModule` with a Mongo-backed
`Status` collection (24h TTL), persisted per-user contact lists for mutual-contact
visibility, persisted default "Private" audiences, access-controlled media, and
real-time delivery via the existing chat Socket.IO gateway - and wires the existing
Flutter screens to it via the data/business logic layers only (no UI changes).
Status replies are delivered as regular 1:1 chat messages tagged with a status
reference, reusing the existing `clientMessageId`-style idempotency pattern for
offline-queued status posts.

## Technical Context

**Language/Version**: Dart 3 / Flutter (frontend, this repo); TypeScript 5 / Node.js 20 with NestJS 10 (backend, `chat-app-backend`)
**Primary Dependencies**: `flutter_bloc` (Cubit), `fpdart`, `injectable`/`get_it`, `sqflite`, `socket_io_client`, `dio`, `cached_network_image`, `video_player` (frontend); `@nestjs/mongoose`, `@nestjs/websockets` (Socket.IO), `@nestjs/jwt`, `@nestjs/platform-express` (Multer), `class-validator` (backend)
**Storage**: MongoDB (new `statuses` collection with TTL index for FR-008; `users` collection extended with persisted synced-contact list and default "Private" audience) + sqflite on-device (`statuses` table extended for offline queue + audience cache)
**Testing**: `flutter_test` / `bloc_test` for Cubit and repository unit tests (frontend); Jest `*.spec.ts` for service/gateway unit tests (backend), following existing `chat.service.spec.ts` / `chat.gateway.spec.ts` patterns
**Target Platform**: iOS 15+ / Android (Flutter app); Linux server (NestJS backend)
**Project Type**: mobile-app + web-service (two sibling repositories: this Flutter repo and `chat-app-backend`)
**Performance Goals**: New status visible to permitted contacts within 5s (SC-001); new viewer/reaction/reply visible to author within 5s (SC-004/SC-005); offline posts delivered within 30s of reconnect (SC-006)
**Constraints**: Status (+ views/reactions/replies/media) MUST become inaccessible exactly 24h after creation (FR-008) - implemented via MongoDB TTL index; status media MUST be access-controlled, not plain `/uploads/<uuid>` (FR-007); existing Status Updates/Creation screens MUST require zero visual changes (SC-007)
**Scale/Scope**: Adds one backend module (`status`), extends `users` and `chat` (message schema + gateway) modules, and extends the existing `lib/features/status/` Flutter feature - no new screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: `lib/features/status/` already follows `data/domain/presentation`; only existing files within those layers are extended (datasources, models, repository, cubit). No new layers introduced. Backend `status` module mirrors the existing `chat`/`users` module structure (controller/service/repository/schema), consistent with this codebase's NestJS conventions.
- [x] **II. State Management**: `StatusCubit` (Cubit, already extends `Equatable` via `StatusState`) is extended, not replaced. New states/fields follow the existing `copyWith` pattern.
- [x] **III. Offline-First**: The existing `statuses` sqflite table remains the UI's data source. New columns support the offline queue (FR-016) and cached default audience (FR-017). No Hive introduced.
- [x] **IV. Socket.IO**: Real-time status events (`uploadStatus`, `statusViewed`, `statusReceived`, plus new `statusReacted`/`statusReplied`/`statusViewerAdded`) are added to the existing singleton `ChatGateway`/`SocketService`, reusing `activeSockets` and the authenticated-socket pattern. All payloads are deduplicated via `clientStatusId` (mirrors `clientMessageId`). New Dart socket handlers follow the `Map<String, dynamic>.from(data)` rule (IV-A).
- [x] **V. Teardown**: New `StreamSubscription`s added to `StatusCubit`/`SocketService` are cancelled in `close()`/`dispose()` alongside the existing `_statusSubscription` and `_expiryTimer`.
- [x] **Code Quality**: New Dart files use `snake_case` naming and `flutter_lints`-clean code; new TS files follow existing `chat-app-backend` ESLint/Prettier config.
- [x] **Error Handling**: New repository methods return `Either<Failure, T>` using existing `ServerFailure`/`CacheFailure`; backend service methods throw Nest `HttpException` subclasses mapped by the existing `GlobalExceptionFilter`.

No violations. Complexity Tracking table not required.

## Project Structure

### Documentation (this feature)

```text
specs/014-status-feature-integration/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── status-rest-api.md
│   └── status-socket-events.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

This feature spans two sibling repositories.

**Frontend** (`/Volumes/Zeyad/Documents/work/Flutter/ciro-chat-app`, this repo - extended only):

```text
lib/
├── core/
│   └── network/
│       ├── socket_service.dart        # extend: new status socket events (typed callbacks)
│       └── socket_events.dart         # extend: new event name constants
└── features/
    └── status/
        ├── data/
        │   ├── datasources/
        │   │   ├── status_remote_data_source.dart   # extend: feed/viewers/audience endpoints
        │   │   └── status_local_data_source.dart    # extend: offline queue, default audience cache
        │   ├── models/
        │   │   ├── status_model.dart                # extend: clientStatusId, audience, viewer/reaction lists
        │   │   └── status_viewer_model.dart          # new
        │   └── repositories/
        │       └── status_repository_impl.dart      # extend
        ├── domain/
        │   ├── entities/
        │   │   ├── status_entity.dart                # extend: clientStatusId, audience
        │   │   └── status_viewer.dart                # new
        │   └── repositories/
        │       └── status_repository.dart            # extend interface
        └── presentation/
            └── bloc/
                ├── status_cubit.dart                  # extend
                └── status_state.dart                  # extend

test/features/status/   # mirrors structure above
```

**Backend** (`/Volumes/Zeyad/Documents/work/Node js/chat-app-backend`, sibling repo - new module + extensions):

```text
src/
├── modules/
│   ├── status/                          # NEW module
│   │   ├── dto/
│   │   │   ├── create-status.dto.ts
│   │   │   ├── react-status.dto.ts
│   │   │   ├── reply-status.dto.ts
│   │   │   └── set-default-audience.dto.ts
│   │   ├── schemas/
│   │   │   └── status.schema.ts
│   │   ├── status.controller.ts
│   │   ├── status.service.ts
│   │   ├── status.repository.ts
│   │   └── status.module.ts
│   ├── users/
│   │   ├── schemas/user.schema.ts       # extend: syncedContacts[], defaultStatusAudience[]
│   │   ├── users.repository.ts          # extend: persist contacts, mutual-contact query
│   │   └── users.service.ts             # extend
│   └── chat/
│       ├── schemas/message.schema.ts    # extend: optional statusRef
│       ├── chat.gateway.ts              # extend: status socket events
│       └── chat.module.ts               # import StatusModule
└── main.ts                              # extend: authenticated status-media route (alongside /uploads)

test/  # *.spec.ts mirrors structure above
```

**Structure Decision**: No new top-level directories. The Flutter side stays
entirely within the existing `lib/features/status/` Clean Architecture layout
(per Constitution I); the backend side adds one new sibling module
(`src/modules/status/`) following the same controller/service/repository/schema
shape as `src/modules/chat/` and `src/modules/users/`, and extends those two
existing modules where the new capability is inseparable from them (contact
persistence on `User`, status replies and real-time delivery via `chat`).

## Complexity Tracking

> No Constitution Check violations - table not required.
