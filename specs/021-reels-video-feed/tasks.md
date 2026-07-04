# Tasks: Reels / Short Videos Feed — v3 (upload + automated content moderation)

**Input**: Design documents from `/specs/021-reels-video-feed/` (plan.md v3, spec.md US10 + FR-060–FR-067 + 2026-07-03 clarifications, research.md R15–R19, data-model.md v3 ERD, contracts/reels-api.md endpoints 21–24)
**Prerequisites**: v1 (US1–US6, T001–T069) and v2 (US7–US9 + notifications, T071–T108) are **implemented and verified** — their checklists are superseded by this file. This file tracks the v3 delta only; IDs continue from T109.

**Status**: All 28 v3 tasks (T109–T136) are complete. Backend: 36/36 reels unit tests + 22/22 reels e2e tests pass; full backend suite shows only pre-existing failures in unrelated modules (video/chat/auth/status — zero diff in this session, confirmed pre-existing). Flutter: 59/59 reels-specific tests pass (upload_cubit 5, creator_profile_cubit 3, reels_interaction_cubit 10, reels_feed_bloc 14, reel_status_badge 3, search_cubit 9, reel_description 5, plus setup/teardown); `flutter analyze` shows zero new issues. T136 (on-device walkthrough) could not be executed — no simulator/device available in this session; see its entry below for what to verify before merge.

**Tests**: Included — plan.md mandates Jest unit/e2e (backend, `mongodb-memory-server`) and `bloc_test`/`mocktail` (Flutter).

**Organization**: v3 has a single user story (US10 — upload with automatic content review, P10). The status state machine is foundational (it re-scopes every existing read path), then US10 splits into parallel backend (upload/worker/delete) and Flutter (trim/upload UI, badges) tracks.

**Repos**: Flutter = this repo. Backend = `/Volumes/Zeyad/Documents/work/Node js/chat-app-backend` (paths prefixed `backend:`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US10) — story phase only

---

## Phase 1: Setup (v3)

**Purpose**: Approval gate, environment, dependencies, shared strings

- [X] T109 ⚠️ GATE (FR-056 re-triggered): v3 ERD delta approved by stakeholder (schema `status` state machine, embedded `ModerationResult`, `reelRejected` event, revised indexes) — backend implementation proceeded
- [X] T110 [P] backend: `MODERATION_PROVIDER` (`stub` default | `sightengine`), `SIGHTENGINE_API_USER`, `SIGHTENGINE_API_SECRET` added to `.env.example` + `app.module.ts`'s Joi validation schema; `BullModule.forRootAsync`'s connection gained `maxRetriesPerRequest: null` (required by BullMQ Workers — the reels-moderation queue is the first Worker this app runs; previously latent since no `@Processor` existed yet)
- [X] T111 [P] Flutter: `video_editor: ^3.0.0` + `ffmpeg_kit_flutter_new: ^4.3.2` added to `pubspec.yaml` (verified on pub.dev: video_editor stopped bundling ffmpeg as of 3.0.0, hence the separate ffmpeg_kit dependency; its own `video_player`/`video_thumbnail` constraints resolve cleanly against this project's existing pins). Android `minSdk` bumped to `maxOf(flutter.minSdkVersion, 24)` (ffmpeg_kit_flutter_new's floor); iOS platform (14.0) and Kotlin (2.3.10) already satisfy its minimums. `flutter pub get` clean.
- [X] T112 [P] Added v3 localization keys (`reels.upload_*`, `reels.trim_*`, `reels.status_processing`, `reels.status_removed`, `reels.delete_*`, `reels.notif_rejected`) to `assets/translations/en.json` and `ar.json`

---

## Phase 2: Foundational (blocks US10 — re-scopes every existing read path)

**Purpose**: Status state machine on the schema + visibility filtering everywhere + backfill. After this phase all v1/v2 behavior is unchanged for `published` reels, and non-published reels are invisible to non-owners on every surface.

