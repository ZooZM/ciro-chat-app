# Implementation Plan: Live Translation Captions Overlay (Frontend MVP)

**Branch**: `014-status-feature-integration` (spec lives in `specs/015-live-translation-captions/`; see note in Project Structure) | **Date**: 2026-06-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-live-translation-captions/spec.md`

## Summary

Add a self-contained `translation` feature module to the Flutter app that lets a listener
enable live translation for a remote speaker on the **Group Call** screen and see
interim/final captions overlaid on that speaker's video tile, sourced from the LiveKit
**data channel** (`topic: "translation"`, schema per the backend's
`contracts/caption-data-channel.md`) and controlled via new `translation:*` Socket.IO
events on the existing `SocketService` (per `contracts/socket-events.md`). The hot path
(per-utterance caption text, updating multiple times/sec) is isolated from
`flutter_bloc`'s `Equatable`-diffed rebuild cycle: a single per-call `TranslationCubit`
owns one `ValueNotifier<Caption?>` per speaker, and a small `CaptionOverlay` widget
(`ValueListenableBuilder`) is the *only* thing that rebuilds on a caption update — the
video grid, tiles, and controls are untouched. Coarse, infrequent state (which speakers
have translation on, denial/unavailable banners) lives in the Cubit's normal `Equatable`
state. All three spec user stories are in scope — including **US3** (listener turns
translation on/off per speaker). Out of scope per spec Assumptions: credits/billing UI
and multi-target-language fan-out (more than one target language per (listener, speaker)
at once) — backend Phases 5-6 are not yet implemented.

## Technical Context

**Language/Version**: Dart 3.9 (`sdk: ^3.9.2`), Flutter (existing app).

**Primary Dependencies**:
- `flutter_bloc: ^9.1.1` + `equatable: ^2.0.8` — `TranslationCubit` (constitution II).
- `livekit_client: ^2.6.4` — `DataReceivedEvent` (`participant`, `data: List<int>`,
  `topic: String?`) on the existing `Room`/`EventsListener<RoomEvent>` already created in
  `GroupCallScreen`.
- `socket_io_client` (via existing `SocketService` singleton, constitution IV) — new
  `translation:subscribe` / `translation:unsubscribe` / `translation:changeLanguage`
  emitters and `translation:subscribed` / `translation:unsubscribed` /
  `translation:denied` / `translation_unavailable` listeners.
- `get_it` / `injectable` — DI registration for the new Cubit/repository/datasources,
  matching existing `@injectable` / `@LazySingleton` patterns.

**Storage**: N/A. Captions are ephemeral/in-memory only for the active call (spec
Assumptions: no persisted transcript history). No `sqflite`/SharedPreferences use.

**Testing**: `flutter_test` + `bloc_test: ^10.0.0` + `mocktail: ^1.0.4` (existing repo
conventions) — `TranslationCubit` unit tests (payload parsing, stale/out-of-order
suppression, subscribe/unsubscribe lifecycle) and a `CaptionModel.fromJson` unit test.

**Target Platform**: iOS + Android via Flutter, integrated into the existing
`GroupCallScreen` (`lib/features/video_call/presentation/pages/group_call_screen.dart`).

**Project Type**: Mobile app feature module — new `lib/features/translation/` following
the Clean Architecture layout (constitution I).

**Performance Goals**: Video grid sustains 30+ FPS (target 60 FPS) during active
captioning (SC-003); interim captions ≤1s after speech starts, finals ≤2s after sentence
end (SC-001/SC-002, inherited from backend SLAs); enabling translation surfaces the first
caption within ≤5s (SC-005) and disabling removes captions within ≤1s (SC-006).

**Constraints**:
- Caption updates MUST NOT call `setState`/`emit` on anything that rebuilds the video
  grid or tiles (FR-007, FR-015) — only the per-tile `CaptionOverlay`
  (`ValueListenableBuilder`) and a small bottom caption banner rebuild.
- Backend contracts (`caption-data-channel.md`, `socket-events.md` in
  `chat-app-backend/specs/001-realtime-call-translation/contracts/`) are authoritative and
  unchanged by this feature (spec Assumption).
- Reuse the existing `Room`/`EventsListener<RoomEvent>` already created in
  `GroupCallScreen._connectToRoom` and the existing `SocketService` singleton — no second
  socket connection, no second LiveKit room join.
- Out of scope for this slice: `VideoCallScreen` (1:1 call), `VoiceCallScreen`, credits
  low/exhausted UI, multi-target-language fan-out per speaker.

**Scale/Scope**: One new feature module (~10 files: 2 entities, 1 repository interface +
impl, 2 datasources, 1 model, 1 cubit + state, 2-3 widgets), plus additive changes to
`SocketService` (new event wiring) and `GroupCallScreen`/`_ParticipantTile`
(overlay + toggle wiring). Single target language per (listener, speaker).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Compliance approach | Status |
|---|-----------|---------------------|--------|
| I | Clean Architecture | New `lib/features/translation/` with `data/` (datasources, models, repository impl), `domain/` (entities, repository interface), `presentation/` (`bloc/`, `widgets/`). Widgets contain no business logic — only render `Caption?`/`TranslationStatus` and call Cubit methods. | ✅ PASS |
| II | State Management (Cubit) | `TranslationCubit extends Cubit<TranslationState>`; `TranslationState extends Equatable` covers coarse per-speaker subscription status (on/off/pending/denied/unavailable) — changes a few times per call, safe for `BlocBuilder`. The high-frequency caption text/stability never enters `state`; it lives in per-speaker `ValueNotifier<Caption?>` owned by the same Cubit (precedent: `SocketService.isConnectedNotifier`). See Complexity Tracking. | ⚠ PASS w/ noted pattern |
| III | Offline-First | N/A — no persisted data; captions are live/ephemeral per spec Assumptions. Documented as N/A, not a violation. | ✅ N/A |
| IV | Socket.IO | New `translation:*` emit/listen wiring added to the existing singleton `SocketService`, following the `data is! Map` → `Map<String,dynamic>.from(data)` pattern (IV-A) for every new `_socket?.on(...)`. Idempotent: repeated `subscribed`/`unsubscribed` acks for the same speaker are safe no-ops. | ✅ PASS |
| V | Teardown | `TranslationCubit.close()` cancels the data-channel subscription, disposes all per-speaker `ValueNotifier`s, and emits `translation:unsubscribe` for any still-active subscriptions. `GroupCallScreen.dispose()` closes the Cubit (via `BlocProvider`) before `_room?.disconnect()`. | ✅ PASS |
| VI | Code Quality | `flutter_lints` clean; `snake_case` files (`caption_overlay.dart`, `translation_cubit.dart`, ...); `PascalCase` classes; no comments except non-obvious invariants (e.g., stale-segment suppression rule). | ✅ PASS |
| VII | Error Handling | Control-plane repository methods (`subscribe`/`unsubscribe`/`changeLanguage`) return `Either<Failure, Unit>` (`fpdart`) per VII "Return Types" — `Left(SocketFailure)` when the emit cannot be dispatched (e.g. socket disconnected), `Right(unit)` on successful dispatch; the eventual subscribe/deny outcome still arrives via the control-plane callbacks. `translation:denied` / `translation_unavailable` map to a small `TranslationStatus` enum surfaced as a non-blocking badge/snackbar on the speaker's tile — never a raw exception or dialog. The caption ingestion path (`attachRoom` → `Stream<Caption>`) is fire-and-forget: data-channel JSON parse failures are caught, logged via `debugPrint`, and dropped (VII "Silent Failures"), so it does not use `Either`. | ✅ PASS |

No unjustified violations. The one noted pattern (Cubit + per-speaker `ValueNotifier` for
the hot path) is recorded in Complexity Tracking with precedent and rationale.

## Project Structure

### Documentation (this feature)

```text
specs/015-live-translation-captions/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/            # Phase 1 output (references to backend contracts; no new APIs)
│   └── frontend-integration.md
└── checklists/
    └── requirements.md
