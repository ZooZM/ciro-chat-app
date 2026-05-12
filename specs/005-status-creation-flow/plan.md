# Implementation Plan: Status Creation Flow

**Branch**: `005-status-creation-flow` | **Date**: May 12, 2026 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/005-status-creation-flow/spec.md`

## Summary

Implement the complete Status Creation Flow for the Ciro Chat App — a multi-modal status composer supporting Text (with background colors & fonts), Voice recording (with waveform), Music attachment (from backend catalog), AI Image generation (via DALL-E proxy), Camera/Gallery media (image + video ≤30s), and a full-screen status viewer with reactions and replies. The feature extends the existing `specs/004-status-updates` infrastructure following Clean Architecture with `flutter_bloc` (Cubit).

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: flutter_bloc, equatable, fpdart, injectable/get_it, dio, socket_io_client, image_picker, record, audio_waveforms, just_audio, video_player, permission_handler, easy_localization  
**Design Tokens**: `AppConstants` (spacing, radius, elevation, durations) + `AppColors` (brand palette)  
**Localization**: `easy_localization` with JSON translation files (`assets/translations/{en,ar}.json`)  
**Storage**: SQLite (sqflite) for status records, Hive for credentials/preferences  
**Testing**: flutter_test, bloc_test  
**Target Platform**: Android, iOS, Web (Chrome)  
**Project Type**: Mobile messaging app (cross-platform)  
**Constraints**: Offline-capable, ≤30s video clips, ≤30s voice recordings  

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature is split into `presentation`, `domain`, and `data` layers
- [x] **II. State Management**: Uses `flutter_bloc` (Cubit preferred). States extend `Equatable`
- [x] **III. Offline-First**: SQLite for status records. Failed uploads queued with `pending` status
- [x] **IV. Socket.io**: Uses singleton `SocketService`. Events are idempotent
- [x] **V. Teardown**: All `StreamSubscription`, `RecorderController`, `AudioPlayer` disposed in `close()`
- [x] **Code Quality**: Strict linting. `snake_case` files, `PascalCase` classes
- [x] **Error Handling**: Exceptions mapped to `Failure` classes in Data layer. Repositories return `Either<Failure, T>`
- [x] **Design Tokens**: All spacing/radius/elevation/duration values use `AppConstants` — no raw numeric literals in widgets
- [x] **Localization**: All user-facing strings use `easy_localization` `.tr()` extension — no hardcoded strings in UI

## Project Structure

### Documentation (this feature)

```text
specs/005-status-creation-flow/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── api-contracts.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (new + modified files)

```text
lib/features/status/
├── data/
│   ├── datasources/
│   │   ├── status_local_data_source.dart     # [MODIFY] add content fields to SQLite schema
│   │   ├── status_remote_data_source.dart    # [MODIFY] add upload, music, AI endpoints
│   │   └── music_remote_data_source.dart     # [NEW] music catalog REST calls
│   ├── models/
│   │   ├── status_model.dart                 # [MODIFY] add new fields mapping
│   │   ├── music_track_model.dart            # [NEW] JSON ↔ MusicTrack
│   │   └── ai_image_result_model.dart        # [NEW] JSON ↔ AIImageResult
│   └── repositories/
│       ├── status_repository_impl.dart       # [MODIFY] add upload/creation methods
│       └── music_repository_impl.dart        # [NEW] music catalog repository
├── domain/
│   ├── entities/
│   │   ├── status_entity.dart                # [MODIFY] add contentType, mediaUrl, etc.
│   │   ├── music_track.dart                  # [NEW] MusicTrack entity
│   │   ├── ai_image_result.dart              # [NEW] AIImageResult entity
│   │   ├── status_content_type.dart          # [NEW] enum
│   │   └── status_privacy.dart               # [NEW] enum
│   └── repositories/
│       ├── status_repository.dart            # [MODIFY] add creation methods
│       └── music_repository.dart             # [NEW] abstract music repo
└── presentation/
    ├── bloc/
    │   ├── status_cubit.dart                 # [MODIFY] integrate creation methods
    │   ├── status_state.dart                 # [MODIFY] add creation-related states
    │   ├── status_creation_cubit.dart        # [NEW] dedicated creation flow Cubit
    │   ├── status_creation_state.dart        # [NEW] creation states
    │   ├── music_cubit.dart                  # [NEW] music catalog Cubit
    │   └── music_state.dart                  # [NEW] music states
    ├── pages/
    │   ├── status_creation_screen.dart       # [NEW] full-screen multi-mode editor
    │   └── story_viewer_screen.dart          # [MODIFY] add reply, reaction, progress bar
    └── widgets/
        ├── add_status_bottom_sheet.dart       # [NEW] entry point bottom sheet
        ├── text_status_editor.dart            # [NEW] text mode canvas
        ├── voice_status_editor.dart           # [NEW] voice recording mode
        ├── media_status_editor.dart           # [NEW] image/video preview + caption
        ├── music_selector_sheet.dart          # [NEW] music catalog bottom sheet
        ├── ai_image_generator_sheet.dart      # [NEW] AI image generation bottom sheet
        ├── color_palette_picker.dart          # [NEW] background color grid
        ├── privacy_dropdown.dart              # [NEW] privacy controls dropdown
        ├── mode_switcher_bar.dart             # [NEW] Video|Image|Text|Voice bottom bar
        ├── status_toolbar.dart                # [NEW] top toolbar (palette, font, privacy)
        └── waveform_visualizer.dart           # [NEW] voice recording waveform widget
```

