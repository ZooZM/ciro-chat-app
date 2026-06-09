# Implementation Plan: Map UI (Google Maps Update)

**Branch**: `013-map-ui` | **Date**: 2026-06-09 | **Spec**: [spec.md](file:///C:/Users/user/Desktop/ciro-app/ciro-chat-app/specs/013-map-ui/spec.md)
**Input**: Feature specification from `/specs/013-map-ui/spec.md`

## Summary

Migrate the existing custom OSM `flutter_map` implementation to `google_maps_flutter`, revert the navigation to use the existing bottom navigation bar instead of a custom one, and update the map screen controls so the first FAB toggles between Satellite and Normal map types.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x
**Primary Dependencies**: `google_maps_flutter`, `flutter_bloc`, `easy_localization`
**Storage**: N/A (Mock data only)
**Testing**: Flutter widget tests (if applicable)
**Target Platform**: Android, iOS
**Project Type**: Mobile Application
**Performance Goals**: Smooth 60fps scrolling and map panning
**Constraints**: UI-ONLY implementation. No actual backend. Maps must be populated with mock markers.
**Scale/Scope**: Single feature module (Map Screen) interacting with existing routing.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [X] **I. Clean Architecture**: Feature is split into `presentation`, `domain`, and `data` layers? (UI only, so `presentation` and `mock`)
- [X] **II. State Management**: Uses `flutter_bloc` (Cubit preferred)? States extend `Equatable`?
- [X] **III. Offline-First**: N/A for this UI-only phase
- [X] **IV. Socket.io**: N/A for this UI-only phase
- [X] **V. Teardown**: Proper `dispose`/`cancel` implemented?
- [X] **Code Quality**: Strict linting followed? Naming conventions (snake_case files) met?
- [X] **Error Handling**: N/A for UI-only phase

## Project Structure

### Documentation (this feature)

```text
specs/013-map-ui/
├── plan.md
├── research.md
├── data-model.md
└── tasks.md
```

### Source Code

```text
lib/features/map/
├── presentation/
│   ├── bloc/
│   │   ├── map_cubit.dart
│   │   └── map_state.dart
│   ├── mock/
│   │   └── map_mock_data.dart
│   ├── pages/
│   │   └── map_screen.dart
│   └── widgets/
│       ├── map_avatar_marker.dart
│       ├── map_top_bar.dart
│       ├── map_fab_column.dart
│       ├── map_filter_sheet.dart
│       └── user_details_sheet.dart
```

**Structure Decision**: Will reuse the existing `MapCubit` but update `MapState` to track `MapType` (normal vs satellite) and refactor `MapScreen` to use `GoogleMap` instead of `FlutterMap`.

## Complexity Tracking

No constitution violations.
