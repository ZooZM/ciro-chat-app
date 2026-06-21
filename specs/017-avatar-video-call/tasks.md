# Tasks: Avatar-Based Video Call UI

**Input**: Design documents from `/specs/017-avatar-video-call/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Not requested in the feature specification. Test tasks are omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Presentation Layer**: `lib/features/video_call/presentation/`
- **Routing**: `lib/core/routing/app_router.dart`
- **Translations**: `assets/translations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Localization keys and routing setup shared by both screens

- [x] T001 [P] Add new localization keys (`call_incoming_call`, `call_action_not_now`, `call_btn_camera`, `call_btn_end_call`) to `assets/translations/en.json`
- [x] T002 [P] Add corresponding Arabic localization keys to `assets/translations/ar.json`
- [x] T003 Register two new route constants (`avatarIncomingCall`, `avatarActiveCall`) and their `GoRoute` entries in `lib/core/routing/app_router.dart`

**Checkpoint**: Routes and localization keys are available. Both new screens can be navigated to (even if they are placeholder Scaffolds initially).

---

## Phase 2: User Story 1 — Incoming Call Screen (Priority: P1) 🎯 MVP

**Goal**: Display a full-screen incoming call screen with a large caller avatar, caller name, and Join / Not Now action buttons — all using localized text and mock data.

**Independent Test**: Navigate to `/avatar_incoming_call` with mock `extra` data and verify the layout renders correctly with avatar, name, and both buttons visible. Tap each button and confirm the callback fires.

### Implementation for User Story 1

- [x] T004 [US1] Create `AvatarIncomingCallScreen` widget in `lib/features/video_call/presentation/pages/avatar_incoming_call_screen.dart` with the following layout:
  - Full-screen `Scaffold` with themed coral/red background
  - Top info bar: small caller `CircleAvatar` + caller name + "Incoming call" localized label + speaker icon
  - Center: large `CircleAvatar` (~120px radius) with initials fallback or `CachedNetworkImage`
  - Bottom-left: small local user PIP avatar (green-tinted `Container` with initials)
  - Bottom action row: "Join" green rounded button + "Not Now" grey rounded button + expand chevron
  - All text via `easy_localization` keys: `call_action_join.tr()`, `call_action_not_now.tr()`, `call_incoming_call.tr()`
  - Constructor params: `callerName`, `callerAvatarUrl`, `onJoin` (`VoidCallback`), `onDecline` (`VoidCallback`)
  - Use `AppTypography`, `AppColors`, responsive extensions (`.resW`, `.resH`, `.resR`)
  - No imports from `call_cubit.dart`, `socket_service.dart`, or `livekit_client`

- [x] T005 [US1] Wire `AvatarIncomingCallScreen` into the `GoRoute` for `avatarIncomingCall` in `lib/core/routing/app_router.dart`, extracting `callerName` and `callerAvatarUrl` from `state.extra` and providing no-op callbacks for `onJoin` / `onDecline`

**Checkpoint**: User Story 1 is fully functional. Navigating to `/avatar_incoming_call` shows the complete incoming call screen with localized text and tappable buttons.

---

## Phase 3: User Story 2 — Active Call Screen (Priority: P1)

**Goal**: Display a full-screen active call screen with a large remote avatar, a small floating PIP local avatar, call duration, and a bottom control bar with Mute, Camera toggle, and End Call icons — all using localized text and mock data.

**Independent Test**: Navigate to `/avatar_active_call` with mock `extra` data and verify the layout renders correctly with both avatars, duration text, and all three control buttons visible. Tap each control button and confirm the callback fires.

### Implementation for User Story 2

