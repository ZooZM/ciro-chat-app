# Implementation Plan: Group Call UI Update

**Branch**: `[TBD]` | **Date**: 2026-06-03 | **Spec**: [group_call_ui_update.md](file:///c:/Users/user/Desktop/ciro-app/ciro-chat-app/specs/group_call_ui_update.md)
**Input**: Feature specification from `specs/group_call_ui_update.md`

## Summary

Implement UI refinements for the Group Call feature, including the incoming call screen, waiting for others screen, and the dynamic participant grid (handling up to 10 participants and overflow with a "+N others" tile). All static text will be integrated with `easy_localization`. Backend call logic is out of scope.

## Technical Context

**Language/Version**: Dart 3.x, Flutter
**Primary Dependencies**: `flutter_bloc` (state management), `easy_localization` (translations), `get_it` & `injectable` (DI)
**Storage**: N/A for this purely UI-focused update. (App uses `sqflite` per constitution, Hive is strictly forbidden)
**Testing**: `flutter_test`, `bloc_test` for UI logic and widget tests.
**Target Platform**: iOS, Android
**Project Type**: Mobile App Feature Update
**Performance Goals**: 60 fps for UI rendering, no layout overflows during grid size changes.
**Constraints**: Follow clean architecture (only touching the `presentation` layer for `call` feature). Follow `easy_localization` patterns exactly.
**Scale/Scope**: Handling dynamic 1-10+ active participants.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature updates are strictly contained within `presentation` layer.
- [x] **II. State Management**: Uses `flutter_bloc` (Cubit preferred). States extend `Equatable`.
- [x] **III. Offline-First**: No new data storage introduced; adhering to the ban on Hive.
- [x] **IV. Socket.io**: Real-time logic uses singleton `SocketService` (if needed for testing states, though backend logic is out of scope here).
- [x] **V. Teardown**: Proper `dispose` implemented for any new UI controllers.
- [x] **Code Quality**: Strict linting followed. Naming conventions met.
- [x] **Error Handling**: Not applicable for static UI update, but adherence maintained.

## Project Structure

### Documentation (this feature)

```text
specs/
├── group_call_ui_plan.md              # This file
├── group_call_ui_research.md          # Phase 0 output
├── group_call_ui_data-model.md        # Phase 1 output
└── group_call_ui_update.md            # The feature spec
```

### Source Code

Updates will be isolated to the existing `video_call` feature's presentation layer:
```text
lib/
└── features/
    └── video_call/
        └── presentation/
            ├── bloc/
            │   └── call_cubit.dart (if state needs +N others support)
            ├── pages/
            │   ├── incoming_group_call_screen.dart (Modify)
            │   └── group_call_screen.dart (Modify)
            └── widgets/
                ├── participant_grid.dart (New or Modify existing)
                └── call_controls.dart (New or Modify existing)
```

**Structure Decision**: Proceeding with standard Clean Architecture. We will modify the existing screen files to prevent duplication and respect the current project structure.
