# Quickstart: Status Creation Flow

## Prerequisites

- Flutter SDK 3.x installed
- All dependencies already in `pubspec.yaml` (no new packages needed)
- Backend endpoints available: `/status/upload`, `/music/tracks`, `/ai/generate-image`

## Quick Run

```bash
# Run on Chrome (web)
flutter run -d chrome --web-browser-flag "--disable-web-security"

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

## Key Entry Points

1. **Updates Screen** → Pencil/Camera FAB → `AddStatusBottomSheet`
2. **Add Status Bottom Sheet** → Chip selection → `StatusCreationScreen`
3. **Status Creation Screen** → Mode-specific editors (Text/Voice/Media)
4. **Music Selector** → Triggered from Music chip → `MusicSelectorSheet`
5. **AI Image Generator** → Triggered from AI Image chip → `AIImageGeneratorSheet`

## Architecture Overview

```
StatusCreationCubit (single source of truth for draft state)
├── TextStatusEditor
├── VoiceStatusEditor  
├── MediaStatusEditor
└── MusicCubit (separate cubit for music catalog)
```

## Testing

```bash
# Run all tests
flutter test

# Run status feature tests only
flutter test test/features/status/
```
