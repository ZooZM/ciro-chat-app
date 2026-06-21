# Quickstart: Avatar-Based Video Call UI

## What this feature adds

Two new Flutter presentation screens inside the existing `video_call` feature:

1. **`avatar_incoming_call_screen.dart`** — A full-screen incoming call UI with a large avatar, caller name, and Join/Not Now buttons.
2. **`avatar_active_call_screen.dart`** — A full-screen active call UI with a large remote avatar, a small PIP local avatar, and a bottom control bar (Mute, Camera, End Call).

Both screens are **pure presentation widgets** with no business logic, WebRTC, or backend wiring. They accept callbacks and mock data via constructor parameters.

## Files changed

### New Files
- `lib/features/video_call/presentation/pages/avatar_incoming_call_screen.dart`
- `lib/features/video_call/presentation/pages/avatar_active_call_screen.dart`

### Modified Files
- `lib/core/routing/app_router.dart` — Two new `GoRoute` entries + constants
- `assets/translations/en.json` — New localization keys
- `assets/translations/ar.json` — New localization keys (Arabic)

## How to test

1. Navigate to the new routes directly via `context.push(AppRouterName.avatarIncomingCall)` or `context.push(AppRouterName.avatarActiveCall)` with mock `extra` data.
2. Verify visual layout matches the reference screenshots.
3. Verify all text is localized (switch locale to Arabic and confirm).
4. Verify tapping buttons triggers the mock callbacks (print statements or snackbars in test harness).
