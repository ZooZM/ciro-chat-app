# Contract: Calls History UI (FR-VoIP-04)

Matches the provided mockup (`images_ui/call_history.png`).

## Navigation contract

- `chat_list_screen.dart` `_buildBody(context)` gains:
  ```dart
  if (_currentIndex == 3) return const CallsHistoryScreen();
  ```
  (The "Calls" nav item at index 3 already exists; no nav-bar change.)
- `floatingActionButton` stays gated to `_currentIndex == 0` (Calls screen has its own new-call action).

## Screen contract: calls_history_screen.dart

| Region | Spec |
|---|---|
| App bar | Large bold title "Calls" (left), no logout/lang actions. |
| Search | Rounded `TextField` with leading search icon, hint "Search", below the title; filters list by contact name (FR-VoIP-04). |
| Section header | "Recent" label above the list. |
| List | `ListView` of `CallHistoryTile`, sorted `startedAt` DESC, streamed from `CallHistoryCubit`. |
| New-call action | Green rounded button (bottom-right, per mockup) → contact/recipient selection to start a call. |
| Empty state | Friendly empty message when no records (edge case). |

## Item contract: call_history_tile.dart

| Slot | Content |
|---|---|
| Leading | Circular avatar — initials on `avatarColorSeed` background (or image when `avatarUrl` present, via `CachedNetworkImage`). |
| Title | `contactName`; **red** when `isMissed`. |
| Subtitle | direction arrow (↙ incoming / ↗ outgoing; **red** when missed) + " " + relative time ("Today 1:10 AM"). |
| Trailing | call-type icon — `Icons.videocam` (video) or `Icons.call` (voice). |
| onTap | Redial: initiate a call to `contactUserId` with `callType` (1:1) or open group. |

## Cubit contract: call_history_cubit.dart

```dart
sealed class CallHistoryState extends Equatable { }
class CallHistoryLoading extends CallHistoryState {}
class CallHistoryLoaded  extends CallHistoryState {
  final List<CallHistoryRecord> records; // already filtered by query
  final String query;
}
class CallHistoryError extends CallHistoryState { final String message; }

class CallHistoryCubit extends Cubit<CallHistoryState> {
  CallHistoryCubit(this._repo);
  void load();                 // subscribe to repo.watchAll()
  void search(String query);   // filter in-memory / via repo.search
  Future<void> close();        // cancel stream sub (§V)
}
```

- States extend `Equatable` (§II); repo returns `Either<Failure, T>` (§VII); errors surface as a non-blocking message, not raw exceptions.

## i18n

- `nav_calls` already exists. Add keys: `calls_title`, `calls_search_hint`, `calls_recent`, `calls_empty`.
