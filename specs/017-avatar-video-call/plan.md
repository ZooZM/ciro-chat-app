# Implementation Plan: Avatar-Based Video Call UI

**Branch**: `016-p2p-call-motion` | **Date**: 2026-06-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/017-avatar-video-call/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Build two new presentation-only Flutter screens — an **Incoming Call** screen and an **Active Call** screen — that use avatar placeholders instead of live video feeds. The screens match the layout from the reference screenshots, use `easy_localization` for all text, follow the app's theme/branding, and contain zero backend or WebRTC logic. They slot into the existing `video_call` feature folder and are registered as new GoRouter routes.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: `flutter_bloc`, `easy_localization`, `go_router`, `google_fonts`, `flutter_screenutil`  
**Storage**: N/A — no data persistence in this feature  
**Testing**: Manual visual verification; widget tests possible  
**Target Platform**: iOS, Android (responsive via `flutter_screenutil`)  
**Project Type**: Mobile app (Flutter)  
**Performance Goals**: 60fps rendering, no jank on avatar screens  
**Constraints**: UI-only — no WebRTC, no `livekit_client`, no `SocketService`  
**Scale/Scope**: 2 new screens, ~4 new localization keys, 2 new routes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature lives in `presentation/pages/` within the existing `video_call` feature. No business logic in widgets — callbacks only.
- [x] **II. State Management**: No new Cubit needed. Screens are stateless (or minimal local state for toggle icons). Future wiring will use existing `CallCubit`.
- [x] **III. Offline-First**: N/A — no data storage or network calls in this feature.
- [x] **IV. Socket.io**: N/A — no socket events. Screens are pure presentation.
- [x] **V. Teardown**: No subscriptions, controllers, or timers to dispose. `StatelessWidget` or simple `StatefulWidget` with no async resources.
- [x] **Code Quality**: Files use `snake_case`. Strict linting. `const` constructors where possible.
- [x] **Error Handling**: N/A — no data layer or repository calls.

## Project Structure

### Documentation (this feature)

```text
specs/017-avatar-video-call/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
lib/features/video_call/
├── presentation/
│   ├── pages/
│   │   ├── avatar_incoming_call_screen.dart    [NEW]
│   │   ├── avatar_active_call_screen.dart      [NEW]
│   │   ├── incoming_call_screen.dart           (existing)
│   │   ├── voice_call_screen.dart              (existing)
│   │   ├── video_call_screen.dart              (existing)
│   │   ├── outgoing_call_screen.dart           (existing)
│   │   ├── incoming_group_call_screen.dart      (existing)
│   │   └── group_call_screen.dart              (existing)
│   ├── bloc/
│   │   └── call_cubit.dart                     (existing — NOT modified)
│   └── widgets/
│       └── (existing widgets — NOT modified)

lib/core/routing/
└── app_router.dart                              [MODIFIED — 2 new routes]

assets/translations/
├── en.json                                      [MODIFIED — new keys]
└── ar.json                                      [MODIFIED — new keys]
```

**Structure Decision**: New screens go inside the existing `video_call/presentation/pages/` directory. This is the established pattern for all call-related screens. No new feature folder needed.

## Detailed File Changes

### [NEW] `avatar_incoming_call_screen.dart`

**Layout** (matching Screenshot 1):
- Full-screen `Scaffold` with app theme background (coral/red tint adapted to brand)
- Top bar: small caller avatar + caller name + "Incoming call" label + speaker icon
- Center: large `CircleAvatar` (120–160px radius) with initials or `CachedNetworkImage`
- Bottom-left: small local user PIP avatar (green-tinted `Container`)
- Bottom action row: "Join" (green rounded button) + "Not Now" (grey rounded button) + expand chevron
- All text: `easy_localization` keys (`call_action_join`, `call_action_not_now`, `call_incoming_call`)
- Constructor: `callerName`, `callerAvatarUrl`, `onJoin`, `onDecline` callbacks

### [NEW] `avatar_active_call_screen.dart`

**Layout** (matching Screenshot 2):
- Full-screen `Scaffold` with app theme background
- Top bar: chevron icon + small remote avatar + remote name + call duration + speaker icon + end call icon
- Center: large `CircleAvatar` for remote user
- Bottom-left: small local PIP avatar (green-tinted `Container`)
- Center-bottom: large white circle (camera shutter / snap button placeholder)
- Bottom control bar: 5 icon buttons in a frosted row — Camera Off (red highlight), Flip camera, Mic, Emoji, Share
- Constructor: `remoteName`, `remoteAvatarUrl`, `localAvatarUrl`, `localName`, `isMuted`, `isCameraOff`, `callDuration`, callbacks

### [MODIFY] `app_router.dart`

- Add `static const String avatarIncomingCall = '/avatar_incoming_call';`
- Add `static const String avatarActiveCall = '/avatar_active_call';`
- Add two `GoRoute` entries following existing patterns (extract `extra` map, pass to widget constructors)

### [MODIFY] `en.json`

Add keys:
```json
"call_incoming_call": "Incoming call",
"call_action_not_now": "Not Now",
"call_btn_camera": "Camera",
"call_btn_end_call": "End Call"
```

### [MODIFY] `ar.json`

Add corresponding Arabic translations:
```json
"call_incoming_call": "مكالمة واردة",
"call_action_not_now": "ليس الآن",
"call_btn_camera": "كاميرا",
"call_btn_end_call": "إنهاء"
```

## Complexity Tracking

No constitution violations. No complexity justifications needed.