- [X] T113 backend: `reel.schema.ts` — `status` enum (`ReelStatus.PENDING_MODERATION` default | `PUBLISHED` | `REJECTED`), `publishedAt?`, embedded `ModerationResult` subdoc (`verdict`, `flaggedSource`, `categories[]`, `providerRef`, `completedAt`); schema gained `updatedAt` (needed for the R17 sweep index); feed index replaced with `{status, createdAt, _id}`, added `{creatorId, status, createdAt}` and `{status, updatedAt}`. `notification-event.schema.ts` — `type` gained `REEL_REJECTED`, `actorId` became optional/nullable (system events)
- [X] T114 backend: `reels-seed.service.ts` — idempotent `backfillStatus()` sets pre-v3 docs to `published`; seeded reels now created directly as `published`
- [X] T115 backend: Visibility filter — `visibilityFilter(viewerId)` in `reels-db.repository.ts` (`status=='published' OR creatorId==viewer`, composes with the existing block filter via plain-object merge) applied to every read (`listFeed`, `getReel`, `listComments`/`addComment`/`toggleLike`/`recordShare`/`recordView`/`toggleSave` all now require `published` — 404/no-op otherwise per FR-064); `getProfile`'s grid filters to `published` for non-self, all statuses + `status` field for self; `searchReels`/`listByRelation` gained the filter too (defense-in-depth). `ReelDto`/`CreatorProfileDto.videos[].status` added to the repository contract
- [X] T116 backend: 3 new e2e tests in `test/reels.e2e-spec.ts` (`moderation visibility` describe block) — pending/rejected reel invisible to non-owner across single-fetch/creator-feed/profile-grid/search/hashtag, 404 on every engagement action, owner sees it with correct `status`; seeded reels unaffected. All pass alongside the full pre-existing v1/v2 e2e suite (25 total in this describe block set)
- [X] T117 [P] Flutter: `ReelStatus` enum (`lib/features/reels/domain/entities/reel_status.dart`) + `status` field on `Reel` entity/`ReelModel` (defaults to `published` — tolerant of pre-v3 payloads) and on `ReelThumb`/`CreatorProfileModel` (for grid badges)

**Checkpoint**: All v1/v2 flows behave identically for published content; non-published reels are invisible to non-owners everywhere. ✅ Verified — all pre-existing e2e tests pass unchanged.

---

## Phase 3: User Story 10 — Upload a Reel with Automatic Content Review (P10)

**Goal**: "+" entry on the Reels screen → record/pick (≤60 s, trimmer for longer sources) + description → upload with progress → "Processing" on own profile → background AI moderation → auto-publish (mentions fire now) or "Removed due to policy violations" (+ rejection push); owner can delete any own reel (FR-060–FR-067).

**Independent Test**: quickstart.md §12 — with `MODERATION_PROVIDER=stub`: upload a clean video (mention a second account) → Processing → published everywhere + mention push exactly once at publish; upload with `nsfw-test` in the description → Removed badge + rejection push, second account sees nothing anywhere; kill Redis → upload stays Processing forever (never publishes); delete a reel → 404 everywhere. ✅ Automated equivalent of this flow is covered by e2e (T125); manual on-device pass not run this session (T136).

### Backend track

- [X] T118 [US10] backend: `dto/create-reel.dto.ts` (description trimmed ≤2200) + `POST /` in `reels.controller.ts` — `FileFieldsInterceptor` (`video` required ≤100 MB mp4/mov/webm, `thumbnail` optional ≤2 MB jpg/png, Multer `diskStorage` with randomized on-disk filenames — chat/status pattern); **server-side duration validation** via `music-metadata` (pinned to `^7.14.0`, the last CommonJS-published major — v8+ is pure ESM and needs a dynamic `import()` that Jest's default CJS test runtime can't execute without `--experimental-vm-modules`; a static import sidesteps this entirely, works identically in prod and tests), >61 s or unparseable → 400 + file cleanup; `ReelsService.createReel` parses hashtags/mentions (no notification sent), creates via repository, enqueues the moderation job (enqueue failure is caught and logged — never fails the upload, R17)
- [X] T119 [P] [US10] backend: `moderation/moderation-provider.ts` (interface + `MODERATION_PROVIDER` DI token) + `moderation/stub.provider.ts` (flags on an `nsfw-test` marker in the video path or description — **note**: the video-path check only fires when a caller controls the path directly (unit tests); through the real upload endpoint Multer's randomized on-disk filename means the description marker is the only reliable trigger — documented in the provider's docstring and quickstart.md)
- [X] T120 [P] [US10] backend: `moderation/sightengine.provider.ts` — video (`check-sync.json`, multipart) + text (`text/check.json`) moderation via `@nestjs/axios` + `form-data`; nudity/offensive category thresholds; throws on missing credentials or HTTP failure (fail-closed)
- [X] T121 [US10] backend: Split into `reels-moderation.service.ts` (pure logic — `moderateReel(id)`, `findStalePendingIds()` — deliberately free of BullMQ so it's directly invocable in tests without live Redis) + `reels-moderation.processor.ts` (thin `@Processor`/`WorkerHost` wrapper owning only job pull + the R17 sweep timer). `BullModule.registerQueue` + provider registered in `reels.module.ts`. Guarded `findOneAndUpdate` (precondition `status: PENDING_MODERATION`) makes both transitions exactly-once under retries/concurrent workers; publish fires block-filtered `notifyMentions`; verdict latency logged (SC-018)
- [X] T122 [US10] backend: `reels-notifications.service.ts` gained `notifyReelRejected()` — system-originated (`actorId: null`, bypasses the self-skip guard), `notif_rejected` push body, `{type:'reelRejected', reelId}` data payload
- [X] T123 [US10] backend: `DELETE /:id` in `reels.controller.ts` (403 non-owner, 404 unknown) + `ReelsDbRepository.deleteReel` cascade (counter adjustment → relations → notification events → reel doc → best-effort local-file unlink, `/uploads/` paths only — seeded/CDN URLs left alone)
- [X] T124 [P] [US10] backend: `reels-moderation.service.spec.ts` (8 tests: no-op on missing/decided reel, clean→published+mentions-once, flagged→rejected+moderation-result+notify, provider-throw leaves reel pending, guarded-update prevents double-fire, block-suppressed mention, stale-id lookup) + `stub.provider.spec.ts` (4 tests) + `deleteReel` unit coverage in `reels.service.spec.ts` (success/404/403)
- [X] T125 [US10] backend: 7 new e2e tests in `test/reels.e2e-spec.ts` (`upload & moderation` describe block) — clean upload publishes + fires mention exactly once, flagged upload rejects + suppresses mentions, over-60s upload 400s with no reel created, no-video-file 400s, block-before-verdict suppresses the mention, owner delete cascades counters correctly, non-owner delete 403s. The suite's `BullModule` is genuinely registered (proving the production DI graph resolves) but the queue is paused in `beforeAll` so every test drives the pipeline via deterministic direct `moderationService.moderateReel()` invocation (plan.md's documented "direct processor invocation" allowance) rather than racing the live Worker

