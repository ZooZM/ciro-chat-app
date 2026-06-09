# Tasks: Map UI

**Input**: Design documents from `specs/013-map-ui/`  
**Prerequisites**: [plan.md](./plan.md) ✅ | [spec.md](./spec.md) ✅ | [research.md](./research.md) ✅ | [data-model.md](./data-model.md) ✅  
**Feature Directory**: `lib/features/map/`  
**Status Feature Extended**: `lib/features/status/presentation/pages/`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on other tasks in same group)
- **[Story]**: Which user story this task belongs to (US1–US5)
- All file paths are project-relative

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the scaffold, shared mock data, and localization keys that every user story depends on.

- [X] T001 Create `map` feature directory structure: `lib/features/map/domain/`, `lib/features/map/data/`, `lib/features/map/presentation/bloc/`, `lib/features/map/presentation/pages/`, `lib/features/map/presentation/widgets/`, `lib/features/map/presentation/mock/`
- [X] T002 [P] Create mock data seed file `lib/features/map/presentation/mock/map_mock_data.dart` — defines `MockUser`, `MockMapMarker`, `MockStatus`, `StatusFilter` enum, and 5 seeded mock users + 4 map markers + 2 mock statuses (from data-model.md)
- [X] T003 [P] Add all new localization keys to `assets/translations/en.json` — add `nav.*`, `map.*`, `reels.*` key groups from the plan.md Localization Keys section
- [X] T004 [P] Mirror the same localization keys to `assets/translations/ar.json` with Arabic translations
- [X] T005 [P] Add `flutter_map` and `latlong2` to `pubspec.yaml` dependencies (needed for map tiles and `LatLng` type)

**Checkpoint**: Shared scaffold and mock data ready. All subsequent phases can proceed.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `MapCubit` + `ShellRoute` + `AppBottomNavBar` that every screen depends on.

- [X] T006 Create `lib/features/map/presentation/bloc/map_state.dart` — defines `MapState extends Equatable` with fields: `selectedTab` (`MapTab` enum: `following`/`explore`), `markers` (`List<MockMapMarker>`), `selectedUser` (`MockUser?`)
- [X] T007 Create `lib/features/map/presentation/bloc/map_cubit.dart` — `MapCubit extends Cubit<MapState>` with methods: `switchTab(MapTab)`, `selectUser(MockUser?)`, seeded with mock markers from `map_mock_data.dart`
- [X] T008 Create `lib/features/map/presentation/widgets/app_bottom_nav_bar.dart` — custom `BottomNavigationBar` with 5 items (Chats, Updates, Map, Calls, Profile), Map tab has raised green circle icon, `selectedItemColor: AppColors.primary`
- [X] T009 Create `lib/core/routing/main_shell.dart` — `MainShell` `StatefulWidget` that wraps `child` with `AppBottomNavBar` and handles tab index ↔ GoRouter location mapping (tracks current location via `GoRouterState`)
- [X] T010 Modify `lib/core/routing/app_router.dart` — wrap existing `/home`, `/updates` routes and add new `/map`, `/calls` (stub), `/profile` (stub) routes inside a `ShellRoute` using `MainShell` as the shell builder; add `/map` `GoRoute` pointing to `MapScreen`; add `AppRouterName.map = '/map'` constant

**Checkpoint**: Bottom nav bar is visible across all 5 tabs. Navigation between tabs works. `MapCubit` is injectable.

---

## Phase 3: User Story 1 — Main Map Navigation (Priority: P1) 🎯 MVP

**Goal**: Full-screen OSM map with floating avatar markers, top bar toggle, and right-side FABs.

**Independent Test**: Launch app → tap Map tab → OSM map renders with 4 avatar markers positioned over Cairo. Tap a marker to see a bottom sheet. Tap the FAB column's filter button to see the filter sheet stub. Tap "Following"/"Explore" to see tab toggle highlight switch.

### Implementation for User Story 1