```

> **Note on branch**: `setup-plan.sh` reports the current git branch as
> `014-status-feature-integration` (the branch was not switched for this spec, per the
> /speckit-specify step, to avoid disturbing in-progress uncommitted work on that
> feature). The spec/plan/docs for this feature live under
> `specs/015-live-translation-captions/` regardless of branch name; a dedicated
> `015-live-translation-captions` branch can be cut before implementation if desired.

### Source Code (repository root)

```text
lib/
├── core/
│   └── network/
│       └── socket_service.dart            # ADDITIVE: translation:* emitters + typed callbacks
└── features/
    └── translation/
        ├── data/
        │   ├── datasources/
        │   │   ├── translation_data_channel_datasource.dart  # owns its EventsListener; Room.DataReceivedEvent (topic "translation") -> Stream<Caption>
        │   │   └── translation_socket_datasource.dart        # wraps SocketService translation:* events
        │   ├── models/
        │   │   └── caption_model.dart      # fromJson per backend caption-data-channel.md (v, type, speakerId, sourceLanguage, targetLanguage, text, segmentId, seq, ts)
        │   └── repositories/
        │       └── translation_repository_impl.dart
        ├── domain/
        │   ├── entities/
        │   │   ├── caption.dart                  # Caption (speakerId, text, type, targetLanguage, sourceLanguage, segmentId, seq)
        │   │   └── translation_subscription.dart # per-(speaker) toggle/status entity
        │   └── repositories/
        │       └── translation_repository.dart
        └── presentation/
            ├── bloc/
            │   ├── translation_cubit.dart   # owns Room attach, per-speaker ValueNotifier<Caption?>, subscribe/unsubscribe/changeLanguage
            │   └── translation_state.dart   # Equatable: Map<speakerId, TranslationStatus>
            └── widgets/
                ├── caption_overlay.dart           # ValueListenableBuilder<Caption?> -> per-tile caption text
                ├── caption_banner.dart            # FR-010 fallback: bottom banner for off-screen speakers
                └── translation_toggle_sheet.dart  # CC button + language picker, calls cubit.subscribe/unsubscribe/changeLanguage

