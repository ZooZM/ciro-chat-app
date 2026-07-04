# Research: Calls Tab UI

**Feature**: 021-calls-tab-ui  
**Date**: 2026-07-04

## Research Tasks

### 1. Existing Call History Infrastructure

**Decision**: Reuse the existing `call_history` feature module (`lib/features/call_history/`) which already has Clean Architecture layers (data/domain/presentation), `CallHistoryRecord` entity, `CallHistoryCubit`, and `CallHistoryTile` widget.

**Rationale**: The existing module already implements the Calls History screen (FR-002, FR-003) and is wired into the bottom nav via `ChatListScreen._buildBody()` at index 3. The current implementation uses `BlocProvider` + `CallHistoryCubit` with repository-backed data. The new screens (Call Information, Select Contact, Dialpad) extend this module rather than creating a new feature folder.

**Alternatives Considered**:
- Creating a separate `calls` feature module → rejected because the existing `call_history` module already owns this tab, and creating a parallel feature would split the call-related screens unnecessarily.

### 2. Contact Picker Pattern

**Decision**: Build the "Select Contact" screen as a new page within the `call_history` feature's presentation layer, using a local `StatefulWidget` with mock data for contact entries. No new Cubit is needed since the spec requires mock data only.

**Rationale**: The spec explicitly forbids device contacts integration (FR-014). A simple `StatefulWidget` with `setState` for selection state is appropriate. A `Cubit` would be over-engineering for purely mock data with no async operations.

**Alternatives Considered**:
- Reusing the existing `ContactsScreen` in `features/contacts/` → rejected because it has real device contacts integration, different layout (no radio buttons, no sections), and a fundamentally different purpose (chat initiation vs. call initiation).
- Creating a new Cubit → rejected as unnecessary overhead for a UI-only mock screen per constitution principle II (single responsibility).

### 3. Navigation Architecture

**Decision**: The new screens (Call Information, Select Contact for Calls, Dialpad) are registered as new GoRouter routes in `app_router.dart`. Calls History → Call Information navigates via `context.push()` with the `CallHistoryRecord` as `extra`. Select Contact and Dialpad navigate sequentially.

**Rationale**: This follows the established GoRouter pattern used by all other screens in the app (e.g., `incomingCall`, `outgoingCall`, `contacts`).

### 4. Localization Key Naming Convention

**Decision**: All new keys follow the existing `calls_*` prefix pattern (e.g., `calls_title`, `calls_recent`, `calls_search_hint` already exist). New keys for sub-screens use `calls_info_*`, `calls_select_*`, `calls_dialpad_*` prefixes.

**Rationale**: Consistent with existing keys in `en.json` and provides clear namespace separation between screens.

### 5. Avatar Color Palette

**Decision**: Reuse the existing `_avatarPalette` from `CallHistoryTile` and extract it to a shared utility or replicate the pattern in new widgets. The screenshots show distinct avatar colors (purple, green, red, yellow, pink, grey) matching the existing palette approach.

**Rationale**: The existing `CallHistoryTile` already implements this exact pattern with `avatarColorSeed` modulo selection.
