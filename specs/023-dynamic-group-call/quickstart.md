# Quickstart: Dynamic Group Call Screen

**Feature**: 023-dynamic-group-call  
**Date**: 2026-07-09  

## What This Feature Does

Adds a new "Dynamic Group Call Screen" to the video_call feature that displays a mock group call UI with adaptive layouts based on participant count. The screen uses a simple state variable (`participantCount`) to switch between:

- **P2P layout** (2 participants) — full-screen remote + floating PIP local
- **Tri-split layout** (3 participants) — top half + bottom half split
- **2-column grid** (4–6+ participants) — like the reference screenshot

All data is mocked. No WebRTC, Agora, or LiveKit logic is involved.

## Key Files

| File | Purpose |
|------|---------|
| `lib/features/video_call/presentation/pages/dynamic_group_call_screen.dart` | Main screen with layout logic |
| `lib/features/video_call/presentation/widgets/mock_participant_tile.dart` | Reusable participant cell widget |
| `lib/features/video_call/presentation/data/mock_call_participants.dart` | Mock data and model class |
| `lib/core/routing/app_router.dart` | New route registration |
| `assets/translations/en.json` | New localization keys |
| `assets/translations/ar.json` | New localization keys (Arabic) |

## How to Test

1. Navigate to the `dynamicGroupCall` route (or add a temporary button in the app).
2. The screen opens with `participantCount = 4` by default.
3. Change `_participantCount` in the source code to 2, 3, 4, 5, or 6 and hot-reload to verify each layout.
4. Verify participant cells show avatar mode (colored background) or video placeholder based on `isVideoOn`.
5. Check overlay badges: mute icon and speaking waveform icon appear correctly.
6. Confirm all text uses `easy_localization` keys (no hardcoded strings).

## Dependencies

- `easy_localization` (existing)
- `flutter_screenutil` (existing)
- `go_router` (existing)

No new dependencies required.
