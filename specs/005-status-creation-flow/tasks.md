# Tasks: Status Creation Flow

**Input**: Design documents from `specs/005-status-creation-flow/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Not explicitly requested — test tasks omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter Feature**: `lib/features/status/`
- **Data Layer**: `lib/features/status/data/`
- **Domain Layer**: `lib/features/status/domain/`
- **Presentation Layer**: `lib/features/status/presentation/`
- **Core Logic**: `lib/core/`
- **Translations**: `assets/translations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Install new dependencies, create translation files, and register the localization system.

- [x] T001 Add `easy_localization` dependency to `pubspec.yaml` and register `assets/translations/` in the assets section
- [x] T002 [P] Create English translation file with all status creation keys at `assets/translations/en.json` (use the key structure from plan.md Component 6)
- [x] T003 [P] Create Arabic translation file with all status creation keys at `assets/translations/ar.json` (same key structure, RTL-aware Arabic values)
- [x] T004 Wrap root `MaterialApp` with `EasyLocalization` widget in `lib/main.dart` — configure supported locales (`en`, `ar`), set translations path to `assets/translations/`
- [x] T005 [P] Add status-specific design tokens to `lib/core/theme/app_constants.dart` — add `statusColorSwatchSize`, `waveformHeight`, `toolbarIconSize`, `statusMaxVideoDuration`, `statusMaxVoiceDuration` constants

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Domain entities, enums, repository contracts, and data models that ALL user stories depend on. MUST complete before any story.

### Domain Layer

- [x] T006 [P] Create `StatusContentType` enum (text, image, video, voice) at `lib/features/status/domain/entities/status_content_type.dart`
- [x] T007 [P] Create `StatusPrivacy` enum (public, private, showOnMap) at `lib/features/status/domain/entities/status_privacy.dart`
- [x] T008 Extend existing `StatusEntity` with new fields (`contentType`, `textContent`, `mediaUrl`, `backgroundColor`, `fontStyle`, `musicTrackId`, `caption`, `privacy`) at `lib/features/status/domain/entities/status_entity.dart` — maintain backward compatibility with existing consumers
- [x] T009 [P] Create `MusicTrack` entity (id, name, artist, duration, thumbnailUrl, previewUrl, category) extending `Equatable` at `lib/features/status/domain/entities/music_track.dart`
- [x] T010 [P] Create `AIImageResult` entity (generationId, prompt, imageUrl, createdAt) extending `Equatable` at `lib/features/status/domain/entities/ai_image_result.dart`
- [x] T011 Extend abstract `StatusRepository` with new methods (`uploadStatus`, `reactToStatus`, `replyToStatus`, `generateAIImage`) at `lib/features/status/domain/repositories/status_repository.dart`
- [x] T012 [P] Create abstract `MusicRepository` interface (`getTracks`, `getCategories`) at `lib/features/status/domain/repositories/music_repository.dart`

### Data Layer

- [x] T013 Extend `StatusModel` with JSON/SQLite mapping for new fields (`contentType`, `textContent`, `mediaUrl`, `backgroundColor`, `fontStyle`, `musicTrackId`, `caption`, `privacy`) at `lib/features/status/data/models/status_model.dart`
- [x] T014 [P] Create `MusicTrackModel` with JSON deserialization from backend `/music/tracks` response at `lib/features/status/data/models/music_track_model.dart`
- [x] T015 [P] Create `AIImageResultModel` with JSON deserialization from backend `/ai/generate-image` response at `lib/features/status/data/models/ai_image_result_model.dart`
- [x] T016 Update `StatusLocalDataSource` SQLite schema to include new columns (`content_type`, `text_content`, `media_url`, `background_color`, `font_style`, `music_track_id`, `caption`, `privacy`) with migration logic at `lib/features/status/data/datasources/status_local_data_source.dart`
- [x] T017 Extend `StatusRemoteDataSource` with upload (multipart), AI generation, reaction, and reply methods at `lib/features/status/data/datasources/status_remote_data_source.dart`
- [x] T018 [P] Create `MusicRemoteDataSource` with `fetchTracks(query, category, page, limit)` using `DioClient` at `lib/features/status/data/datasources/music_remote_data_source.dart`
- [x] T019 Extend `StatusRepositoryImpl` with new method implementations and offline queue for failed uploads at `lib/features/status/data/repositories/status_repository_impl.dart`
- [x] T020 [P] Create `MusicRepositoryImpl` implementing `MusicRepository`, delegating to `MusicRemoteDataSource` at `lib/features/status/data/repositories/music_repository_impl.dart`