- [X] T011 [US1] Create `lib/features/map/presentation/widgets/map_avatar_marker.dart` — `MapAvatarMarker` widget: `Column` with bordered `CircleAvatar` (photo or initial fallback), online green dot (Positioned), name label pill (white rounded container below); props: `MockMapMarker marker`
- [X] T012 [P] [US1] Create `lib/features/map/presentation/widgets/map_top_bar.dart` — `MapTopBar` widget: `Row` with glass search icon button, centered `_FollowingExplorePill` (dark pill with two tappable tab labels, active = white text), add-person icon, add-box icon; props: `MapTab selectedTab`, `ValueChanged<MapTab> onTabChanged`
- [X] T013 [P] [US1] Create `lib/features/map/presentation/widgets/map_fab_column.dart` — `MapFabColumn` widget: vertical `Column` of 4 circular FABs (Layers `Icons.layers_outlined`, Filter/Tune `Icons.tune`, Locate Me `Icons.my_location`, Share My Location green primary FAB with `Icons.location_on` + 'map.share_location'.tr() label); filter FAB calls `onFilterTap` callback; all others are no-op for now
- [X] T014 [US1] Create `lib/features/map/presentation/pages/map_screen.dart` — `MapScreen` `StatelessWidget` using `BlocBuilder<MapCubit, MapState>`: `Scaffold(extendBodyBehindAppBar: true)` with `Stack` containing: `FlutterMap` (OSM `TileLayer` + `MarkerLayer` built from `state.markers` using `MapAvatarMarker`), `Positioned` top overlay for `MapTopBar`, `Positioned` right overlay for `MapFabColumn`; marker tap calls `cubit.selectUser(user)` then `showModalBottomSheet` with `UserDetailsSheet`
- [X] T015 [P] [US1] Register `MapCubit` in DI: add `@lazySingleton` annotation to `MapCubit` (or manually register in `lib/core/di/injection.dart`), re-run `flutter pub run build_runner build` to regenerate DI code
- [X] T016 [US1] Provide `MapCubit` via `BlocProvider` in the `ShellRoute` shell builder (`main_shell.dart`) so it is available to `MapScreen` and its children

**Checkpoint**: Map tab is fully interactive with mock data. Constitution checks pass (Clean Architecture layer stubs exist, Cubit state management, CachedNetworkImage used).

---

## Phase 4: User Story 2 — Bottom Navigation Interaction (Priority: P1)

**Goal**: Seamless tab switching across all 5 nav items with correct active state highlight.

**Independent Test**: Tap each of the 5 bottom nav tabs — active icon turns green, inactive icons are grey. Map center icon stays visually distinct (raised green circle). Back navigation preserves correct active tab.

### Implementation for User Story 2

- [X] T017 [US2] Polish `app_bottom_nav_bar.dart` — ensure Map tab item uses a custom `Container` with `BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)` for the icon background so it visually "pops" above the bar; use `BottomNavigationBarType.fixed` to prevent shifting animation
- [X] T018 [US2] Implement `main_shell.dart` tab index resolver — map GoRouter `state.uri.path` → index (0=Chats, 1=Updates, 2=Map, 3=Calls, 4=Profile); on `onTabChanged` call `context.go(tabPath)` for correct GoRouter navigation
- [X] T019 [P] [US2] Create stub `CallsScreen` in `lib/features/call_routing/presentation/pages/calls_screen.dart` (or reuse existing) — simple `Scaffold` with centered 'nav.calls'.tr() text placeholder; register `/calls` route in `app_router.dart`
- [X] T020 [P] [US2] Create stub `ProfileScreen` in a new `lib/features/profile/presentation/pages/profile_screen.dart` — simple `Scaffold` with centered 'nav.profile'.tr() placeholder; register `/profile` route in `app_router.dart`

**Checkpoint**: All 5 tabs navigate correctly. Bottom nav bar active state is visually correct on all tabs.

---

## Phase 5: User Story 3 — User Details Bottom Sheet (Priority: P2)

**Goal**: Tapping a map marker slides up a bottom sheet showing the user's avatar, name, online status, location, Messaging and Call buttons.

**Independent Test**: Tap any mock avatar marker on the map → bottom sheet animates up showing "Omar Hassan / online / Near Zamalek, Cairo / Messaging + Call buttons". Dismiss by tapping outside or dragging down.

### Implementation for User Story 3

- [X] T021 [US3] Create `lib/features/map/presentation/widgets/user_details_sheet.dart` — `UserDetailsSheet` `StatelessWidget`: rounded-top white `Container` (borderRadius 24 top), drag handle pill, `Row` with `Stack(CircleAvatar + online dot)`, `Column(name, 'online' in AppColors.primary, locationLabel)`, `Spacer`, two `OutlinedButton.icon` (Messaging with `Icons.message`, Call with `Icons.call`) styled with `AppColors.primaryLight` background and no border
- [X] T022 [US3] Wire marker tap in `map_screen.dart` — on `Marker` tap call `showModalBottomSheet(context: context, isScrollControlled: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => UserDetailsSheet(user: tappedMarker.user))`

**Checkpoint**: Tapping any mock marker shows correct user info in the bottom sheet.

---

## Phase 6: User Story 4 — Status/Reels Viewer Screen (Priority: P2)

**Goal**: A full-screen TikTok-style vertical `PageView` reels viewer launched from the Updates tab with top toggle, right action column, and bottom text overlay.

**Independent Test**: From the Updates tab, trigger `ReelsViewerScreen` (add a "View Reels" button or wire existing status tile tap) — full-screen photo fills the screen, right-side action column shows Like/Comment/Share icons with counts, bottom shows "Omar Hassan · 5h ago · Status & Explore" text. Swipe vertically to next reel.

