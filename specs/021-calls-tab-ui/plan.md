# Implementation Plan: Calls Tab UI

**Branch**: `021-calls-tab-ui` | **Date**: 2026-07-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/021-calls-tab-ui/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Build four new presentation-only Flutter screens — **Call Information**, **Select Contact** (with empty and selected states), and **Dialpad** — plus update the existing **Calls History** screen to support navigation to the Call Information screen via tap. All screens use `easy_localization` for text, follow the app's existing theme/branding, and contain zero backend, WebRTC, or device contacts logic. They slot into the existing `call_history` feature folder and are registered as new GoRouter routes.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: `flutter_bloc`, `easy_localization`, `go_router`, `google_fonts`, `flutter_screenutil`, `cached_network_image`  
**Storage**: N/A — no data persistence in this feature  
**Testing**: Manual visual verification; widget tests possible  
**Target Platform**: iOS, Android (responsive via `flutter_screenutil`)  
**Project Type**: Mobile app (Flutter)  
**Performance Goals**: 60fps rendering, no jank on all new screens  
**Constraints**: UI-only — no WebRTC, no `livekit_client`, no `SocketService`, no device contacts API  
**Scale/Scope**: 3 new screens + 1 modified screen, ~25 new localization keys, 3 new routes, 1 mock data file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: All new screens go in `presentation/pages/` within the existing `call_history` feature. No business logic in widgets — callbacks only. Mock data is isolated in a separate file.
- [x] **II. State Management**: No new Cubit needed. Select Contact screen uses minimal local `StatefulWidget` state for single-contact selection toggle. Future wiring will use existing `CallHistoryCubit`.
- [x] **III. Offline-First**: N/A — no data storage or network calls in this feature.
- [x] **IV. Socket.io**: N/A — no socket events. Screens are pure presentation.
- [x] **V. Teardown**: No subscriptions, controllers, or timers to dispose except `TextEditingController` on Dialpad (properly disposed in `dispose()`). Select Contact uses `StatefulWidget` with no async resources.
- [x] **Code Quality**: Files use `snake_case`. Strict linting. `const` constructors where possible. Montserrat font via `google_fonts`.
- [x] **Error Handling**: N/A — no data layer or repository calls. Mock data is compile-time constant.

## Project Structure

### Documentation (this feature)

```text
specs/021-calls-tab-ui/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
lib/features/call_history/
├── presentation/
│   ├── pages/
│   │   ├── calls_history_screen.dart          [MODIFY — add tap→Call Info navigation]
│   │   ├── call_information_screen.dart       [NEW]
│   │   ├── select_contact_screen.dart         [NEW]
│   │   └── dialpad_screen.dart                [NEW]
│   ├── widgets/
│   │   ├── call_history_tile.dart             [MODIFY — expose onInfoTap callback]
│   │   ├── call_action_card.dart              [NEW — reusable action card widget]
│   │   └── contact_avatar.dart                [NEW — shared avatar widget]
│   ├── bloc/
│   │   └── call_history_cubit.dart            (existing — NOT modified)
│   └── data/
│       └── mock_call_data.dart                [NEW — all hardcoded mock data]

lib/core/routing/
└── app_router.dart                            [MODIFY — 3 new routes]

assets/translations/
├── en.json                                    [MODIFY — ~25 new keys]
└── ar.json                                    [MODIFY — ~25 new keys]
```

**Structure Decision**: All new screens go inside the existing `call_history/presentation/pages/` directory. This is the established pattern — the `call_history` feature already owns the Calls tab. No new feature folder needed. Mock data lives in `presentation/data/` to keep it co-located with the UI that consumes it while signaling it's not a real data source.

## Detailed File Changes

---

### [NEW] `mock_call_data.dart`

**Path**: `lib/features/call_history/presentation/data/mock_call_data.dart`

A file containing all hardcoded mock data used across the new screens:
- `mockCallHistory`: `List<CallHistoryRecord>` with 8 entries matching screenshot 1 (Test, Ahmed Khaled, Layla Ibrahim, Yara Mostafa, Amr Mohamed, Omar Hassan, Mahmoud Reda, Tamer Ahmed) with accurate directions, outcomes, call types, timestamps, and avatar color seeds.
- `MockContact` class: Simple data class with `id`, `name`, `initials`, `avatarColorSeed`, `avatarUrl`.
- `mockFrequentContacts`: `List<MockContact>` — Layla Ibrahim, Yara Mostafa, Amr Mohamed.
- `mockAllContacts`: `List<MockContact>` — Amr Mohamed, Omar Hassan, Mahmoud Reda, Tamer Ahmed, Yara Mostafa.
- `CallDetailEntry` class: `direction`, `time`, `status`, `callType`.
- `mockCallDetails`: `Map<String, List<CallDetailEntry>>` keyed by contact user ID for the Call Information screen.
- Avatar color palette constant: `kAvatarPalette` extracted from the existing `CallHistoryTile._avatarPalette` for reuse.