### Presentation Layer — Cubits

- [x] T021 Create `StatusCreationState` classes (`Idle`, `Composing(draft)`, `Uploading(draft)`, `Success`, `Error(message)`) extending `Equatable` at `lib/features/status/presentation/bloc/status_creation_state.dart`
- [x] T022 Create `StatusCreationCubit` with all draft management methods (`initDraft`, `updateText`, `updateBackgroundColor`, `updateFontStyle`, `updatePrivacy`, `attachMedia`, `attachVoiceRecording`, `attachMusicTrack`, `attachAIImage`, `switchMode`, `submitStatus`, `reset`) at `lib/features/status/presentation/bloc/status_creation_cubit.dart`
- [x] T023 [P] Create `MusicState` classes (`Initial`, `Loading`, `Loaded(tracks, hasMore)`, `Error`) extending `Equatable` at `lib/features/status/presentation/bloc/music_state.dart`
- [x] T024 [P] Create `MusicCubit` with `loadTracks`, `searchTracks`, `loadMore`, `previewTrack`, `selectTrack` methods at `lib/features/status/presentation/bloc/music_cubit.dart`

### DI Registration

- [x] T025 Register all new dependencies in `lib/core/di/injection.dart` — `StatusCreationCubit`, `MusicCubit`, `MusicRepository`, `MusicRepositoryImpl`, `MusicRemoteDataSource`

**Checkpoint**: Foundation ready — user story implementation can now begin in parallel

---

## Phase 3: User Story 1 — Open Add Status Bottom Sheet (Priority: P1) 🎯 MVP

**Goal**: Deliver the entry-point bottom sheet triggered by the Pencil FAB with category chips (Text, Music, Voice, AI Image), Camera tile, and gallery grid.

**Independent Test**: Tap the FAB on the Updates screen → verify the bottom sheet appears with all category chips, camera tile, and gallery thumbnails.

### Implementation for User Story 1

- [x] T026 [US1] Create `AddStatusBottomSheet` widget with draggable sheet, "Add Status" title (.tr()), close (×) button, horizontal scrollable category chips (Text, Music, Voice, AI Image), "Recently used" label, Camera tile, and gallery grid using `image_picker` at `lib/features/status/presentation/widgets/add_status_bottom_sheet.dart` — use `AppConstants.sheetRadius` for top corners, `AppConstants.spacingMd` for all padding, all strings via `.tr()`
- [x] T027 [US1] Wire Pencil FAB and "Add Status" tile on `UpdatesScreen` to launch `AddStatusBottomSheet` — modify `lib/features/status/presentation/pages/updates_screen.dart`
- [x] T028 [US1] Add route for `StatusCreationScreen` in routing configuration — modify `lib/core/routing/`
- [x] T029 [US1] Handle gallery image/video tap in `AddStatusBottomSheet` — on tap, validate video duration (≤30s via `video_player`), navigate to `StatusCreationScreen` with media pre-attached, show SnackBar `'status.video_too_long'.tr()` if video exceeds 30s
- [x] T030 [US1] Handle Camera tile tap — request camera permission via `permission_handler`, launch `image_picker` camera, navigate to `StatusCreationScreen` with captured media

