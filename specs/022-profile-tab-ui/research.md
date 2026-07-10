# Research: Profile Tab UI

No unknowns or complex technical decisions to clarify. The feature is explicitly defined as UI-only with hardcoded mock data and `easy_localization`. 

## Technical Decisions
- **Feature Location**: A new `profile` feature directory will be created at `lib/features/profile`.
- **State Management**: Local state (`StatefulWidget`) will be used where necessary (e.g., wallet balance visibility toggle, appearance selection) since no global state or backend integration is required at this stage.
- **Mock Data**: All mock data will be co-located in `lib/features/profile/presentation/data/mock_profile_data.dart`.
