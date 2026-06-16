# Phase 1 Data Model: Live Translation Captions Overlay (Frontend MVP)

All entities are ephemeral (in-memory, per active call). No persistence layer is added —
nothing is written to `sqflite`/`SharedPreferences`/`FlutterSecureStorage`.

## 1. `Caption` (domain entity)

`lib/features/translation/domain/entities/caption.dart`

| Field | Type | Notes |
|---|---|---|
| `speakerId` | `String` | LiveKit participant identity that produced the speech (FR-007). Used to look up the `_ParticipantTile`. |
| `text` | `String` | Caption text — translated, or transcription if `sourceLanguage == targetLanguage` (backend FR-012). |
| `type` | `CaptionType` (`interim` \| `final_`) | Stability (FR-005/FR-006/FR-009). `final_` because `final` is a Dart keyword. |
| `sourceLanguage` | `String` | BCP-47, detected source language (display-only for MVP). |
| `targetLanguage` | `String` | BCP-47, language of `text`. |
| `segmentId` | `String` | Groups interim updates + their closing final into one displayed line (FR-005, FR-006). |
| `seq` | `int` | Monotonic per `segmentId`; used for stale/out-of-order suppression (FR-012). |
| `ts` | `int` | Server epoch ms — display/debug only. |

`extends Equatable` (props: all fields) so `ValueNotifier<Caption?>` consumers
(`ValueListenableBuilder`) only rebuild when a field actually changes.

**Validation / invariants**:
- A `Caption` is only ever constructed from a successfully-parsed `CaptionModel`
  (§3) — no client-side validation rules beyond non-empty `speakerId`/`segmentId`
  (rows failing this are dropped silently, per Constitution VII "Silent Failures").

## 2. `TranslationSubscription` (domain entity)

`lib/features/translation/domain/entities/translation_subscription.dart`

| Field | Type | Notes |
|---|---|---|
| `speakerId` | `String` | The speaker this listener has (or is changing) translation for. |
| `targetLanguage` | `String` | Currently selected/requested target language (FR-001). |
| `status` | `TranslationStatus` | See state machine below. |
| `unavailableReason` | `String?` | Set when `status == unavailable` (`language_undetected` \| `unsupported_language` \| `service_outage`, from `translation_unavailable`). |
| `deniedReason` | `String?` | Set when `status == denied` (`insufficient_credits` \| `not_a_participant` \| `unsupported_language` \| `unauthenticated`, from `translation:denied`). |

`extends Equatable` — this is what lives in `TranslationState` and drives
`BlocBuilder` for the toggle/CC button and any denial/unavailable badges (low
frequency — safe for normal Cubit rebuilds).

### `TranslationStatus` enum

```text
off        — listener has not enabled translation for this speaker (default; no entry
              in TranslationState.subscriptions)
pending    — translation:subscribe sent, awaiting translation:subscribed/denied (FR-001)
active     — translation:subscribed received; captions may arrive (FR-001, US1)
denied     — translation:denied received; not retried automatically (FR-002 still lets
              the user try again / pick a different language)
unavailable— translation_unavailable received while active; captions paused but
              subscription intent remains until the user disables it (FR-014)
```

### State transitions

```text
off --(user enables, FR-001)--> pending
pending --(translation:subscribed)--> active
pending --(translation:denied)--> denied
active --(user changes language, FR-002/US3)--> pending  [re-uses translation:changeLanguage]
active --(translation_unavailable)--> unavailable
unavailable --(translation:subscribed for same speaker, e.g. backend recovers)--> active
{pending, active, denied, unavailable} --(user disables, FR-002)--> off
  [emits translation:unsubscribe; removes ValueNotifier entry; clears CaptionOverlay]
{pending, active, unavailable} --(speaker leaves call, FR-013)--> off
  [local cleanup only; translation:unsubscribe still emitted for backend hygiene]
```

## 3. `CaptionModel` (data model — wire format)

`lib/features/translation/data/models/caption_model.dart`

Mirrors the backend's `contracts/caption-data-channel.md` payload **exactly** (spec
Assumption: existing backend contract is authoritative):

```jsonc
{
  "v": 1,
  "type": "interim" | "final",
  "speakerId": "string",
  "sourceLanguage": "string",
  "targetLanguage": "string",
  "text": "string",
  "segmentId": "string",
  "seq": 0,
  "ts": 0
}
```

`CaptionModel.fromJson(Map<String, dynamic> json)`:
- Required, non-empty: `speakerId`, `segmentId`, `type` (must be `"interim"` or
  `"final"`), `text` (empty string allowed — an empty interim is valid mid-recognition).