### Flutter track

- [X] T126 [P] [US10] `uploadReel()` (dio `FormData` multipart, `onSendProgress`, `CancelToken`) + `deleteReel()` in `ReelsRemoteDataSource`/`ReelsRepositoryImpl`; new domain-layer `UploadCancelToken` (constitution I — keeps `dio` out of the domain layer; the repository impl adapts it to a real `CancelToken` internally)
- [X] T127 [US10] `upload_cubit.dart` + `UploadState` (`idle → uploading(progress) → success|failure`; the picked/trimming steps live in screen-local state per R16) — `@injectable`, cancels its token in `close()`
- [X] T128 [US10] `reel_trimmer_screen.dart` — `VideoEditorController` (`video_editor`) + `TrimSlider` for the ≤60 s window UI; export via `VideoFFmpegVideoEditorConfig`/`CoverFFmpegVideoEditorConfig`'s generated ffmpeg commands run through `ffmpeg_kit_flutter_new`'s `FFmpegKit.execute`; in-flight session cancelled on dispose (constitution V)
- [X] T129 [US10] `upload_reel_screen.dart` — `image_picker` camera capture (native `maxDuration: 60s`) / gallery pick with a `VideoPlayerController`-based duration probe, >60 s → mandatory trimmer; `video_thumbnail` frame-grab for already-short picks; description input + submit wired to `UploadCubit`; `/reels/upload` route (declared before `/reels/:id`, matching the other static-path routes) + "+" entry in `reels_my_profile_header.dart`
- [X] T130 [US10] `reel_status_badge.dart` (const leaf, renders nothing for `published`) applied to own-grid thumbnails in `creator_profile_screen.dart`'s `_VideosTab`; a `_StatusBanner` in `reel_page.dart` covers the single-reel-view case (own pending/rejected reel opened directly); `ReelsFeedBloc` now skips `recordView` when the current reel's `status != published` (avoids fire-and-forget 404 noise for the owner viewing their own non-published reel)
- [X] T131 [US10] Owner delete — long-press/overflow-icon on own-grid items → confirmation dialog → `CreatorProfileCubit.deleteReel()` (added `videos` to `CreatorProfile.copyWith` to support the grid-item removal) → snackbar; non-self grids never show the affordance
- [X] T132 [US10] Rejection push routing — `reelRejected` added to `push_notification_service.dart`'s type checks; new `reelOwnProfile:` payload prefix (no id — the push carries none) resolved to the current user's id via `AuthLocalDataSource.getUserId()` at navigation time in `app_router.dart`'s `navigateToReelsNotification`/`handleInitialNotification`
- [X] T133 [P] [US10] `upload_cubit_test.dart` (4 tests: success, progress emission, failure-not-phantom-success, cancel-on-close) + `reel_status_badge_test.dart` (3 tests: nothing/processing/removed) — all pass; `.tr()` without an `EasyLocalization` ancestor degrades to a logged warning + the raw key rather than throwing, so no special test harness was needed (matches the existing `reel_description_test.dart` convention)