# Touch points in existing code (additive only):
lib/features/video_call/presentation/pages/group_call_screen.dart
  - wrap body in BlocProvider<TranslationCubit>(create: (_) => getIt<TranslationCubit>())
  - after _room!.connect(...): call translationCubit.attachRoom(_room!, roomId: ...)
    (the Cubit subscribes to TranslationRepository.attachRoom(room)'s Stream<Caption>;
    the screen never touches raw DataReceivedEvents — ingestion is fully inside the
    data layer, keeping the UI decoupled per Constitution I)
  - _buildRemoteTile: pass translationCubit.captionNotifier(participant.identity) +
    translationCubit.statusFor(participant.identity) into _ParticipantTile
  - _ParticipantTile: add optional `caption` (ValueListenable<Caption?>?) and
    `onTapTranslate` (VoidCallback?) params; render CaptionOverlay + small CC icon
  - add CaptionBanner above _buildControls()
  - dispose(): translationCubit.detachRoom() before _room?.disconnect()

test/
└── features/
    └── translation/
        ├── data/models/caption_model_test.dart
        └── presentation/bloc/translation_cubit_test.dart
```

**Structure Decision**: New self-contained `lib/features/translation/` module per
Constitution I, consumed only by `GroupCallScreen` for this MVP. All cross-module edits
are additive (`SocketService` event wiring, `_ParticipantTile`/`group_call_screen.dart`
wiring) — no existing files are restructured.

## Complexity Tracking

> Only the one noted Constitution II pattern needs justification.

| Pattern | Why Needed | Simpler Alternative Rejected Because |
|---------|------------|---------------------------------------|
| `TranslationCubit` keeps high-frequency caption data (`ValueNotifier<Caption?>` per speaker) **outside** its `Equatable` `state`, alongside a normal `Equatable` state for coarse subscription status. | FR-007/FR-015/SC-003 require captions updating multiple times/sec to **never** trigger a `BlocBuilder` rebuild of the video grid. A `Cubit<TranslationState>` that put captions in `state` would re-diff and rebuild every `BlocBuilder<TranslationCubit, TranslationState>` ancestor on every interim update — exactly the regression this feature must avoid. | (1) Putting captions in `state` with a very narrow `BlocBuilder` per tile still re-runs `Equatable.props` comparison and the builder for that tile dozens of times/sec — acceptable, but `ValueNotifier` is strictly cheaper and is already an approved pattern in this codebase (`SocketService.isConnectedNotifier`, constitution IV). (2) A separate `Cubit` instance per video tile would require dynamic `BlocProvider` creation/teardown per tile as the participant list changes (join/leave, screen resize), adding lifecycle complexity disproportionate to a `Map<String, ValueNotifier<Caption?>>` owned by one per-call Cubit. |