### Implementation for User Story 4

- [X] T023 [US4] Create `lib/features/status/presentation/pages/reels_viewer_screen.dart` — `ReelsViewerScreen` `StatefulWidget`: `Scaffold(extendBodyBehindAppBar: true, backgroundColor: Colors.black)` with full-screen `Stack`: (1) vertical `PageView.builder` of `CachedNetworkImage(fit: BoxFit.cover)` using `mockStatuses`, (2) dark bottom-to-top `LinearGradient` overlay via `DecoratedBox`, (3) `Positioned` top → `_ReelsTopBar`, (4) `Positioned` right bottom → `_ReelsActionColumn`, (5) `Positioned` bottom-left → `_ReelsBottomInfo`
- [X] T024 [P] [US4] Implement `_ReelsTopBar` private widget within `reels_viewer_screen.dart` — `SafeArea Row` with back `IconButton`, search `IconButton`, centered dark-pill Following/Explore toggle (same design as `MapTopBar`'s pill but white icons), add-person + add-box icon buttons; all in `Colors.white`
- [X] T025 [P] [US4] Implement `_ReelsActionColumn` private widget — `Container` with `Colors.black45` background + `borderRadius: 30`, vertical `Column` of `_ReelActionItem` widgets: Like (`Icons.favorite_border`, likeCount), Comment (`Icons.chat_bubble_outline`, commentCount), Share (`Icons.reply`, 'reels.share'.tr()), Refresh (`Icons.refresh`), Music (`Icons.music_note_outlined`); each item is an `IconButton` + optional `Text` count below
- [X] T026 [P] [US4] Implement `_ReelsBottomInfo` private widget — `Column(crossAxisAlignment: start)`: author name (white, bold, 16sp), time-ago string (white70, 13sp), caption (white, 14sp, maxLines:2, overflow: ellipsis); time-ago computed from `MockStatus.timestamp`
- [X] T027 [US4] Wire `ReelsViewerScreen` entry point — in `updates_screen.dart` add tap on the "Explore" section header or add a dedicated "Explore" button that calls `Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReelsViewerScreen()))` passing mock statuses

**Checkpoint**: Reels viewer is fully navigable and visually matches mockup. Vertical swipe transitions between mock status items.

---

## Phase 7: User Story 5 — Map Filter Sheet (Priority: P3)

**Goal**: The filter FAB on the map opens a comprehensive filter modal with search, Status radio buttons, Groups chips, and Distance slider.

**Independent Test**: Tap the `Icons.tune` FAB on the map → `MapFilterSheet` slides up. Toggle Status radio (Online/Offline/All), tap mock group chips, drag distance slider. Tap "Apply Filters" → sheet closes. No crash, no real filter logic needed.

### Implementation for User Story 5

- [X] T028 [US5] Create `lib/features/map/presentation/widgets/map_filter_sheet.dart` — `MapFilterSheet` `StatefulWidget` with local `_MapFilterState`: drag handle, 'map.filter'.tr() title, `TextField` (search, `Icons.search` prefix), Divider, 'map.filter_status'.tr() subtitle, 3× `RadioListTile<StatusFilter>` (all/online/offline), Divider, 'map.filter_groups'.tr() subtitle, `Wrap` of `FilterChip` for 4 mock groups, Divider, 'map.filter_distance'.tr() subtitle, `Slider(min:0, max:100)` + km label, full-width `ElevatedButton` (AppColors.primary) calling `Navigator.pop(context)`; dispose `TextEditingController` in `dispose()`
- [X] T029 [US5] Wire filter sheet — in `map_fab_column.dart` pass `onFilterTap` callback; in `map_screen.dart` implement `_showFilterSheet(context)` calling `showModalBottomSheet(isScrollControlled: true, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: MapFilterSheet()))`

**Checkpoint**: Filter sheet opens, all UI controls are interactive (local state), sheet dismisses on Apply.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final visual polish, error edge cases, and `flutter analyze` clean pass.

- [X] T030 [P] Handle null `avatarUrl` in `map_avatar_marker.dart` and `user_details_sheet.dart` — `CachedNetworkImageProvider` only used when `avatarUrl != null`; fallback to `CircleAvatar` with `user.initial` text and `user.avatarBgColor` background
- [X] T031 [P] Truncate long names in `MapAvatarMarker` name pill — wrap `Text` in `ConstrainedBox(maxWidth: 80)` with `overflow: TextOverflow.ellipsis, maxLines: 1`
- [X] T032 [P] Apply `SafeArea` correctly in `ReelsViewerScreen` — ensure `_ReelsTopBar` respects status bar inset; use `MediaQuery.of(context).padding.top` for additional top offset on the top `Positioned`
- [X] T033 [P] Add missing localization keys check — run `grep -r 'hardcoded'` and ensure zero raw English strings exist in all new files; all user-visible strings use `.tr()`
- [X] T034 Run `flutter analyze` and resolve all warnings/errors in the new files
- [X] T035 Manual smoke test all 5 user stories per the Verification Plan in `plan.md`

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
  └─► Phase 2 (Foundational) — blocked by T005 (pubspec + flutter_map)
        └─► Phase 3 (US1: Map Screen) — blocked by T006–T010
        └─► Phase 4 (US2: Bottom Nav) — blocked by T008–T010
        └─► Phase 5 (US3: User Sheet) — blocked by Phase 3
        └─► Phase 6 (US4: Reels)      — independent of Phase 3; blocked by Phase 2
        └─► Phase 7 (US5: Filter)     — blocked by Phase 3
Phase 8 (Polish) — blocked by all user story phases
```

### User Story Dependencies

| Story | Depends On | Blocks |
|-------|-----------|--------|
| US1 (Map Screen) | Phase 1 + 2 | US3 (sheet), US5 (filter) |
| US2 (Bottom Nav) | Phase 1 + 2 | All tabs navigation |
| US3 (User Sheet) | US1 complete | — |
| US4 (Reels) | Phase 1 + 2 | — |
| US5 (Filter Sheet) | US1 complete | — |

### Parallel Opportunities

- T002, T003, T004, T005 — all Phase 1 tasks (except T001) can run in parallel
- T011, T012, T013 — Phase 3 widget builds can run in parallel (different files)
- T019, T020 — stub screens can be built in parallel
- T024, T025, T026 — all `ReelsViewerScreen` private sub-widgets can be built in parallel
- T030, T031, T032, T033 — all polish tasks are independent

---

## Parallel Example: User Story 1 (Map Screen)

```
# After T001-T010 complete, the following can run in parallel:

Agent A: T011 — map_avatar_marker.dart
Agent B: T012 — map_top_bar.dart
Agent C: T013 — map_fab_column.dart

# Then (T014 depends on A+B+C):
Agent A: T014 — map_screen.dart (assembles the above 3 widgets)
Agent B: T015 — DI registration

# Then T016 (depends on T014 + T015):
T016 — BlocProvider wiring in main_shell.dart
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 Only)

