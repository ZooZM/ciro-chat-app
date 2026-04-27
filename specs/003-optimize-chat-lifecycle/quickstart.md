# Quickstart: Optimize Chat Lifecycle (Expanded)

**Date**: April 27, 2026

## Prerequisites

- Flutter SDK 3.x installed
- Android emulator or device connected
- NestJS backend running at configured URL
- `.env` file with `GOOGLE_MAPS_API_KEY` at project root

## New Dependencies to Add

```yaml
# pubspec.yaml — add if not already present
dependencies:
  video_player: ^2.8.0        # US12: Video message playback
  video_thumbnail: ^0.5.3     # US12: Generate video thumbnails
```

## Quick Implementation Order

1. **Phase A** (US11 — Waveform Cache): Modify `_VoiceBubble._preparePlayer()` to check/store waveform samples in metadata
2. **Phase B** (US12 — Video): Add `MessageType.video`, `_VideoBubble`, `sendVideoMessage()`, `MediaGalleryViewer`
3. **Phase C** (US13 — Resend): Add resend icon to error-status bubbles, `resendMessage()` to ChatCubit
4. **Phase D** (US14 — Block): Backend REST + socket guard, then frontend ChatCubit + ChatInfoScreen
5. **Phase E** (US15 — Search): `searchMessages()` in SQLite, `ChatSearchBar` widget, wire to menu
6. **Phase F** (US16 — ChatInfo): Wire quick actions, real media, block button, settings toggles
7. **Phase G** (US17 — Splash): Preload chat list during splash before navigating to home

## Verification

```bash
# Run static analysis
flutter analyze

# Check for remaining hardcoded values
grep -rn "Colors\." lib/features/chat/
grep -rn "Color(0x" lib/features/chat/

# Check for TODO/FIXME markers
grep -rn "TODO\|FIXME\|HACK\|XXX" lib/features/chat/
```

## Already Completed (Hotfixes)

- [x] C1: Audio crash on back-press — `PopScope` + skip `PlayerController.dispose()`
- [x] D1: Location crash — `LocationService` in `core/services/`
- [x] F1: ChatInfoScreen hardcoded colors — migrated to `AppColors`/`AppConstants`