### Translations (new)

```text
assets/translations/
├── en.json                                   # [NEW] English translations for status creation
└── ar.json                                   # [NEW] Arabic translations for status creation
```

### Core modifications

```text
lib/core/
├── di/injection.dart                         # [MODIFY] register new Cubits + repos
├── routing/                                  # [MODIFY] add route for StatusCreationScreen
└── theme/
    └── app_constants.dart                    # [MODIFY] add status-specific tokens if needed
```

## Proposed Changes

### Component 1: Domain Layer Extensions

Extend the existing domain layer with new entities and repository contracts.

#### [MODIFY] [status_entity.dart](file:///c:/Users/user/Desktop/ciro-app/ciro-chat-app/lib/features/status/domain/entities/status_entity.dart)
Add fields: `contentType`, `textContent`, `mediaUrl`, `backgroundColor`, `fontStyle`, `musicTrackId`, `caption`, `privacy`. Maintain backward compatibility with existing consumers.

#### [NEW] `status_content_type.dart`
Enum: `text`, `image`, `video`, `voice`.

#### [NEW] `status_privacy.dart`
Enum: `public`, `private`, `showOnMap`.

#### [NEW] `music_track.dart`
Entity with `id`, `name`, `artist`, `duration`, `thumbnailUrl`, `previewUrl`, `category`. Extends `Equatable`.

#### [NEW] `ai_image_result.dart`
Entity with `generationId`, `prompt`, `imageUrl`, `createdAt`. Extends `Equatable`.

#### [MODIFY] [status_repository.dart](file:///c:/Users/user/Desktop/ciro-app/ciro-chat-app/lib/features/status/domain/repositories/status_repository.dart)
Add methods: `uploadStatus(StatusEntity)`, `reactToStatus(statusId, reaction)`, `replyToStatus(statusId, message)`, `generateAIImage(prompt)`.

#### [NEW] `music_repository.dart`
Abstract repo: `getTracks(query, category, page)`, `getCategories()`.

---

### Component 2: Data Layer Extensions

#### [MODIFY] `status_model.dart`
Add JSON/SQLite mapping for new fields (`contentType`, `textContent`, `mediaUrl`, `backgroundColor`, `fontStyle`, `musicTrackId`, `caption`, `privacy`).

#### [NEW] `music_track_model.dart`
JSON deserialization from backend `/music/tracks` response.

#### [NEW] `ai_image_result_model.dart`
JSON deserialization from backend `/ai/generate-image` response.

#### [MODIFY] `status_remote_data_source.dart`
Add methods: `uploadStatus()` (multipart), `generateAIImage()`, `reactToStatus()`, `replyToStatus()`. Uses `DioClient`.

#### [NEW] `music_remote_data_source.dart`
Methods: `fetchTracks(query, category, page, limit)`. Uses `DioClient`.

#### [MODIFY] `status_local_data_source.dart`
Update SQLite schema to include new columns. Add migration logic.

#### [MODIFY] `status_repository_impl.dart`
Implement new repository methods. Offline queue for failed uploads.

#### [NEW] `music_repository_impl.dart`
Implements `MusicRepository`. Delegates to `MusicRemoteDataSource`.

---

### Component 3: Presentation Layer — Cubits

#### [NEW] `status_creation_cubit.dart` + `status_creation_state.dart`
**Dedicated Cubit for the entire creation flow.** This is the central brain.