**Checkpoint**: Add Status bottom sheet is fully functional. User can open it, see gallery, and navigate to the creation screen.

---

## Phase 4: User Story 2 — Create Text Status (Priority: P1) 🎯 MVP

**Goal**: Full text status creation with colored canvas, font cycling, privacy controls, and background color picker.

**Independent Test**: Open Text mode → type message → change background color → set privacy to Private → tap Done → verify status is published.

### Implementation for User Story 2

- [x] T031 [P] [US2] Create `ColorPalettePicker` widget — grid of ~24 curated `Color` swatches using `GridView`, selected color shows checkmark, emits `onColorSelected(Color)` callback at `lib/features/status/presentation/widgets/color_palette_picker.dart` — use `AppConstants.statusColorSwatchSize` for swatch dimensions, `AppConstants.spacingXs` for grid spacing
- [x] T032 [P] [US2] Create `PrivacyDropdown` widget — popup menu with 3 options: "Public (All contacts)", "Private (Select contacts)", "Show on Map" using `.tr()` keys, triggers contact picker for Private mode at `lib/features/status/presentation/widgets/privacy_dropdown.dart`
- [x] T033 [P] [US2] Create `ModeSwitcherBar` widget — horizontal pill bar (Video | Image | Text | Voice), active mode highlighted with `AppColors.primary`, emits `onModeChanged(StatusContentType)` at `lib/features/status/presentation/widgets/mode_switcher_bar.dart` — use `AppConstants.radiusPill` for pill shape
- [x] T034 [P] [US2] Create `StatusToolbar` widget — top row with Color Palette icon, Font Style (Aa) icon, Privacy (@/Map) icon, Close (×) button; adapts visible icons based on current mode at `lib/features/status/presentation/widgets/status_toolbar.dart` — use `AppConstants.toolbarIconSize`
- [x] T035 [US2] Create `TextStatusEditor` widget — full-screen colored canvas with centered `TextField`, placeholder `'status.write_status'.tr()`, background color from `StatusCreationCubit` state at `lib/features/status/presentation/widgets/text_status_editor.dart`
- [x] T036 [US2] Create `StatusCreationScreen` page — hosts `StatusToolbar`, active editor (Text/Voice/Media), and `ModeSwitcherBar`; uses `BlocBuilder<StatusCreationCubit>` to switch editor mode; "Done" button triggers `submitStatus()` at `lib/features/status/presentation/pages/status_creation_screen.dart` — all spacing via `AppConstants`, all strings via `.tr()`
- [x] T037 [US2] Integrate font style cycling in `StatusCreationCubit` — define 3-5 font families, "Aa" button rotates through them, `TextStatusEditor` applies current font family
- [x] T038 [US2] Integrate `ColorPalettePicker` with `StatusCreationCubit` — tapping palette icon toggles picker visibility, selecting a color calls `updateBackgroundColor()`, canvas updates instantly
- [x] T039 [US2] Integrate `PrivacyDropdown` with `StatusCreationCubit` — selecting privacy option calls `updatePrivacy()`, "Private" option launches contact multi-select picker
- [x] T040 [US2] Wire `submitStatus()` flow — `StatusCreationCubit` validates draft, calls `StatusRepository.uploadStatus()`, emits `Success`/`Error`, on success dismisses screen and refreshes `StatusCubit`

**Checkpoint**: Users can compose and publish text statuses with custom backgrounds, fonts, and privacy. Full MVP complete.

---

## Phase 5: User Story 3 — Create Voice Status (Priority: P2)

**Goal**: Voice recording mode with waveform visualization, preview, and submit.

**Independent Test**: Switch to Voice tab → record a clip → verify waveform animates → stop → verify playback → submit.

### Implementation for User Story 3