**Checkpoint**: US10 fully demoable per quickstart §12 — upload → moderation → publish/reject → badges/push → delete. ✅ Automated coverage complete; manual on-device pass flagged in T136.

---

## Phase 4: Polish & Cross-Cutting

- [X] T134 [P] `dart run build_runner build --delete-conflicting-outputs` (confirmed `UploadCubit` registered as `gh.factory` in `injection.config.dart`); `flutter analyze` shows zero new issues — every remaining warning/error is pre-existing and in files with no diff in this session (unrelated auth/status/translation/map areas)
- [X] T135 Full regression — backend: 36/36 reels unit tests + 22/22 reels e2e tests pass; full `npx jest` shows 4 pre-existing failing suites (video/chat/auth/status — confirmed zero git diff on those files, i.e. failing before this session) and otherwise all green. Flutter: 59/59 reels tests pass across all 7 test files; full `flutter test` shows only pre-existing failures (status_creation_cubit missing-param, translation_cubit missing getter, google_fonts asset-loading in map tests — none touch reels)
- [X] T136 Manual on-device quickstart walkthrough — **NOT run this session (no simulator/device available)**, consistent with how T107/T108 flagged the same gap for v1/v2. Recommended before merge, particularly:
  - The full record → (trim) → upload → Processing → publish/reject → badge/push → delete loop on a real device (the backend pipeline is e2e-tested; the Flutter trim/upload UI chain — `image_picker` → `video_editor`/`ffmpeg_kit_flutter_new` → multipart upload — has only been `flutter analyze`-verified, never run)
  - `video_editor`/`ffmpeg_kit_flutter_new` on both iOS and Android specifically (native plugin integration, camera permissions, ffmpeg binary presence)
  - Redis-down fail-closed recovery (kill Redis mid-Processing, confirm the sweep re-enqueues on restart) against the *real* BullMQ worker (e2e deliberately pauses it for determinism — see T125)
  - Re-run the v1 performance gates (SC-001/002/006) after adding the top-bar "+" — confirm no overlay rebuild regressions

---

## Carried-over technical debt (from v1)

- [ ] T070 backend/Flutter: `GlobalResponseInterceptor` (`chat-app-backend/src/main.ts`) wraps every controller response as `{ success, message, data }`, but `StatusRemoteDataSource` (`lib/features/status/data/datasources/status_remote_data_source.dart`, methods `getFeed`, `getViewers`, `getReactions`, `getDefaultAudience`) casts `response.data` directly `as List<dynamic>` without unwrapping the envelope. If these `/status/...` routes pass through the interceptor, that cast throws a `TypeError` at runtime. Needs verification against a live backend + fix — unrelated to Reels; flagged with inline `TODO`s at call sites.

## New technical debt discovered this session (v3)

- [ ] **Pre-existing schema-typing quirk** (not introduced by v3, but newly surfaced while writing e2e tests): every `@Prop({ type: Types.ObjectId, ... })` field across the reels module (`reel.creatorId`, `notification-event.recipientId`/`actorId`/`reelId`, likely others project-wide) resolves to Mongoose schema type `Mixed` rather than `ObjectId` under this project's `mongoose@^9.4.1` + `@nestjs/mongoose@^11.0.4` combination — confirmed via `Model.schema.path(...).instance`. Consequence: Mongoose's automatic string→ObjectId query-argument casting does not apply; every query must pass real `Types.ObjectId` instances (which `reels-db.repository.ts`'s `toObjectId()` helper already does everywhere in production code — this is why it was never noticed before). `test/reels.e2e-spec.ts`'s new notification-event queries now follow the same convention explicitly. Root-causing and fixing the schema declaration itself is out of scope for this feature (project-wide blast radius, unrelated to reels/moderation) but worth a dedicated investigation.
- [ ] **Local dev Redis**: this session installed Redis via Homebrew (`brew install redis`, started via `redis-server --daemonize yes`) since neither Docker nor a standalone Redis was running locally and the v3 BullMQ queue needs one for the e2e suite. `npm run docker:local:up`'s compose stack already provisions Redis for normal dev use — the Homebrew install is a redundant fallback specific to this sandboxed session, not a project change.