States: `StatusCreationIdle`, `StatusCreationComposing(draft)`, `StatusCreationUploading(draft)`, `StatusCreationSuccess`, `StatusCreationError(message)`.

Methods:
- `initDraft(contentType)` — initialize a blank draft
- `updateText(text)` — update text content
- `updateBackgroundColor(color)` — change canvas color
- `updateFontStyle(fontFamily)` — cycle font
- `updatePrivacy(privacy, selectedContacts?)` — set visibility
- `attachMedia(filePath)` — attach image/video from gallery/camera
- `attachVoiceRecording(filePath)` — attach voice recording
- `attachMusicTrack(track)` — attach background music
- `attachAIImage(imageUrl)` — attach AI-generated image
- `switchMode(contentType)` — switch between Video/Image/Text/Voice
- `submitStatus()` — validate + upload
- `reset()` — clear draft

#### [NEW] `music_cubit.dart` + `music_state.dart`
States: `MusicInitial`, `MusicLoading`, `MusicLoaded(tracks, hasMore)`, `MusicError`.

Methods:
- `loadTracks(category?)` — initial load
- `searchTracks(query)` — search with debounce
- `loadMore()` — pagination
- `previewTrack(track)` — play audio preview
- `selectTrack(track)` — select and return

#### [MODIFY] `status_cubit.dart`
Update `uploadNewStatus()` to accept the new entity fields. Wire into `StatusCreationCubit` completion callback.

---

### Component 4: Presentation Layer — Pages & Widgets

#### [NEW] `add_status_bottom_sheet.dart`
The entry point. Shows:
- Title "Add Status" + close button
- Horizontal scrollable chips: Text, Music, Voice, AI Image
- "Recently used" label
- Camera quick-access tile
- Gallery grid (via `image_picker` or `photo_manager`)

#### [NEW] `status_creation_screen.dart`
Full-screen page that hosts the active editor mode. Uses `BlocBuilder<StatusCreationCubit>` to switch between:
- `TextStatusEditor` (default)
- `VoiceStatusEditor`
- `MediaStatusEditor` (image/video preview)

Includes `StatusToolbar` at top and `ModeSwitcherBar` at bottom.

#### [NEW] `text_status_editor.dart`
Colored canvas with centered `TextField`. Tap-to-type. Placeholder "Write Status".

#### [NEW] `voice_status_editor.dart`
Canvas with user avatar circle + waveform bar. Mic button for record toggle. Uses `RecorderController` from `audio_waveforms`.

#### [NEW] `media_status_editor.dart`
Full-screen image/video preview with caption input at bottom. For video: shows play/pause overlay.

#### [NEW] `music_selector_sheet.dart`
Bottom sheet with search bar, category chips, scrollable song list. Each row: thumbnail, name, artist, duration, play/select button.

#### [NEW] `ai_image_generator_sheet.dart`
Bottom sheet with "Create any image" title, 2-column grid of inspiration images, text input + mic icon.

#### [NEW] `color_palette_picker.dart`
Grid of ~24 color circles. Selected color shows checkmark. Emits `onColorSelected(Color)`.

#### [NEW] `privacy_dropdown.dart`
Popup menu with 3 options: Public, Private, Show on Map. Triggers contact picker for Private mode.

#### [NEW] `mode_switcher_bar.dart`
Horizontal pill bar: Video | Image | Text | Voice. Active mode is highlighted.

#### [NEW] `status_toolbar.dart`
Top toolbar: Color Palette icon, Font Style (Aa) icon, Privacy (@/Map) icon, Close (×) button. Adapts based on current mode.

#### [NEW] `waveform_visualizer.dart`
Wraps `AudioWaveforms` widget from the `audio_waveforms` package. Shows real-time waveform during recording.

#### [MODIFY] `story_viewer_screen.dart`
Enhance with: segmented progress bar, reply input field, heart/like reaction button, tap-to-advance, swipe-to-next-contact.

---

### Component 5: Core, DI & Design Tokens

#### [MODIFY] `injection.dart`
Register: `StatusCreationCubit`, `MusicCubit`, `MusicRepository`, `MusicRepositoryImpl`, `MusicRemoteDataSource`.

#### [MODIFY] Routing
Add route for `StatusCreationScreen`. Wire FAB actions on `UpdatesScreen` to launch `AddStatusBottomSheet`.