1. Complete Phase 1: Setup (T001–T005)
2. Complete Phase 2: Foundational (T006–T010)
3. Complete Phase 3: US1 Map Screen (T011–T016)
4. Complete Phase 4: US2 Bottom Nav polish (T017–T020)
5. **STOP and VALIDATE**: Full-screen OSM map with avatars + working 5-tab nav
6. Demo / review before continuing

### Incremental Delivery

1. Setup + Foundational → scaffold ready
2. US1 + US2 → interactive map + nav (MVP demo)
3. US3 → user details sheet
4. US4 → reels viewer
5. US5 → filter sheet
6. Polish → production-ready

---

## Phase 9: Google Maps Migration (P0)

**Purpose**: Execute the user's new requirements: migrate from OSM to Google Maps, use the existing navbar instead of the custom one, and implement map type toggling.

- [x] T036 Update dependencies in `pubspec.yaml` — remove `flutter_map` and add `google_maps_flutter`
- [x] T037 [P] Update `lib/features/map/presentation/bloc/map_state.dart` and `map_cubit.dart` — add `MapType mapType` to state (default `MapType.normal`) and a `toggleMapType()` method to switch between `normal` and `satellite`
- [x] T038 [P] Revert bottom nav changes — in `lib/core/routing/app_router.dart`, remove `ShellRoute` using `MainShell` and restore the original routes. Delete `main_shell.dart` and `app_bottom_nav_bar.dart`. Ensure the map screen is accessible from the original existing navbar.
- [x] T039 [P] Update `lib/features/map/presentation/widgets/map_fab_column.dart` — modify the first FAB (Layers icon) to call `context.read<MapCubit>().toggleMapType()` instead of being a no-op
- [x] T040 Migrate `lib/features/map/presentation/pages/map_screen.dart` — replace `FlutterMap` with `GoogleMap`, set `mapType: state.mapType`, and convert `MockMapMarker` elements to Google Maps `Marker` objects. Handle custom marker icons using `BitmapDescriptor` or a widget-to-image generator.

---

## Notes

- No tests are generated (not requested in spec)
- `[P]` tasks operate on different files with no cross-dependencies within their phase
- All mock data is contained in `map_mock_data.dart` — never spread across files
- The `flutter_map` package requires `latlong2` for `LatLng`; both must be in `pubspec.yaml`
- `build_runner` must be re-run after any DI annotation change (T015)
- Stub screens (Calls, Profile) are intentionally minimal — they are not part of this feature's scope