- `seq`/`ts` default to `0` if missing/non-numeric (defensive — contract guarantees
  presence, but parsing must not throw on a malformed packet, per Constitution VII).
- Any parse failure (wrong type, missing required field) → `fromJson` returns `null`
  (not a thrown exception); `TranslationDataChannelDataSource` drops `null` results and
  `debugPrint`s once.
- `v` is read but not currently branched on (schema version 1 only); a future `v != 1`
  is logged and the packet is still attempted with best-effort field access.

`CaptionModel.toEntity()` → `Caption` (maps `"final"` → `CaptionType.final_`).

## 4. `TranslationState` (Cubit state — coarse, `Equatable`)

`lib/features/translation/presentation/bloc/translation_state.dart`

```dart
class TranslationState extends Equatable {
  final Map<String, TranslationSubscription> subscriptions; // key: speakerId

  const TranslationState({this.subscriptions = const {}});

  @override
  List<Object?> get props => [subscriptions];
}
```

- One entry per speaker the listener has ever toggled on during this call
  (`off` entries are removed from the map entirely — absence == `off`).
- Drives: CC-button highlight state, denial snackbars, "translation unavailable" badge
  on a tile.
- Does **NOT** contain `Caption` data — see §5.

## 5. Per-speaker caption hot path (NOT in `TranslationState`)

Owned directly by `TranslationCubit` (not part of `Equatable` state, per
research.md §1):

```dart
final Map<String, ValueNotifier<Caption?>> _captionNotifiers = {};
final ValueNotifier<Caption?> latestActiveCaption = ValueNotifier(null);

ValueNotifier<Caption?> captionNotifier(String speakerId) =>
    _captionNotifiers.putIfAbsent(speakerId, () => ValueNotifier(null));
```

- `_captionNotifiers[speakerId].value` is set on every accepted `Caption` for that
  speaker (§ research.md §3 for the accept/reject rule), and cleared (`null`) when the
  subscription returns to `off` (user disables, or speaker leaves the call — FR-013).
- `latestActiveCaption.value` is set alongside, for the `CaptionBanner` fallback
  (FR-010).
- All `ValueNotifier`s are `.dispose()`d in `TranslationCubit.close()` (Constitution V).

## 6. Repository interface

`lib/features/translation/domain/repositories/translation_repository.dart`

```dart
abstract class TranslationRepository {
  /// Begin listening for caption packets on [room]'s data channel.
  /// Returns a stream of parsed captions (already filtered to topic "translation").
  /// The data layer owns the underlying LiveKit listener — the UI never sees
  /// raw DataReceivedEvents (Constitution I: presentation stays decoupled from data).
  Stream<Caption> attachRoom(Room room);

  // Control-plane methods return Either<Failure, Unit> (fpdart) per Constitution VII.
  // Left(SocketFailure) when the emit cannot be dispatched (e.g. socket disconnected);
  // Right(unit) on successful dispatch. The eventual subscribe/deny/unavailable outcome
  // arrives asynchronously via the control-plane callbacks below.
  Either<Failure, Unit> subscribe({required String roomId, required String speakerId, required String targetLanguage});
  Either<Failure, Unit> unsubscribe({required String roomId, required String speakerId});
  Either<Failure, Unit> changeLanguage({required String roomId, required String speakerId, required String targetLanguage});

  // Control-plane callbacks (set once by TranslationCubit):
  set onSubscribed(void Function(String speakerId, String targetLanguage, int remainingSeconds)? cb);
  set onUnsubscribed(void Function(String speakerId)? cb);
  set onDenied(void Function(String speakerId, String reason)? cb);
  set onUnavailable(void Function(String speakerId, String reason, bool transient)? cb);

  // FR-016 reconnect auto-resume. Forwards SocketService's multicast reconnect API
  // (see tasks T007a) so the Cubit never touches SocketService directly. Multicast is
  // required because ChatCubit already consumes the legacy single onReconnected callback.
  void addReconnectListener(void Function() cb);
  void removeReconnectListener(void Function() cb);
}
```

`TranslationRepositoryImpl` composes `TranslationDataChannelDataSource` (LiveKit side —
owns its own `EventsListener<RoomEvent>` and exposes `Stream<Caption>`) and
`TranslationSocketDataSource` (wraps `SocketService`, constitution IV). The control
methods map a failed emit to `Left(SocketFailure)` and a successful dispatch to
`Right(unit)`; `attachRoom`'s stream is fire-and-forget (parse failures dropped with
`debugPrint`, Constitution VII "Silent Failures") and therefore is not wrapped in
`Either`.