- [x] T041 [P] [US3] Create `WaveformVisualizer` widget — wraps `AudioWaveforms` from `audio_waveforms` package, shows real-time waveform during recording, configurable height via `AppConstants.waveformHeight` at `lib/features/status/presentation/widgets/waveform_visualizer.dart`
- [x] T042 [US3] Create `VoiceStatusEditor` widget — canvas background, user avatar circle with mic icon, `WaveformVisualizer`, mic action button (tap to record/stop), timer display, playback preview using `just_audio` at `lib/features/status/presentation/widgets/voice_status_editor.dart` — use `AppConstants.durationNormal` for animations, `AppConstants.spacingLg` for avatar sizing
- [x] T043 [US3] Integrate voice recording in `StatusCreationCubit` — `RecorderController` initialization, start/stop recording, auto-stop at 30s (`AppConstants.statusMaxVoiceDuration`), save to temp file, call `attachVoiceRecording(filePath)`
- [x] T044 [US3] Wire Voice mode in `StatusCreationScreen` — when `ModeSwitcherBar` switches to Voice, render `VoiceStatusEditor`, show mic button next to mode bar, toolbar adapts (hide Aa button, keep palette + privacy)
- [ ] T045 [US3] Implement voice status upload in `StatusRemoteDataSource` — multipart upload of audio file to `/status/upload` with `contentType: voice`, background color, and privacy

**Checkpoint**: Users can record and publish voice statuses with waveform visualization.

---

## Phase 6: User Story 4 — Select Music for Status (Priority: P2)

**Goal**: Music catalog bottom sheet with search, categories, preview, and selection.

**Independent Test**: Tap Music chip → search for a song → tap preview → select song → verify it is attached.

### Implementation for User Story 4

- [x] T046 [US4] Create `MusicSelectorSheet` widget — bottom sheet with search bar (`'status.search'.tr()`), category chips (Suggestions, Mood, Type), scrollable `ListView` of songs (thumbnail, name, artist, duration, play/select buttons), pagination via `MusicCubit.loadMore()` at `lib/features/status/presentation/widgets/music_selector_sheet.dart` — use `AppConstants.sheetRadius`, `AppConstants.spacingMd`, `AppConstants.radiusSm` for chips
- [x] T047 [US4] Wire Music chip in `AddStatusBottomSheet` — tapping "Music" chip opens `MusicSelectorSheet` as a new bottom sheet
- [x] T048 [US4] Implement song preview playback in `MusicCubit` — use `just_audio` to play `previewUrl`, manage play/pause state, stop previous preview when new song is tapped
- [x] T049 [US4] Implement song selection flow — tapping the select/arrow button calls `StatusCreationCubit.attachMusicTrack(track)`, dismisses music sheet, navigates to `StatusCreationScreen` with music attached
- [x] T050 [US4] Display attached music indicator on `StatusCreationScreen` — show song name/artist chip or mini-player when a music track is attached to the draft

**Checkpoint**: Users can browse, search, preview, and attach music to statuses.

---

## Phase 7: User Story 5 — Generate AI Image for Status (Priority: P3)

**Goal**: AI image generation bottom sheet with text/voice prompt and generated image preview.

**Independent Test**: Tap AI Image chip → type prompt → submit → verify loading → verify generated image → post as status.

### Implementation for User Story 5

- [x] T051 [US5] Create `AIImageGeneratorSheet` widget — bottom sheet with "Create any image" title (`'status.create_any_image'.tr()`), 2-column `GridView` of sample/inspiration images, text input with placeholder `'status.create_image_for'.tr()` and mic icon at bottom at `lib/features/status/presentation/widgets/ai_image_generator_sheet.dart` — use `AppConstants.sheetRadius`, `AppConstants.spacingMd`
- [x] T052 [US5] Wire AI Image chip in `AddStatusBottomSheet` — tapping "AI Image" chip opens `AIImageGeneratorSheet`
- [x] T053 [US5] Implement AI image generation in `StatusCreationCubit` — call `StatusRepository.generateAIImage(prompt)`, manage `Generating`/`Generated`/`Failed` sub-states, show loading indicator, handle 15s timeout
- [x] T054 [US5] Implement voice-to-text input on `AIImageGeneratorSheet` — tapping mic icon activates speech recognition, converts speech to text in the prompt field
- [x] T055 [US5] Implement AI result selection — once image is generated, user can post it as a status (calls `attachAIImage(imageUrl)` then navigates to `StatusCreationScreen`) or generate a new one

