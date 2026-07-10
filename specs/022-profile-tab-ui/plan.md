# Implementation Plan: Profile Tab UI

**Branch**: `022-featurename-profile-tab-ui` | **Date**: 2026-07-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/022-profile-tab-ui/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command.

## Summary

Build five new presentation-only Flutter screens for the new Profile tab: **Main Profile Tab**, **QR Code**, **Profile Info (Edit)**, **Appearance**, and **Chat Theme Preview**. All screens use `easy_localization` for text, follow the app's existing theme and branding, and contain zero backend logic. The screens will be housed in a new `profile` feature directory and registered as new GoRouter routes.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x
**Primary Dependencies**: `easy_localization`, `go_router`, `flutter_screenutil`, `cached_network_image`
**Storage**: N/A — no data persistence in this feature
**Testing**: Manual visual verification
**Target Platform**: iOS, Android
**Project Type**: Mobile app (Flutter)
**Performance Goals**: 60fps rendering, no jank on all new screens
**Constraints**: UI-only — no backend API calls, no real camera/QR scanning, no actual wallet logic.
**Scale/Scope**: 5 new screens, new localization keys, 4 new routes (one existing), 1 mock data file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: Feature is split into `presentation` (pages, widgets) and `data` (for mock data). Since it's UI-only, no `domain` layer or repository logic is needed yet.
- [x] **II. State Management**: Uses local `StatefulWidget` for simple toggles (e.g., wallet visibility, appearance selection). No global state/Cubit required for this static UI phase.
- [x] **III. Offline-First**: N/A (UI-only mock data).
- [x] **IV. Socket.io**: N/A
- [x] **V. Teardown**: Proper `dispose` implemented where needed.
- [x] **Code Quality**: Strict linting followed. `snake_case` files.
- [x] **Error Handling**: N/A

## Project Structure

### Documentation (this feature)

```text
specs/022-profile-tab-ui/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
lib/features/profile/
├── presentation/
│   ├── pages/
│   │   ├── profile_main_screen.dart           [NEW]
│   │   ├── qr_code_screen.dart                [NEW]
│   │   ├── profile_info_screen.dart           [NEW]
│   │   ├── appearance_screen.dart             [NEW]
│   │   └── chat_theme_preview_screen.dart     [NEW]
│   ├── widgets/
│   │   ├── wallet_card.dart                   [NEW]
│   │   ├── profile_completion_bar.dart        [NEW]
│   │   ├── appearance_theme_list.dart         [NEW]
│   │   ├── appearance_color_grid.dart         [NEW]
│   │   └── appearance_background_list.dart    [NEW]
│   └── data/
│       └── mock_profile_data.dart             [NEW]

lib/core/routing/
└── app_router.dart                            [MODIFY — add new routes]

assets/translations/
├── en.json                                    [MODIFY — ~30 new keys]
└── ar.json                                    [MODIFY — ~30 new keys]
```

**Structure Decision**: A new `profile` feature directory is created. Since this feature is heavily UI-centric with no business logic for now, everything is placed under `presentation`. Mock data is placed in `presentation/data/mock_profile_data.dart`.

## Detailed File Changes

### [NEW] `mock_profile_data.dart`
**Path**: `lib/features/profile/presentation/data/mock_profile_data.dart`
- Contains `UserProfile` with name, bio, ciroId, avatar.
- Contains `WalletInfo` with total balance and current balance.
- Contains mock lists for themes, colors, and backgrounds.

### [NEW] `profile_main_screen.dart`
**Path**: `lib/features/profile/presentation/pages/profile_main_screen.dart`
- A `Scaffold` displaying the main profile.
- Top header with "Profile" title and QR icon (navigates to `AppRouterName.qrCode`).
- User section (Avatar with camera badge, name, bio, Ciro ID, edit icon navigating to `AppRouterName.profileInfo`).
- Uses `WalletCard` and `ProfileCompletionBar` widgets.
- Settings list (Appearance, Linked Devices, Invite a Friend, Language). Appearance navigates to `AppRouterName.appearance`.

### [NEW] `qr_code_screen.dart`
**Path**: `lib/features/profile/presentation/pages/qr_code_screen.dart`
- `AppBar` with "QR Code" and share icon.
- Displays `UserProfile` data, mock QR image placeholder, and descriptive text.
- Full-width "Scan" and "Reset QR code" buttons.

### [NEW] `profile_info_screen.dart`
**Path**: `lib/features/profile/presentation/pages/profile_info_screen.dart`
- `AppBar` with "Profile Info".
- Large Avatar with camera badge.
- TextFields for "Name" and "About (Optional)" (rounded green borders).
- "Save info" green button.

### [NEW] `appearance_screen.dart`
**Path**: `lib/features/profile/presentation/pages/appearance_screen.dart`
- `StatefulWidget` to track selected theme, color, and background.
- Uses `appearance_theme_list.dart`, `appearance_color_grid.dart`, `appearance_background_list.dart`.
- "Preview Chat" button navigates to `AppRouterName.chatThemePreview`.

### [NEW] `chat_theme_preview_screen.dart`
**Path**: `lib/features/profile/presentation/pages/chat_theme_preview_screen.dart`
- Full-screen background.
- Mock chat bubbles (sent/received).
- "Apply Theme" button.

### [NEW] Widgets
- **Path**: `lib/features/profile/presentation/widgets/wallet_card.dart`
  - `StatefulWidget` (for visibility toggle). Green-to-blue gradient.
- **Path**: `lib/features/profile/presentation/widgets/profile_completion_bar.dart`
  - Progress bar.
- **Path**: `lib/features/profile/presentation/widgets/appearance_theme_list.dart`
- **Path**: `lib/features/profile/presentation/widgets/appearance_color_grid.dart`
- **Path**: `lib/features/profile/presentation/widgets/appearance_background_list.dart`

### [MODIFY] `app_router.dart`
**Path**: `lib/core/routing/app_router.dart`
- Add route names: `qrCode`, `profileInfo`, `appearance`, `chatThemePreview`. (Note: `profile` already exists).
- Add `GoRoute` entries for the new screens.

### [MODIFY] `en.json` & `ar.json`
**Path**: `assets/translations/en.json` and `assets/translations/ar.json`
- Add localization keys for all UI text (e.g., `profile_title`, `profile_total_balance`, `profile_appearance_title`, `profile_preview_chat_btn`, etc.).

## Complexity Tracking
No complex architecture required. Strict UI layout using existing design system patterns.
