# Implementation Plan: 023-dynamic-group-call

**Branch**: `023-dynamic-group-call` | **Date**: 2026-07-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/023-dynamic-group-call/spec.md`

## Summary

Implement a "Dynamic Group Call Screen" UI that adapts its layout based on the number of participants. It re-uses standard P2P for 2 participants, uses a split layout for 3, and a 2-column grid for 4-6+. The UI handles "Video Stream" and "Avatar Mode" states, includes mute/speaker badges, uses `easy_localization` for all text, and relies entirely on mock data for rendering to allow manual testing of layout transitions.

## Technical Context

**Language/Version**: Dart (Flutter)
**Primary Dependencies**: `easy_localization`
**Storage**: N/A (Mock data only)
**Testing**: Flutter Widget Tests
**Target Platform**: iOS, Android
**Project Type**: Mobile App
**Performance Goals**: 60 fps during layout transitions
**Constraints**: Mock data ONLY. No WebRTC/Agora logic. Smooth rounded corners and vibrant colors.
**Scale/Scope**: Single self-contained UI screen with 1-6+ mock participants.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature is split into `presentation`, `domain`, and `data` layers? (UI only, goes in `presentation`)
- [x] **II. State Management**: Uses `flutter_bloc` (Cubit preferred)? States extend `Equatable`? (Using simple `StatefulWidget` or Cubit for the mock `participantCount` state)
- [x] **III. Offline-First**: Relational data uses `sqflite`? Key-value uses `Hive`? (N/A - mock data)
- [x] **IV. Socket.io**: Real-time logic uses singleton `SocketService`? Events are idempotent? (N/A)
- [x] **V. Teardown**: Proper `dispose`/`cancel` implemented? Logout sequence handled? (N/A - no streams)
- [x] **Code Quality**: Strict linting followed? Naming conventions (snake_case files) met? (Yes)
- [x] **Error Handling**: Exceptions mapped to `Failure` classes in Data layer? (N/A)

## Project Structure

### Documentation (this feature)

```text
specs/023-dynamic-group-call/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

lib/
└── features/
    └── video_call/
        └── presentation/
            ├── pages/
            │   └── dynamic_group_call_screen.dart
            └── widgets/
                └── mock_participant_tile.dart

**Structure Decision**: Will place the UI code within the existing `video_call` feature under `presentation/pages` and `presentation/widgets`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