**Checkpoint**: Users can generate and post AI-created images as statuses.

---

## Phase 8: User Story 6 — View and Interact with a Status (Priority: P1) 🎯 MVP

**Goal**: Full-screen status viewer with progress bar, reply, reaction, and navigation.

**Independent Test**: Tap a status from Updates screen → verify viewer opens with progress bar, author info, caption, reply field, and heart icon.

### Implementation for User Story 6

- [x] T056 [US6] Enhance `StoryViewerScreen` with segmented linear progress bar at the top — each segment represents one status item, auto-advances with timer, tap-to-advance at `lib/features/status/presentation/pages/story_viewer_screen.dart`
- [x] T057 [US6] Add author info overlay (avatar, name, timestamp "Yesterday") to the top-left of the viewer — use `AppConstants.spacingMd` for positioning
- [x] T058 [US6] Add caption display at the bottom center of the viewer — render `caption` from `StatusEntity`, styled text over content
- [x] T059 [US6] Add Reply input field at the bottom-left — `TextField` with `'status.reply'.tr()` hint, on submit call `StatusRepository.replyToStatus()` which sends a DM to the status author
- [x] T060 [US6] Add heart/like reaction button at the bottom-right — tapping calls `StatusRepository.reactToStatus(statusId, 'heart')`, show brief animation feedback
- [x] T061 [US6] Implement swipe-to-skip between contacts — horizontal `PageView` wrapping the viewer, each page is one contact's status set
- [x] T062 [US6] Update `StatusCubit.markStatusAsViewed()` to fire when a status is displayed in the viewer — emit socket event `statusViewed`

**Checkpoint**: Users can view, reply to, and react to statuses with full progress navigation.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories.

- [x] T063 [P] Verify all new widgets use `AppConstants` for spacing/radius/elevation — grep for raw numeric literals (`SizedBox(height:`, `EdgeInsets.all(`, `BorderRadius.circular(`) in all new files and replace with `AppConstants.*` tokens
- [x] T064 [P] Verify all new widgets use `.tr()` for user-facing strings — grep for literal `Text('...')` in all new files and replace with `.tr()` calls
- [x] T065 Implement offline queue for failed status uploads — if `submitStatus()` fails due to network, save draft with `pending` status to SQLite, retry on `SocketService.onReconnected` callback
- [x] T066 [P] Handle permission edge cases — camera permission denied → show prompt to open settings; gallery permission denied → show empty state with access prompt; microphone permission denied → show SnackBar with settings link
- [x] T067 Update existing `StatusCubit.uploadNewStatus()` to accept new entity fields and integrate with `StatusCreationCubit` completion callback at `lib/features/status/presentation/bloc/status_cubit.dart`
- [x] T068 Ensure proper `dispose`/`close` teardown in `StatusCreationCubit` — cancel `RecorderController`, `AudioPlayer` for music preview, all `StreamSubscription` instances
- [x] T069 Ensure proper `dispose`/`close` teardown in `MusicCubit` — cancel `AudioPlayer` for preview, pagination state
- [x] T070 Run `flutter analyze` and fix all lint warnings across new files
- [x] T071 Manual end-to-end validation — run through all 6 user stories on Chrome, verify each flow, switch to Arabic locale and verify RTL rendering

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 - Add Status Sheet (Phase 3)**: Depends on Phase 2
- **US2 - Text Status (Phase 4)**: Depends on Phase 2. Recommended after US1 (needs sheet navigation)
- **US3 - Voice Status (Phase 5)**: Depends on Phase 2. Can start in parallel with US2
- **US4 - Music Selector (Phase 6)**: Depends on Phase 2. Can start in parallel with US2/US3
- **US5 - AI Image (Phase 7)**: Depends on Phase 2. Can start in parallel with US3/US4
- **US6 - Status Viewer (Phase 8)**: Depends on Phase 2. Fully independent from US1-US5
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: After Phase 2 — no dependencies on other stories
- **US2 (P1)**: After Phase 2 — light dependency on US1 (bottom sheet navigation) but can be tested independently
- **US3 (P2)**: After Phase 2 — independent from US1/US2
- **US4 (P2)**: After Phase 2 — independent from other stories
- **US5 (P3)**: After Phase 2 — independent from other stories
- **US6 (P1)**: After Phase 2 — fully independent from creation stories