---

### [NEW] `contact_avatar.dart`

**Path**: `lib/features/call_history/presentation/widgets/contact_avatar.dart`

A shared `ContactAvatar` widget reused across Call Information, Select Contact, and Call History screens:
- Accepts: `initials`, `avatarUrl`, `colorSeed`, `radius`
- Renders: `CircleAvatar` with color from `kAvatarPalette[colorSeed % length]`, `CachedNetworkImage` if URL provided, otherwise white initials text.
- Extracts the existing avatar rendering logic from `CallHistoryTile` to avoid duplication.

---

### [NEW] `call_action_card.dart`

**Path**: `lib/features/call_history/presentation/widgets/call_action_card.dart`

A reusable action card widget for the Call Information screen's action row:
- Accepts: `icon` (IconData), `label` (String), `onTap` (VoidCallback)
- Renders: A `Container` with rounded border, centered green icon, and label text below
- Sized as square cards (~100×80) matching screenshot 2 layout
- Uses `AppColors.primary` (green) for icons

---

### [NEW] `call_information_screen.dart`

**Path**: `lib/features/call_history/presentation/pages/call_information_screen.dart`

**Layout** (matching Screenshot 2):
- `Scaffold` with white background
- `AppBar`: back arrow + `'calls_info_title'.tr()` ("Call information")
- Center section: Large `ContactAvatar` (radius ~60) + contact name in bold
- Action row: `Row` of three `CallActionCard` widgets — "Messaging" (`Icons.chat_bubble_outlined`), "Video call" (`Icons.videocam_outlined`), "Voice call" (`Icons.call_outlined`). All icons green. Labels localized.
- Divider
- Call log section: Date header (`'calls_info_today'.tr()` → "Today"), followed by `ListTile` entries from `mockCallDetails` showing: leading green phone icon, title = direction label ("Outgoing"/"Incoming" localized), subtitle = time, trailing = status text ("Not answer" localized)
- Constructor: Receives `CallHistoryRecord` as the parameter to display contact info and look up mock call details.
- All callbacks (Messaging, Video call, Voice call) are no-op `VoidCallback`s.

---

### [NEW] `select_contact_screen.dart`

**Path**: `lib/features/call_history/presentation/pages/select_contact_screen.dart`

**Layout** (matching Screenshots 3 & 4):
- `StatefulWidget` managing `MockContact? _selectedContact` state
- `Scaffold` with white background
- `AppBar`: back arrow, title = `'calls_select_title'.tr()` ("Select a contact"), subtitle = `'calls_select_count'.tr(args: ['261'])` ("261 contacts"), trailing search icon
- **Selection bar** (visible only when `_selectedContact != null`):
  - Left: Selected contact avatar chip — `CircleAvatar` with a small grey `×` `Positioned` badge. Truncated name below.
  - Right: Voice call icon (`Icons.call_outlined`) + Video call icon (`Icons.videocam_outlined`), both in dark grey
- **Top action items** (always visible):
  - "New contact" row: Green circle with `Icons.person_add` → no-op
  - "Call a number" row: Green circle with `Icons.dialpad` → `context.push(AppRouterName.dialpad)`
- **Section: "Frequently contacted"**: Grey section header text, followed by `ListView` of `mockFrequentContacts` with `ContactAvatar` + name + trailing radio button
- **Section: "contact"**: Grey section header text, followed by `ListView` of `mockAllContacts` with same tile structure
- **Radio button behavior**:
  - Unselected: Grey outlined circle (`Icons.radio_button_unchecked`, color grey)
  - Selected: Green filled checkmark (`Icons.check_circle`, color green / `AppColors.primary`)
  - Only one contact can be selected at a time
- Tapping a contact toggles selection: if same contact tapped again → deselects. Tapping `×` badge also deselects.

---

### [NEW] `dialpad_screen.dart`

**Path**: `lib/features/call_history/presentation/pages/dialpad_screen.dart`