- [x] T006 [US2] Create `AvatarActiveCallScreen` widget in `lib/features/video_call/presentation/pages/avatar_active_call_screen.dart` with the following layout:
  - Full-screen `Scaffold` with themed coral/red background
  - Top bar: down-chevron icon + small remote `CircleAvatar` + remote name + call duration text + speaker icon + red end-call circle icon
  - Center: large `CircleAvatar` (~100px radius) with initials fallback for remote user, inside a light circular background
  - Bottom-left: small local user PIP avatar (green-tinted `Container` with initials)
  - Center-bottom: large white outlined circle (camera shutter placeholder)
  - Bottom control bar: frosted/translucent row with 5 icon buttons — Camera Off (red highlight when active), Flip camera, Mic, Emoji, Share
  - All text via `easy_localization` keys: `call_btn_mute.tr()`, `call_btn_camera.tr()`, `call_btn_end_call.tr()`
  - Constructor params: `remoteName`, `remoteAvatarUrl`, `localAvatarUrl`, `localName`, `isMuted` (bool), `isCameraOff` (bool), `callDuration` (String), `onToggleMute` (`VoidCallback`), `onToggleCamera` (`VoidCallback`), `onEndCall` (`VoidCallback`), `onMinimize` (`VoidCallback?`)
  - Use `AppTypography`, `AppColors`, responsive extensions (`.resW`, `.resH`, `.resR`)
  - No imports from `call_cubit.dart`, `socket_service.dart`, or `livekit_client`

- [x] T007 [US2] Wire `AvatarActiveCallScreen` into the `GoRoute` for `avatarActiveCall` in `lib/core/routing/app_router.dart`, extracting all params from `state.extra` and providing no-op callbacks

**Checkpoint**: User Story 2 is fully functional. Navigating to `/avatar_active_call` shows the complete active call screen with localized text and tappable controls.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final layout tweaks and visual verification

- [x] T008 Verify responsive layout on small screens (iPhone SE, 320px width) — ensure avatars scale down and buttons don't overflow in both `avatar_incoming_call_screen.dart` and `avatar_active_call_screen.dart`
- [x] T009 Verify long caller name truncation with ellipsis in both screens
- [x] T010 [P] Run quickstart.md validation: navigate to both routes with mock data, switch locale to Arabic, confirm all text is localized

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **User Story 1 (Phase 2)**: Depends on T001, T002, T003 (localization keys + routes)
- **User Story 2 (Phase 3)**: Depends on T001, T002, T003 (localization keys + routes). Independent of US1.
- **Polish (Phase 4)**: Depends on both User Stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 1 — No dependency on User Story 2
- **User Story 2 (P1)**: Can start after Phase 1 — No dependency on User Story 1

### Within Each User Story

- Screen widget (T004/T006) before route wiring (T005/T007)

### Parallel Opportunities

- T001 and T002 (localization files) can run in parallel
- T004 and T006 (both screen widgets) can run in parallel after Phase 1 completes
- User Stories 1 and 2 can be worked on by different developers simultaneously

---

## Parallel Example: User Story 1 & 2 (after Phase 1)

```bash
# Launch both screen widgets in parallel (different files):
Task: "Create AvatarIncomingCallScreen in lib/features/video_call/presentation/pages/avatar_incoming_call_screen.dart"
Task: "Create AvatarActiveCallScreen in lib/features/video_call/presentation/pages/avatar_active_call_screen.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: User Story 1 (T004–T005)
3. **STOP and VALIDATE**: Navigate to `/avatar_incoming_call` with mock data
4. Confirm layout, localization, and button callbacks work

### Incremental Delivery

1. Complete Setup → Keys and routes ready
2. Add User Story 1 → Incoming Call screen testable → Demo (MVP!)
3. Add User Story 2 → Active Call screen testable → Demo
4. Polish → Responsive + truncation + locale checks → Done

### Parallel Team Strategy

With two developers:

1. Both complete Phase 1 together (3 small tasks)
2. Once Phase 1 is done:
   - Developer A: User Story 1 (T004–T005)
   - Developer B: User Story 2 (T006–T007)
3. Both complete and merge independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- CRITICAL: No imports from `call_cubit.dart`, `socket_service.dart`, or `livekit_client` in any new file