### Within Each User Story

- Widgets before pages (bottom-up)
- Cubit integration after widgets exist
- Wiring/navigation last

### Parallel Opportunities

- T002 + T003 (en.json + ar.json) can run in parallel
- T006 + T007 + T009 + T010 (all domain enums/entities) can run in parallel
- T014 + T015 (music/AI models) can run in parallel
- T018 + T020 (music datasource + repo) can run in parallel
- T023 + T024 (music cubit state + cubit) can run in parallel
- T031 + T032 + T033 + T034 (all US2 reusable widgets) can run in parallel
- US3 + US4 + US5 can all start in parallel after Phase 2
- US6 can run entirely in parallel with US1-US5

---

## Parallel Example: Phase 2 (Foundational)

```text
# Parallel batch 1 — Domain enums + entities (all different files):
T006: StatusContentType enum
T007: StatusPrivacy enum  
T009: MusicTrack entity
T010: AIImageResult entity

# Sequential — depends on enums:
T008: Extend StatusEntity (needs T006, T007)
T011: Extend StatusRepository (needs T008)
T012: MusicRepository interface (needs T009)

# Parallel batch 2 — Data models (all different files):
T013: Extend StatusModel (needs T008)
T014: MusicTrackModel (needs T009)
T015: AIImageResultModel (needs T010)

# Parallel batch 3 — Data sources:
T016: StatusLocalDataSource migration (needs T013)
T017: StatusRemoteDataSource extension (needs T013)
T018: MusicRemoteDataSource (needs T014)

# Parallel batch 4 — Repositories:
T019: StatusRepositoryImpl (needs T016, T017)
T020: MusicRepositoryImpl (needs T018)

# Parallel batch 5 — Cubits:
T021 + T022: StatusCreation state + cubit (needs T019)
T023 + T024: Music state + cubit (needs T020)

# Final:
T025: DI registration (needs all above)
```

---

## Implementation Strategy

### MVP First (US1 + US2 + US6)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T025)
3. Complete Phase 3: US1 — Add Status Bottom Sheet (T026-T030)
4. Complete Phase 4: US2 — Text Status Creation (T031-T040)
5. Complete Phase 8: US6 — Status Viewer (T056-T062)
6. **STOP and VALIDATE**: Test text status creation + viewing end-to-end
7. Deploy/demo if ready — this is a fully functional MVP

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 + US2 → Text statuses work → Demo (MVP!)
3. US6 → Viewing + reactions work → Demo
4. US3 → Voice statuses work → Demo
5. US4 → Music attachment works → Demo
6. US5 → AI images work → Demo
7. Polish → Production-ready

### Parallel Team Strategy

With multiple developers after Phase 2:

- **Developer A**: US1 → US2 (creation flow)
- **Developer B**: US6 (viewer, fully independent)
- **Developer C**: US3 + US4 (voice + music)
- **Developer D**: US5 (AI image, independent)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- All UI strings MUST use `.tr()` from `easy_localization`
- All layout values MUST use `AppConstants.*` tokens — zero raw numeric literals
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