**Layout** (matching Screenshot 5):
- `StatefulWidget` with `TextEditingController` for dialed number
- `Scaffold` with white background
- `AppBar`: back arrow only, no title
- Center body: Number display area (currently entered digits, large text, horizontally scrollable)
- Keypad: 4×3 `GridView` of circular grey buttons:
  - Row 1: 1, 2, 3
  - Row 2: 4, 5, 6
  - Row 3: 7, 8, 9
  - Row 4: *, 0, #
  - Each button: `Container` with `Colors.grey[200]` background, `BorderRadius.circular(40)`, large dark text (~32sp)
  - Button size: ~80×80 circular
- Bottom: Large green circular call button (`CircleAvatar` radius ~35, `AppColors.primary` background, white phone icon). No-op `onTap`.
- `dispose()`: properly disposes `TextEditingController`

---

### [MODIFY] `call_history_tile.dart`

**Path**: `lib/features/call_history/presentation/widgets/call_history_tile.dart`

**Changes**:
- The existing `onTap` callback already exists and is used for redialing. The `CallsHistoryScreen` will be updated to navigate to Call Information on tile tap instead (see below). No changes needed to `CallHistoryTile` itself — the `onTap` callback is already generic.

---

### [MODIFY] `calls_history_screen.dart`

**Path**: `lib/features/call_history/presentation/pages/calls_history_screen.dart`

**Changes**:
- Update `_redial` method (or add new `_openCallInfo` method) to navigate to the Call Information screen instead of directly redialing:
  ```dart
  void _openCallInfo(BuildContext context, CallHistoryRecord record) {
    context.push(AppRouterName.callInfo, extra: record);
  }
  ```
- Update the `CallHistoryTile` `onTap` to call `_openCallInfo` instead of `_redial`
- Update FAB `onPressed` to navigate to `AppRouterName.selectContact` (new route) instead of the generic contacts screen

---

### [MODIFY] `app_router.dart`

**Path**: `lib/core/routing/app_router.dart`

**Changes**:
- Add 3 new route constants in `AppRouterName`:
  ```dart
  static const String callInfo = '/call_info';
  static const String selectContact = '/select_contact';
  static const String dialpad = '/dialpad';
  ```
- Add 3 new `GoRoute` entries following existing patterns:
  ```dart
  GoRoute(
    path: AppRouterName.callInfo,
    builder: (context, state) {
      final record = state.extra as CallHistoryRecord;
      return CallInformationScreen(record: record);
    },
  ),
  GoRoute(
    path: AppRouterName.selectContact,
    builder: (context, state) => const SelectContactScreen(),
  ),
  GoRoute(
    path: AppRouterName.dialpad,
    builder: (context, state) => const DialpadScreen(),
  ),
  ```

---

### [MODIFY] `en.json`

Add new localization keys (~25):
```json
"calls_info_title": "Call information",
"calls_info_messaging": "Messaging",
"calls_info_video_call": "Video call",
"calls_info_voice_call": "Voice call",
"calls_info_today": "Today",
"calls_info_outgoing": "Outgoing",
"calls_info_incoming": "Incoming",
"calls_info_not_answer": "Not answer",
"calls_info_answered": "Answered",
"calls_select_title": "Select a contact",
"calls_select_count": "{} contacts",
"calls_select_new_contact": "New contact",
"calls_select_call_number": "Call a number",
"calls_select_frequently": "Frequently contacted",
"calls_select_contacts": "contact",
"calls_dialpad_title": "Dialpad"
```

---

### [MODIFY] `ar.json`

Add corresponding Arabic translations:
```json
"calls_info_title": "معلومات المكالمة",
"calls_info_messaging": "الرسائل",
"calls_info_video_call": "مكالمة فيديو",
"calls_info_voice_call": "مكالمة صوتية",
"calls_info_today": "اليوم",
"calls_info_outgoing": "صادرة",
"calls_info_incoming": "واردة",
"calls_info_not_answer": "لم يرد",
"calls_info_answered": "تم الرد",
"calls_select_title": "اختيار جهة اتصال",
"calls_select_count": "{} جهة اتصال",
"calls_select_new_contact": "جهة اتصال جديدة",
"calls_select_call_number": "الاتصال برقم",
"calls_select_frequently": "الأكثر اتصالاً",
"calls_select_contacts": "جهات الاتصال",
"calls_dialpad_title": "لوحة الأرقام"
```

---

## Complexity Tracking

No constitution violations. No complexity justifications needed.
