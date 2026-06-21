# Research: Avatar-Based Video Call UI

## R-001: Where to place the new screens in the feature hierarchy

- **Decision**: Add the two new screens inside the existing `lib/features/video_call/presentation/pages/` directory.
- **Rationale**: The `video_call` feature already contains `incoming_call_screen.dart`, `voice_call_screen.dart`, `video_call_screen.dart`, `outgoing_call_screen.dart`, `incoming_group_call_screen.dart`, and `group_call_screen.dart`. The avatar-based variants are a UI-only addition within the same feature and share the same `CallCubit` dependency.
- **Alternatives considered**: Creating a new feature folder `avatar_call/`. Rejected because the screens are presentation-only variants of the same feature and splitting would break the existing DI and routing cohesion.

## R-002: Localization key pattern

- **Decision**: Use the existing `call_` prefix for new localization keys (e.g., `call_incoming_call`, `call_action_not_now`, `call_btn_camera`, `call_btn_end_call`). Reuse existing keys where applicable (`call_action_join`, `call_btn_mute`).
- **Rationale**: All call-related keys in `en.json` and `ar.json` already follow the `call_` prefix convention.
- **Alternatives considered**: Using a sub-namespace like `avatar_call_`. Rejected for consistency with existing flat key structure.

## R-003: Routing approach

- **Decision**: Add two new `GoRoute` entries in `app_router.dart` with named constants `avatarIncomingCall` and `avatarActiveCall`. Pass mock data via the `extra` parameter following the pattern of all existing call routes.
- **Rationale**: Every existing call screen uses `GoRoute` with `state.extra as Map<String, dynamic>`. The avatar screens follow the same pattern.
- **Alternatives considered**: Overlaying the new screens as modal dialogs. Rejected because the screenshots show full-screen layouts, and existing call screens are full-page routes.

## R-004: Mock data strategy for avatars

- **Decision**: Use `Container` with colored backgrounds and text initials (matching the existing `CircleAvatar` pattern in `incoming_call_screen.dart` and `voice_call_screen.dart`) as placeholder avatars. No external assets needed.
- **Rationale**: The spec explicitly requires mock data with simple colored containers; no actual avatar images or animations. Existing screens already use `CircleAvatar` with initials as a fallback.
- **Alternatives considered**: Using `Image.asset` with placeholder PNGs. Rejected as unnecessary complexity for mock-only screens.

## R-005: Responsive layout approach

- **Decision**: Use the existing `responsive.dart` extension methods (`.resW`, `.resH`, `.resR`) for all spacing and sizing, matching the pattern in `voice_call_screen.dart` and `incoming_call_screen.dart`.
- **Rationale**: Every existing call screen uses these responsive helpers. Consistency ensures the new screens scale correctly on all devices.

## R-006: Constitution compliance — no backend/WebRTC logic

- **Decision**: The new screens will accept callbacks (`VoidCallback`) for Join, Not Now, Mute, Camera, and End Call. They will not import `CallCubit`, `SocketService`, `livekit_client`, or any data layer. They are pure presentation widgets.
- **Rationale**: The spec FR-008 explicitly requires "strictly presentation-only (dumb widgets) using mock data, with no real WebRTC or backend logic wired up."
- **Alternatives considered**: Wiring directly to `CallCubit`. Rejected per the spec constraint — the user wants UI widgets only, to be connected later.