#### [MODIFY] [app_constants.dart](file:///c:/Users/user/Desktop/ciro-app/ciro-chat-app/lib/core/theme/app_constants.dart)
Add status-specific design tokens as needed (e.g., `statusColorSwatchSize`, `waveformHeight`, `toolbarIconSize`). All new widgets MUST reference `AppConstants` for spacing (`spacingXs/Sm/Md/Lg/Xl`), radius (`radiusSm/Md/Lg/Pill`), elevation (`elevationNone/Sm/Md/Lg`), and animation durations (`durationFast/Normal/Slow`). **Zero raw numeric literals in widget layout code.**

---

### Component 6: Localization (easy_localization)

#### [NEW] `assets/translations/en.json`
English translation keys for all user-facing strings in the status creation flow:
```json
{
  "status": {
    "add_status": "Add Status",
    "write_status": "Write Status",
    "text": "Text",
    "music": "Music",
    "voice": "Voice",
    "ai_image": "AI Image",
    "video": "Video",
    "image": "Image",
    "camera": "Camera",
    "recently_used": "Recently used",
    "done": "Done",
    "reply": "Reply",
    "public": "Public",
    "public_desc": "All contacts",
    "private": "Private",
    "private_desc": "Select contacts",
    "show_on_map": "Show on Map",
    "create_any_image": "Create any image",
    "create_image_for": "Create image for....",
    "search": "Search",
    "suggestions": "Suggestions",
    "mood": "Mood",
    "type": "Type",
    "video_too_long": "Video must be 30 seconds or less",
    "no_songs_available": "No songs available",
    "generation_failed": "Image generation failed. Try again.",
    "upload_failed": "Upload failed. Will retry automatically.",
    "recording_max": "Maximum recording duration reached"
  }
}
```

#### [NEW] `assets/translations/ar.json`
Arabic translation keys — same structure with RTL-aware values.

#### [MODIFY] `pubspec.yaml`
Add `easy_localization` dependency and register `assets/translations/` in the assets section.

#### [MODIFY] `main.dart`
Wrap the root `MaterialApp` with `EasyLocalization` widget, configure supported locales (`en`, `ar`), set `assets/translations/` as the translations path.

#### Usage Pattern
All widgets MUST use the `.tr()` extension from `easy_localization`:
```dart
// ✅ Correct
Text('status.write_status'.tr())

// ❌ Wrong — hardcoded string
Text('Write Status')
```

## Reusable/Custom Widgets Summary

| Widget | Reusability | Description |
| ------ | ----------- | ----------- |
| `ColorPalettePicker` | High | Can be reused for any feature needing color selection |
| `ModeSwitcherBar` | Medium | Generic horizontal pill selector |
| `StatusToolbar` | Medium | Configurable top toolbar with icon actions |
| `WaveformVisualizer` | High | Wraps audio_waveforms, reusable for voice messages |
| `PrivacyDropdown` | Medium | Generic 3-option popup menu |
| `MusicSelectorSheet` | Low | Feature-specific but self-contained |
| `AIImageGeneratorSheet` | Low | Feature-specific but self-contained |

## Verification Plan

### Automated Tests
- Unit tests for `StatusCreationCubit`: test all state transitions (init → composing → uploading → success/error)
- Unit tests for `MusicCubit`: test loading, search, pagination, preview
- Unit tests for `StatusEntity` extended fields serialization
- Unit tests for `MusicTrackModel` JSON parsing
- Widget tests for `ColorPalettePicker` selection behavior
- Widget tests for `ModeSwitcherBar` mode switching

### Manual Verification
- Open Updates screen → tap Pencil FAB → verify Add Status bottom sheet appears with all chips
- Select Text → type message → change background color → set privacy → tap Done → verify upload
- Select Voice → record → verify waveform animates → stop → verify playback → submit
- Select Music → search → tap song → verify preview plays → select → verify attachment
- Select AI Image → type prompt → verify loading → verify generated image → post as status
- Select gallery image → verify preview → add caption → submit
- Select gallery video ≤30s → verify acceptance; select >30s → verify rejection with message
- Tap another user's status → verify viewer: progress bar, reply, heart icon, tap-to-advance
- Kill network → create status → verify queued locally → restore network → verify auto-retry
- Switch device language to Arabic → verify all status creation UI strings render in Arabic (RTL)
- Verify no hardcoded strings remain in any new widget (grep for literal `Text('...'))` in new files)
- Verify all spacing uses `AppConstants.spacing*` — no raw `SizedBox(height: 16)` etc.

## Complexity Tracking

No constitution violations. All patterns follow established conventions.
