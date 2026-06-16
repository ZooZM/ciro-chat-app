# Tasks: Live Translation Captions Overlay (Frontend MVP)

**Input**: Design documents from `/specs/015-live-translation-captions/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/frontend-integration.md](./contracts/frontend-integration.md), [quickstart.md](./quickstart.md)

**Tests**: Included — `plan.md` Technical Context calls out `flutter_test` + `bloc_test` +
`mocktail` unit tests for `CaptionModel.fromJson` and `TranslationCubit`, and
`quickstart.md` "Automated checks" names `caption_model_test.dart` and
`translation_cubit_test.dart` explicitly.

**Organization**: Tasks are grouped by user story (US1/US2/US3 from spec.md, in priority
order) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are exact and relative to the repo root
  (`/Volumes/Zeyad/Documents/work/Flutter/ciro-chat-app`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the new feature module's directory skeleton per plan.md Project Structure

- [X] T001 Create the `lib/features/translation/` directory tree (`data/datasources/`,
  `data/models/`, `data/repositories/`, `domain/entities/`, `domain/repositories/`,
  `presentation/bloc/`, `presentation/widgets/`) and the matching
  `test/features/translation/` tree (`data/models/`, `presentation/bloc/`,
  `presentation/widgets/`), per [plan.md](./plan.md) "Project Structure"

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain/data/state layer that every user story depends on — the
`TranslationCubit`, its repository, and the LiveKit/Socket.IO plumbing must exist before
any UI wiring can compile or be tested.

- [X] T002 [P] Create `CaptionType` enum (`interim`, `final_`) and the `Caption` entity
  (`extends Equatable`; fields `speakerId`, `text`, `type`, `sourceLanguage`,
  `targetLanguage`, `segmentId`, `seq`, `ts` per data-model.md §1) in
  `lib/features/translation/domain/entities/caption.dart`

- [X] T003 [P] Create `TranslationStatus` enum (`off`, `pending`, `active`, `denied`,
  `unavailable`) and the `TranslationSubscription` entity (`extends Equatable`; fields
  `speakerId`, `targetLanguage`, `status`, `unavailableReason`, `deniedReason` per
  data-model.md §2) in
  `lib/features/translation/domain/entities/translation_subscription.dart`

- [X] T004 [P] Create `CaptionModel` data model with `fromJson(Map<String, dynamic>)`
  (returns `null` on any parse failure; `seq`/`ts` default to `0`; requires non-empty
  `speakerId`/`segmentId`/`type` ∈ {`interim`,`final`}) and `toEntity()` → `Caption`
  (mapping `"final"` → `CaptionType.final_`) per data-model.md §3, in
  `lib/features/translation/data/models/caption_model.dart`

- [X] T005 [P] Add `translation:*` Socket.IO event name constants
  (`translationSubscribe`, `translationUnsubscribe`, `translationChangeLanguage`,
  `translationSubscribed`, `translationUnsubscribed`, `translationDenied`,
  `translationUnavailable`) to `lib/core/network/socket_events.dart`, matching
  `contracts/frontend-integration.md` §2 event names exactly

- [X] T006 Define the `TranslationRepository` abstract interface in
  `lib/features/translation/domain/repositories/translation_repository.dart` per
  data-model.md §6 (depends on T002, T003):
  - `Stream<Caption> attachRoom(Room room)` — the data layer owns the LiveKit listener;
    the UI never sees raw `DataReceivedEvent`s (Constitution I)
  - `Either<Failure, Unit> subscribe/unsubscribe/changeLanguage(...)` — control methods
    return `Either<Failure, Unit>` (`fpdart`) per Constitution VII: `Left(SocketFailure)`
    when the emit cannot be dispatched (e.g. socket disconnected), `Right(unit)` on
    successful dispatch (the subscribe/deny outcome itself arrives via the callbacks below)
  - `onSubscribed`/`onUnsubscribed`/`onDenied`/`onUnavailable` callback setters

- [X] T007 Add `translation:*` emitters (`emitTranslationSubscribe`,
  `emitTranslationUnsubscribe`, `emitTranslationChangeLanguage`, each taking
  `roomId`/`speakerId`/`targetLanguage`) and four typed callbacks
  (`onTranslationSubscribed`, `onTranslationUnsubscribed`, `onTranslationDenied`,
  `onTranslationUnavailable`) to `lib/core/network/socket_service.dart`, each `_socket?.on`
  guarded with the `data is! Map` → `Map<String,dynamic>.from(data)` pattern (constitution
  IV-A), per `contracts/frontend-integration.md` §2 and using the constants from T005
  (depends on T005)

- [X] T007a Make socket reconnect notification multicast-safe in
  `lib/core/network/socket_service.dart` (depends on T007). `SocketService.onReconnected`
  is currently a **single** `void Function()?` already claimed by `ChatCubit`
  (`chat_cubit.dart:174`); a second assignment for FR-016 would clobber it. Add an
  additive multicast API — `void addReconnectListener(VoidCallback)` /
  `void removeReconnectListener(VoidCallback)` (or a broadcast `Stream<void>`) invoked
  alongside the existing `onReconnected?.call()` in the `onConnect` handler — and migrate
  `ChatCubit`'s existing `_socketService.onReconnected = ...` to the new API so both
  `ChatCubit` and `TranslationCubit` receive reconnect events. Keep `onReconnected`
  backward-compatible or remove it only after the `ChatCubit` migration in this task.

- [X] T008 [P] Create `TranslationDataChannelDataSource` with
  `Stream<Caption> attach(Room room)` that creates its **own**
  `EventsListener<RoomEvent>` (`room.createListener()`) — the data layer owns ingestion,
  the UI is never wired to `DataReceivedEvent` (research.md §2, Constitution I) — filters
  `DataReceivedEvent`s where `event.topic == 'translation'`, UTF-8 decodes + `jsonDecode`s
  `event.data` (using the `data is! Map` guard, IV-A), parses via `CaptionModel.fromJson`,
  drops `null` results with a single `debugPrint`, and emits `.toEntity()` results;
  exposes a `dispose()`/`detach()` that cancels the listener, in
  `lib/features/translation/data/datasources/translation_data_channel_datasource.dart`
  (depends on T002, T004)

- [X] T009 Create `TranslationSocketDataSource` wrapping `SocketService` — exposes
  `subscribe`/`unsubscribe`/`changeLanguage` (delegating to the T007 emitters with
  `roomId`/`speakerId`/`targetLanguage`) and `onSubscribed`/`onUnsubscribed`/`onDenied`/
  `onUnavailable` setters that forward the T007 callbacks, plus
  `addReconnectListener`/`removeReconnectListener` that forward the T007a multicast
  reconnect API (so `TranslationCubit` never touches `SocketService` directly), in
  `lib/features/translation/data/datasources/translation_socket_datasource.dart`
  (depends on T007, T007a)

- [X] T010 Implement `TranslationRepositoryImpl` (`@LazySingleton(as:
  TranslationRepository)`) composing `TranslationDataChannelDataSource` (T008) and
  `TranslationSocketDataSource` (T009) per data-model.md §6, in
  `lib/features/translation/data/repositories/translation_repository_impl.dart`:
  `attachRoom` returns the datasource's `Stream<Caption>`; `subscribe`/`unsubscribe`/
  `changeLanguage` wrap the emit in `Either<Failure, Unit>` (`Left(SocketFailure)` if
  dispatch fails, else `Right(unit)`), per Constitution VII (depends on T006, T008, T009)

- [X] T011 [P] Create `TranslationState` (`extends Equatable`; single field
  `Map<String, TranslationSubscription> subscriptions`, keyed by `speakerId`, absence ==
  `off`, per data-model.md §4) in
  `lib/features/translation/presentation/bloc/translation_state.dart` (depends on T003)

- [X] T012 Implement `TranslationCubit` (`@injectable`, `extends Cubit<TranslationState>`)
  in `lib/features/translation/presentation/bloc/translation_cubit.dart`:
  - `attachRoom(Room room, {required String roomId})` / `detachRoom()` — subscribes to
    `TranslationRepository.attachRoom(room)` (research.md §2)
  - `Map<String, ValueNotifier<Caption?>> _captionNotifiers` +
    `captionNotifier(String speakerId)` (lazy `putIfAbsent`) and
    `final ValueNotifier<Caption?> latestActiveCaption` (data-model.md §5)
  - Per-speaker `(segmentId, seq, type)` high-water-mark tracking implementing the
    stale/out-of-order suppression rule (research.md §3 / FR-012): a new `segmentId`
    always applies; a same-`segmentId` update applies only if `type == 'final'` or
    `seq >= trackedSeq`
  - FR-012 language filter: silently drop any `Caption` whose `targetLanguage` does not
    match `TranslationState.subscriptions[speakerId]?.targetLanguage`
  - `subscribe`/`unsubscribe`/`changeLanguage(speakerId, targetLanguage)` driving the
    `TranslationStatus` state machine (data-model.md §2) via the T010 repository,
    updating `TranslationState.subscriptions` through `emit()`; each call `.fold`s the
    repository's `Either<Failure, Unit>` — on `Left` leave the prior status unchanged
    (no optimistic `pending`) and surface it per Constitution VII, on `Right` advance to
    `pending`
  - Repository callbacks (`onSubscribed`/`onUnsubscribed`/`onDenied`/`onUnavailable`) set
    in the constructor, mapping to the corresponding state transitions
  - `close()` override: cancels the `attachRoom` caption `StreamSubscription`, removes the
    reconnect listener (T029), emits `translation:unsubscribe` for every `pending`/
    `active`/`unavailable` subscription, `.dispose()`s every `ValueNotifier` (including
    `latestActiveCaption`), then `super.close()` (Constitution V)
  (depends on T010, T011)

- [X] T013 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate
  `lib/core/di/injection.config.dart` so `TranslationCubit`, `TranslationRepositoryImpl`,
  `TranslationDataChannelDataSource`, and `TranslationSocketDataSource` are registered
  with `getIt` (depends on T002–T012, incl. T007a)

**Checkpoint**: `TranslationCubit` compiles, is DI-registered, and can be unit-tested in
isolation — user story implementation can now begin.

---

## Phase 3: User Story 1 - Listener sees live translated captions on the speaker's tile (Priority: P1) 🎯 MVP

**Goal**: A listener who enables translation for a speaking participant sees translated
captions appear over that speaker's video tile, updating live (interim) and settling into
a corrected line (final), correctly attributed to the right tile.

**Independent Test**: Join a call where the backend translation pipeline is already
running for a speaker (backend Phases 1-4). Enable translation for that speaker on the
client. Verify translated captions appear over that speaker's tile, update live while
they talk, and resolve into a stable final line when they finish a sentence.

### Tests for User Story 1

- [X] T014 [P] [US1] Write `CaptionModel.fromJson` unit tests — valid `interim` payload,
  valid `final` payload, malformed payload (missing `speakerId`/`segmentId`/invalid
  `type`) → `null`, missing `seq`/`ts` default to `0` — in
  `test/features/translation/data/models/caption_model_test.dart` (depends on T004)

- [X] T015 [P] [US1] Write `TranslationCubit` `bloc_test` cases for caption ingestion:
  in-order interim updates apply to `captionNotifier(speakerId)`, a `final` freezes the
  segment, a late/lower-`seq` interim for an already-finalized or higher-`seq` segment is
  dropped, a new `segmentId` always starts a new line, and `latestActiveCaption` tracks
  the most recent accepted caption across subscribed speakers — in
  `test/features/translation/presentation/bloc/translation_cubit_test.dart` (depends on
  T012; mock `TranslationRepository` with `mocktail`)

### Implementation for User Story 1

- [X] T016 [P] [US1] Create `CaptionOverlay` widget — `ValueListenableBuilder<Caption?>`
  rendering `caption.text` with visually distinct styling for `CaptionType.interim` vs
  `CaptionType.final_` (FR-009), rendering nothing when `null`, wrapping/truncating long
  text within a bounded box without resizing its parent (FR-011) — in
  `lib/features/translation/presentation/widgets/caption_overlay.dart` (depends on T002)

- [X] T017 [P] [US1] Create `CaptionBanner` widget — `ValueListenableBuilder<Caption?>`
  bound to `TranslationCubit.latestActiveCaption`, rendering `"{speakerName}: {text}"`
  (FR-010 off-screen/camera-off fallback), resolving `speakerName` from the participant
  list passed in — in
  `lib/features/translation/presentation/widgets/caption_banner.dart` (depends on T002)

- [X] T018 [US1] In `lib/features/video_call/presentation/pages/group_call_screen.dart`:
  wrap the screen body in `BlocProvider<TranslationCubit>(create: (_) =>
  getIt<TranslationCubit>())`, and in `_connectToRoom` after `await _room!.connect(url,
  token)` call `translationCubit.attachRoom(_room!, roomId: <chatRoomId from CallActive
  state>)`. Caption ingestion is owned entirely by the data layer (the Cubit subscribes
  to `TranslationRepository.attachRoom`'s `Stream<Caption>`, T012) — do **not** wire any
  `DataReceivedEvent` handler into the screen's `_roomEventsListener`, keeping the UI
  decoupled from the raw data channel (research.md §2, Constitution I) (depends on T012,
  T013)

- [X] T019 [US1] Extend `_ParticipantTile` in `group_call_screen.dart` with an optional
  `ValueListenable<Caption?>? caption` parameter and render `CaptionOverlay` positioned
  over/below the video (FR-004); in `_buildRemoteTile`, pass
  `context.read<TranslationCubit>().captionNotifier(participant.identity)` (depends on
  T016, T018)

- [X] T020 [US1] Add `CaptionBanner` once, above `_buildControls()`, in
  `_buildCallBody()` of `group_call_screen.dart`, passing the current
  `remoteParticipants` list for name resolution (depends on T017, T018)

- [X] T021 [US1] In `group_call_screen.dart` `dispose()`, call
  `translationCubit.detachRoom()` before `_room?.disconnect()` (depends on T018;
  Constitution V — `translationCubit` is read via `context.read` before the widget tree
  is torn down)

**Checkpoint**: User Story 1 is independently testable end-to-end against a live backend
— enabling translation (manually via cubit call, ahead of US3's UI) shows live interim
and final captions on the correct tile.

---

## Phase 4: User Story 2 - Captions never disrupt call performance (Priority: P1)

**Goal**: While captions stream and update multiple times per second, the video grid,
other tiles, and call controls continue to render smoothly with zero extra rebuilds
outside the affected speaker's caption area.

**Independent Test**: With translation enabled for one or more speakers and captions
updating at the maximum expected rate, observe the call screen during sustained caption
activity and confirm video playback remains smooth and the rest of the UI (other tiles,
call controls) continues to respond normally.

### Implementation for User Story 2

- [X] T022 [US2] Add a widget test that pumps `GroupCallScreen`'s `_ParticipantTile` (or
  an extracted equivalent) inside a `BlocProvider<TranslationCubit>` +
  `BlocBuilder<CallCubit, CallState>`, drives several `captionNotifier(speakerId).value =
  ...` updates (interim → interim → final), and asserts the `CallCubit`
  `BlocBuilder`/video-grid subtree's `build()` is **not** re-invoked while
  `CaptionOverlay`/`CaptionBanner` do rebuild (FR-007/FR-015/SC-007) — in
  `test/features/translation/presentation/widgets/caption_overlay_test.dart` (depends on
  T016, T017, T019, T020)

- [ ] T023 [US2] Manual performance validation per `quickstart.md` step 4: with captions
  actively updating, scroll the participant grid and tap mute/camera controls; confirm no
  visible stutter/frame drop and immediate control response (optionally run in Flutter
  profile mode and confirm the video-grid subtree does not rebuild on each caption
  update) (depends on T018–T021)

**Checkpoint**: User Stories 1 and 2 both hold — captions render correctly and the call
screen stays smooth under sustained caption traffic.

---

## Phase 5: User Story 3 - Listener turns translation on or off per speaker (Priority: P2)

**Goal**: A listener can enable/disable live translation for an individual speaker at any
point, pick the target language, and these actions are independent per speaker and don't
interrupt the call.

**Independent Test**: During an active call, enable translation for Speaker A and confirm
captions begin appearing for them. Disable translation for Speaker A and confirm captions
stop appearing for them, while the call continues uninterrupted and any captions for
Speaker B (if enabled) are unaffected.

### Tests for User Story 3

- [X] T024 [P] [US3] Extend `translation_cubit_test.dart` with lifecycle `bloc_test`
  cases: `subscribe()` → `pending` → `translation:subscribed` → `active`;
  `translation:denied` → `denied`; `active` → `translation_unavailable` → `unavailable`;
  `changeLanguage()` re-enters `pending` then `active` with the new language;
  `unsubscribe()` → `off` (removes the `subscriptions` entry, clears
  `captionNotifier(speakerId)`); `close()` emits `translation:unsubscribe` for every
  `pending`/`active`/`unavailable` speaker and disposes all `ValueNotifier`s; and FR-016
  reconnect auto-resume (T029) re-emits `translation:subscribe` for previously
  `pending`/`active` speakers using their last-selected `targetLanguage` — in
  `test/features/translation/presentation/bloc/translation_cubit_test.dart` (depends on
  T012, T026, T028, T029)

### Implementation for User Story 3

- [X] T025 [P] [US3] Create `TranslationToggleSheet` widget — a modal bottom sheet with a
  CC on/off toggle and a target-language picker (list of supported languages per
  `contracts/frontend-integration.md`), returning the selected `targetLanguage` (or
  `null`/"off") to its caller — in
  `lib/features/translation/presentation/widgets/translation_toggle_sheet.dart` (depends
  on T002, T003)

- [X] T026 [US3] Add a default-target-language resolver to `TranslationCubit` (FR-001):
  when enabling translation for a speaker for the first time, default `targetLanguage` to
  `context.locale.languageCode` (via `easy_localization`, passed in by the caller) if it
  is in the supported-languages list, else fall back to the configured default (`"en"`
  per spec Assumptions); pre-select this value in `TranslationToggleSheet` (T025) (depends
  on T012, T025)

- [X] T027 [US3] In `group_call_screen.dart`: add a CC icon + `onTapTranslate` callback to
  `_ParticipantTile`; on tap, show `TranslationToggleSheet` (T025) and call
  `context.read<TranslationCubit>().subscribe(...)` /
  `.unsubscribe(...)` / `.changeLanguage(...)` for `participant.identity`, with the CC
  icon's highlight state driven by `BlocBuilder<TranslationCubit, TranslationState>`
  reading `state.subscriptions[participant.identity]?.status` (depends on T018, T019,
  T025, T026)

- [X] T028 [US3] Wire `translation:denied` → non-blocking `SnackBar` (reason-specific
  message, Constitution VII) and `translation_unavailable` → small "translation
  unavailable" badge on the affected `_ParticipantTile` (FR-002/FR-014), both driven by
  `BlocBuilder<TranslationCubit, TranslationState>` on `state.subscriptions[speakerId]` —
  in `group_call_screen.dart` (depends on T012, T027)

- [X] T029 [US3] Implement FR-016 reconnect auto-resume in `TranslationCubit`: register a
  listener via the multicast reconnect API from T007a (`addReconnectListener`, surfaced
  through `TranslationSocketDataSource`/repository so the Cubit stays off `SocketService`
  directly per Clean Architecture) that, for every speaker whose
  `TranslationSubscription.status` was `pending`/`active`/`unavailable` before the drop,
  re-emits `translation:subscribe` with that speaker's last-selected `targetLanguage` and
  sets `status = pending`; the listener is removed in `close()` (Constitution V) (depends
  on T007a, T012)

- [X] T030 [US3] Implement FR-013 cleanup in `TranslationCubit`/`group_call_screen.dart`:
  when a participant leaves the call (existing `ParticipantDisconnectedEvent` /
  `remoteParticipants` change in `_onRoomUpdate`), remove that speaker's
  `TranslationState.subscriptions` entry, dispose/clear its `captionNotifier`, and
  best-effort emit `translation:unsubscribe` (depends on T012, T018)

- [X] T031 [P] [US3] Add translation toggle/picker/badge/snackbar strings (CC button
  label, language picker title, "translation unavailable" badge text, per-`reason`
  denial snackbar messages) to `assets/translations/en.json` and
  `assets/translations/ar.json`, and reference them via `.tr()` from T025/T027/T028
  (depends on T025, T028)

**Checkpoint**: All three user stories are independently functional — translation can be
toggled per speaker, captions render correctly and performantly, and reconnect/leave edge
cases are handled.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T032 [P] Run `flutter analyze` and resolve all issues in
  `lib/features/translation/` and the modified `lib/core/network/socket_service.dart`,
  `lib/core/network/socket_events.dart`, and
  `lib/features/video_call/presentation/pages/group_call_screen.dart` (Constitution VI)

- [X] T033 [P] Run `flutter test test/features/translation/` and confirm all
  `caption_model_test.dart` and `translation_cubit_test.dart` cases pass

- [ ] T034 Execute the full `quickstart.md` manual validation (steps 1-8) against a
  running `chat-app-backend` with Phases 1-4 deployed, on two devices/simulators in the
  same group call room

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001). BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion.
- **User Story 2 (Phase 4)**: Depends on User Story 1 (Phase 3) — its widget test (T022)
  pumps the `_ParticipantTile`/`CaptionOverlay`/`CaptionBanner` wiring built in US1.
- **User Story 3 (Phase 5)**: Depends on Foundational (Phase 2) and on US1's
  `group_call_screen.dart` wiring (T018/T019) for the CC icon's host tile — can otherwise
  proceed in parallel with US2.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### Within Each User Story

- US1: Tests (T014, T015) can be written alongside implementation but should pass before
  the checkpoint. Widgets (T016, T017) before screen wiring (T018-T021). T018 before
  T019/T020/T021 (same file, sequential edits).
- US2: T022 depends on US1's tile/overlay wiring; T023 is a manual check after T018-T021.
- US3: Widget (T025) and language resolver (T026) before tile wiring (T027). T027 before
  T028. T029/T030 can proceed in parallel with T027/T028 (different concerns in
  `TranslationCubit`, though T030 also touches `group_call_screen.dart`). T024 (tests)
  last, once T026/T028/T029 behavior exists to assert against.

### Parallel Opportunities

- Foundational: T002, T003, T004, T005 in parallel (distinct new files); T008 once
  T002/T004 land; T011 once T003 lands.
- US1: T014 and T015 in parallel (distinct test files); T016 and T017 in parallel
  (distinct widget files).
- US3: T024 and T031 in parallel with each other; T025 can start as soon as Foundational
  is done (in parallel with US1/US2 work, since it doesn't touch `group_call_screen.dart`
  until T027).
- Polish: T032 and T033 in parallel.

---

## Parallel Example: Foundational (Phase 2)

```bash
# Launch together — distinct new files, no shared dependencies:
Task: "Create CaptionType enum + Caption entity in lib/features/translation/domain/entities/caption.dart"
Task: "Create TranslationStatus enum + TranslationSubscription entity in lib/features/translation/domain/entities/translation_subscription.dart"
Task: "Create CaptionModel in lib/features/translation/data/models/caption_model.dart"
Task: "Add translation:* socket event constants in lib/core/network/socket_events.dart"
```

## Parallel Example: User Story 1 (Phase 3)

```bash
# Tests, in parallel:
Task: "CaptionModel.fromJson unit tests in test/features/translation/data/models/caption_model_test.dart"
Task: "TranslationCubit caption-ingestion bloc_test in test/features/translation/presentation/bloc/translation_cubit_test.dart"

