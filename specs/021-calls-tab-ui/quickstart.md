# Quickstart: Calls Tab UI

**Feature**: 021-calls-tab-ui  
**Branch**: `021-calls-tab-ui`

## Prerequisites

- Flutter SDK 3.x installed
- Project dependencies installed (`flutter pub get`)

## Running

```bash
# From project root
flutter run
```

Navigate to the **Calls** tab (4th bottom nav item) to see the Calls History screen.

## New Screens

| Screen | Navigation Path |
|--------|-----------------|
| Calls History | Bottom nav → Calls tab (index 3) |
| Call Information | Calls History → tap any call entry |
| Select Contact | Calls History → tap green FAB |
| Dialpad | Select Contact → tap "Call a number" |

## New Localization Keys

All new keys are prefixed with `calls_info_`, `calls_select_`, or `calls_dialpad_` and are defined in both `en.json` and `ar.json`.

## Architecture

All new screens live in `lib/features/call_history/presentation/pages/` and follow the existing Clean Architecture pattern. No new Cubits, repositories, or data sources are introduced — all screens use hardcoded mock data.