# Widgets, in parallel:
Task: "CaptionOverlay widget in lib/features/translation/presentation/widgets/caption_overlay.dart"
Task: "CaptionBanner widget in lib/features/translation/presentation/widgets/caption_banner.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002-T013) — **critical path**, blocks everything else.
3. Complete Phase 3: User Story 1 (T014-T021).
4. **STOP and VALIDATE**: Manually call `translationCubit.subscribe(...)` for a test
   speaker (UI toggle isn't built yet — that's US3) and confirm captions render correctly
   on that speaker's tile per the Independent Test.

### Incremental Delivery

1. Setup + Foundational → `TranslationCubit` ready, unit-testable.
2. User Story 1 → captions render on the correct tile (MVP demoable with a temporary
   hard-coded `subscribe()` call).
3. User Story 2 → verify/lock in the zero-extra-rebuild guarantee with a widget test +
   manual profiling pass.
4. User Story 3 → real CC-icon toggle UI, language picker, denial/unavailable feedback,
   leave/reconnect edge cases — now the feature is end-user-usable without code changes.
5. Polish → `flutter analyze`, full test suite, full `quickstart.md` walkthrough.

### Suggested MVP Scope

**User Story 1** (Phases 1-3, T001-T021) is the smallest demoable slice: captions appear
correctly on the right tile, validated against the already-implemented backend. User
Story 3's toggle UI is the minimum needed for a *real user* (not just a developer) to
trigger it, so for an end-user-facing release, ship **US1 + US3** together (skip the
`flutter test`-only US2 lock-in if time-constrained — but do not skip US2 in production,
since FR-007/FR-015 are hard requirements).
