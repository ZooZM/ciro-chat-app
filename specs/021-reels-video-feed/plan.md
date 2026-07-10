# Implementation Plan: Reels / Short Videos Feed

**Branch**: `021-reels-video-feed` | **Date**: 2026-07-06 (v5 — extended for the camera-first creation overhaul after its clarification session; v4 dated 2026-07-05, v3 2026-07-03) | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/021-reels-video-feed/spec.md`

## Summary

v1 (feed, overlay, profiles, follow, share sheet, deep links — US1–US6) and v2 (real MongoDB, shared identity + blocking, descriptions/hashtags/mentions, views, saves/liked lists, own profile, search, FCM notifications — US7–US9) are **fully implemented** (tasks T001–T108 complete). This v3 plan covers only the delta added by the 2026-07-03 spec update and clarifications — **US10: reel upload with automated explicit/NSFW content moderation** (App Store UGC compliance, FR-060–FR-067):

1. **Upload endpoint** — `POST /api/reels` (multipart: video ≤60 s + optional thumbnail + description) following the backend's existing Multer `diskStorage` pattern (chat/status controllers); creates the reel with `status: 'pending_moderation'` and enqueues a moderation job. Description parsing reuses `reels-text.util.ts`; **mention notifications do NOT fire here** — they move to the publish transition (FR-063), giving `notifyMentions` (built in T102, currently caller-less) its live caller.
2. **Moderation status state machine** — `reels.status ∈ {pending_moderation, published, rejected}`; every public read path gains a `status: 'published'` filter (seeded catalog is backfilled/created as `published`); owner-facing reads include own pending/rejected reels with status. Non-owner fetch of a non-published reel → 404 (unknown-reel path, FR-061).
3. **Background moderation worker** — BullMQ (`@nestjs/bullmq` + Redis, already dependencies) queue `reels-moderation`; processor calls a `ModerationProvider` abstraction (primary: **Sightengine** video + text endpoints — accepts direct upload of the locally stored file, no cloud-bucket prerequisite; a `stub` provider for dev/tests). Clean → `published` + `notifyMentions`; flagged (video OR description) → `rejected` + soft-delete (media hidden, retained on disk) + `reelRejected` notification event + push (FR-062–FR-064). Fail-closed: provider failure keeps `pending_moderation`, BullMQ retries with exponential backoff (FR-066).
4. **Owner deletion** — `DELETE /api/reels/:id` (owner-only, any status): cascade relations, counter adjustments, media file removal; deep link then 404s (FR-067).
5. **Flutter upload flow** — "+" entry in the Reels top bar → record (camera, `image_picker` `maxDuration: 60s`) or pick from gallery; >60 s sources open a WhatsApp-Status-style trimmer; description input; `dio` multipart with progress. Own profile grid gains status badges ("Processing" / "Removed due to policy violations") and owner delete; push tap-routing gains `reelRejected` (FR-060/FR-060a/FR-065).

v1–v3 are **fully implemented** (T001–T136 complete). This v4 plan covers only the delta added by the 2026-07-05 spec update — **US11: user reporting with auto-hide** and **US12: reposting + Following/For You feed tabs** (FR-068–FR-078):

1. **Reporting** — `POST /api/reels/:id/report` (reason enum + conditional `customReason`); `reel_reports` collection with unique `{videoId, reporterId}` (duplicate = idempotent no-op); per-user daily rate limit (`REEL_REPORT_DAILY_LIMIT` env, default 20/day → `429`, clarified); `reportsCount` stored counter on the reel; the insert that reaches `REEL_REPORT_AUTOHIDE_THRESHOLD` (env, default 25) fires the guarded `published → hidden` transition — unless the reel carries `adminRestored: true` (permanent auto-hide immunity after a restore, clarified) (contracts §25, FR-069/FR-070).
2. **`hidden` status** — fourth `ReelStatus` value; the existing visibility filter (`status == 'published' OR owner`) excludes it on every surface with **zero query changes**; owner-facing badge "Under review". Status writers grow from one to three, all guarded `findOneAndUpdate` (data-model state machine v4).
3. **Admin moderation** — `PATCH /api/reels/:id/moderation` `{action: restore|reject}` plus `GET /api/reels/moderation/hidden` (review-backlog list with report reasons/counts, clarified), both behind a new `AdminKeyGuard` (`x-admin-key` vs `ADMIN_API_KEY` env — the backend has no role system); restore sets `adminRestored: true` (permanent auto-hide immunity; `reportsCount` retained for audit) (contracts §29–30, FR-071/FR-072).
4. **Reposting** — `reel_reposts` collection (unique `{videoId, reposterId}`, `{reposterId, createdAt}` injection index); `POST`/`DELETE /api/reels/:id/repost` toggle (same relation-write-outcome pattern as saves, no counter, no notification); a dedicated **Repost button in the action column** (repeat glyph, Save's former slot — Save relocates into the 3-dots more-options sheet alongside Report/Delete, clarified) (FR-073/FR-068, contracts §26–27).
5. **Feed tabs** — `GET /api/reels/following` (followees' original reels, finite, no reposts — reuses the v3 `{creatorId, status, createdAt}` index) and For You injection on the existing `GET /api/reels` (two-leg merge by repost recency, dedup one-instance-per-reel, `repostedBy` payload, reposter-edge block filtering — R20 decides the packed-cursor encoding). Flutter: Following | For You top toggle, `ReelsFeedBloc` parameterized by `feedScope`, one bloc per tab, exclusive playback + per-tab resume (FR-074–FR-078, contracts §28).

v1–v4 are **fully implemented** (T001–T161 complete; the T136/T162 on-device walkthroughs remain outstanding). This v5 plan covers only the delta added by the 2026-07-06 spec update and its clarification session — **US13: camera-first reel creation** (FR-079–FR-084):

1. **Capture screen** — a custom full-screen in-app camera (`camera` package — the only new dependency, R21) replacing the v3 source-choice entry: red record toggle (single continuous clip, clarified), gallery thumbnail (`image_picker.pickVideo`), flip/flash only, `Video | 15s | 30s | 60s` selector with timer-driven auto-stop at the cap. Permission pre-flight via the existing `permission_handler` with an open-settings denial state (FR-079).
2. **Trimmer step for every source** — `reel_trimmer_screen.dart` gains a `maxDuration` param (15s/30s/60s from capture; 60s for gallery, clarified) and an explicit **"Next"** CTA; all inputs are first copied to a space-free `reels_tmp` path (confirmed `video_editor` 3.0.0 iOS space-path failure, R22); straight-to-trimmer, no preview step (clarified).
3. **Post-details rebuild** — `upload_reel_screen.dart` reduced to description + preview thumbnail + Post (source-choice UI removed; the `UploadCubit` submit/progress/error machine is unchanged) (FR-082).
4. **Mention autocomplete** — a zero-dependency overlay (`OverlayPortal` + `CompositedTransformFollower`) on the description field, fed by a `MentionSuggestionsCubit` filtering the once-fetched following list in memory (FR-083, R23).
5. **Followed-users endpoint** — `GET /api/reels/me/following` (reels module, rides the existing `{followerId, createdAt}` index; no schema, env, or dependency changes — FR-084, contracts §31, R24).

## Technical Context

**Language/Version**: Dart (Flutter, SDK ^3.9.2) frontend; TypeScript / NestJS 11 (Express platform) backend
**Primary Dependencies**: Flutter existing: `media_kit` stack, `flutter_bloc` 9, `get_it`/`injectable`, `dio`, `go_router`, `fpdart`, `equatable`, `cached_network_image`, `image_picker` (video record/pick — already present), `firebase_messaging`. **New Flutter packages (v3)**: `video_editor` (trim UI) + `ffmpeg_kit_flutter_new` (trim export + thumbnail frame extraction) — see R16; exact pins verified at implementation time. Backend existing: `@nestjs/mongoose` + `mongoose` 9, `@nestjs/bullmq` + `bullmq` + `ioredis` (registered in `app.module.ts`), Multer via `@nestjs/platform-express`, `firebase-admin`. **New backend dependency**: one lightweight container-metadata parser for server-side duration validation (e.g., `music-metadata` — no ffmpeg); Sightengine itself is plain REST via existing `@nestjs/axios`. **New Flutter package (v5)**: `camera` ^0.11 (custom capture screen — R21); `permission_handler`, `photo_manager`, `image_picker`, `video_editor`, `ffmpeg_kit_flutter_new` all already present. Backend v5: no new dependencies, env vars, or schema changes
**Storage**: MongoDB (v2, unchanged) + local-disk media under `uploads/reels/` served statically (existing `main.ts` static-assets pattern; CDN swap remains a data-value change). Redis required at runtime for the BullMQ moderation queue (`REDIS_URL` already in env)
**Testing**: Backend — Jest unit (moderation processor state transitions, provider stub, publish-time `notifyMentions`, delete cascade) + e2e on `mongodb-memory-server` (status filtering on every read surface, owner-vs-other visibility, upload → pending → publish/reject flows with the stub provider). Flutter — `bloc_test`/`mocktail` (`UploadCubit` progress/failure, status-badge rendering); existing 33 reels tests stay green. **v5**: Flutter — `bloc_test` for `CaptureCubit` (cap auto-stop, sub-second discard, permission states) and `MentionSuggestionsCubit` (token filter, insert, dismiss), widget tests for the suggestion overlay and the trimmer `maxDuration` param; backend — unit + e2e for `GET /me/following` (ordering, pagination, block filter)
**Target Platform**: iOS + Android; backend Node.js (docker-compose local Mongo + Redis)
**Project Type**: Mobile app + API backend (this Flutter repo + `chat-app-backend`)
**Performance Goals**: v1/v2 gates unchanged (SC-001..SC-016) plus: upload response never blocked by moderation (FR-062), moderation verdict ≤5 min for ≤60 s videos (SC-018), zero unmoderated public exposure (SC-017). **v4**: hidden reels invisible from next fetch (SC-020), exactly-once hide under concurrency (SC-021), one instance per reel per For You session (SC-022), tab switch within the SC-005 bound (SC-023). **v5**: camera preview ≤2 s and record feedback ≤200 ms (SC-024), auto-stop at the cap ±0.5 s with zero >60 s uploads (SC-025), mention panel ≤300 ms with no input lag (SC-026), ≤5-tap creation flow (SC-027)
**Constraints**: fail-closed moderation (never publish without an explicit clean verdict — FR-066); `status: 'published'` filter on EVERY non-owner read path, enforced server-side only (FR-061); mention notifications fire exactly once, at publish, never at upload (FR-063); upload cap 60 s / 100 MB, longer sources trimmed client-side (FR-060a); rejected media soft-deleted (hidden, retained) not purged (Assumption). **v4**: exactly three guarded status writers (worker / report service / admin endpoint — data-model v4); report+repost writes require `published` (404 otherwise); reposter-edge block filtering on For You injection (FR-078); no new Flutter or backend dependencies — new env vars only (`REEL_REPORT_AUTOHIDE_THRESHOLD` default 25, `REEL_REPORT_DAILY_LIMIT` default 20, `ADMIN_API_KEY`). **v5**: single continuous clip — no segmented recording (clarified); every source passes through the trimmer via a space-free temp copy (R22); the suggestion overlay never blocks typing (FR-083); one new Flutter dependency (`camera`, justified in Complexity Tracking); backend adds exactly one read endpoint
**Scale/Scope**: ~~v3~~ (delivered): 1 schema change + 2 endpoints + 1 BullMQ processor + provider abstraction + status filter + seed backfill; 2 Flutter screens + `UploadCubit` + badges. **v4**: Backend — 2 new collections (`reel_reports`, `reel_reposts`) + `hidden` status + `reportsCount`/`adminRestored` + 6 endpoints (report, repost ×2, following feed, admin moderation + hidden-list) + For You two-leg merge + 1 guard. Flutter — Following|For You toggle on the feed screen, `feedScope` on `ReelsFeedBloc`, action-column **Repost button** in Save's former slot (Save relocates into the 3-dots sheet — extended `reel_more_button.dart` with Save + Report/Delete), new reasons sheet, `repost_badge.dart`, "Under review" badge case, i18n keys (en/ar). **v5**: Backend — 1 read endpoint. Flutter — 1 new capture screen + `CaptureCubit`, trimmer `maxDuration` + "Next", post-details rebuild, mention overlay + `MentionSuggestionsCubit`, `FollowedUser` entity + datasource/repo methods, `/reels/capture` route, i18n keys (en/ar)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Clean Architecture**: upload flow lives in `lib/features/reels/` layering — `UploadCubit` + screens/widgets in presentation, multipart datasource call + model in data, `uploadReel`/`deleteReel` repo methods + `ReelStatus` enum on the entity in domain (equatable-only).
- [x] **II. State Management**: `UploadCubit` (Cubit, Equatable states, constructor DI via `get_it`/`injectable`); status badges via `BlocSelector` leaves. `ReelsFeedBloc` (v1 justified deviation) untouched.
- [~] **III. Offline-First**: v1/v2 deviation stands — reels network-only; an upload requires connectivity by nature (failed/interrupted uploads are cleanly retryable, no partial reel — FR-060). No offline upload queue in v3 (documented in Complexity Tracking).
- [x] **IV. Socket.io**: no new socket events; moderation outcomes ride the existing FCM push path (`reelRejected`).
- [x] **V. Teardown**: trimmer's video controller + `UploadCubit` disposed with their routes; ffmpeg sessions cancelled on route pop; upload `CancelToken` cancelled on dispose.
- [x] **Code Quality**: `flutter_lints` clean; `snake_case` files; `const` leaf widgets for badges.
- [x] **Error Handling**: repo methods return `Either<Failure, T>`; upload failure → explicit retryable error state (never a phantom reel); raw errors never shown.
- [x] **VIII-A/B URL & env**: uploaded media URLs stored relative, resolved via `UrlUtils.resolveMediaUrl`; provider keys/queue config via backend env (`SIGHTENGINE_API_USER/SECRET`, `MODERATION_PROVIDER`, existing `REDIS_URL`) — no hardcoded URLs/keys.

**Post-Phase-1 re-check**: PASS — one new justified deviation recorded (no offline upload queue); everything else inherits v1/v2 posture.

**v4 re-check (2026-07-05)**: PASS —
- [x] **I. Clean Architecture**: report/repost/following-feed calls flow datasource → repository (`Either<Failure, T>`) → domain signatures (`reportReel`, `repostReel`, `unrepostReel`, following-scoped feed fetch); `ReelReposter` entity + `ReelStatus.hidden` live in domain (equatable-only).
- [x] **II. State Management**: no new cubits — `ReelsFeedBloc` gains a constructor `feedScope` param (one instance per tab); `ReelsInteractionCubit` gains the optimistic repost map (same pattern as saves); the report sheet is screen-local state.
- [~] **III. Offline-First**: carried v1–v3 deviation — report/repost are network-only optimistic writes with revert (FR-037 pattern), no offline queue (Complexity Tracking).
- [x] **IV. Socket.io**: no new socket events; no new push types in v4 (auto-hide and admin actions are silent to users).
- [x] **V. Teardown**: the inactive tab's bloc pauses playback (FR-009/FR-074); both blocs disposed with the Reels screen; sheets are route-scoped.
- [x] **Error Handling / VIII-A/B**: `Either<Failure, T>` everywhere; raw errors never shown; threshold + admin key are backend env (`REEL_REPORT_AUTOHIDE_THRESHOLD`, `ADMIN_API_KEY`) — no client knowledge of either.

**v5 re-check (2026-07-06)**: PASS —
- [x] **I. Clean Architecture**: capture/post-details/overlay live in `presentation/`; `getFollowingUsers` flows datasource → repository (`Either<Failure, T>`) → domain signature; `FollowedUser` entity equatable-only; no business logic in widgets.
- [x] **II. State Management**: `CaptureCubit` and `MentionSuggestionsCubit` (Cubit, Equatable states, constructor DI); `UploadCubit` reused unchanged; suggestion-panel rebuilds isolated to the overlay leaf (FR-014 spirit).
- [~] **III. Offline-First**: carried v3 deviation — reel creation is a foreground, connectivity-dependent act (Complexity Tracking).
- [x] **IV. Socket.io**: no new socket events.
- [x] **V. Teardown**: `CameraController` disposed on route pop + `WidgetsBindingObserver` (active recording stopped safely on lifecycle pause); text/overlay controllers disposed; `reels_tmp` purged on flow exit; ffmpeg session cancellation carried from v3.
- [x] **Error Handling / VIII-A/B**: `Either<Failure, T>`; permission denial is a rendered state, not an error toast; avatar URLs resolved via `UrlUtils.resolveMediaUrl`; no hardcoded URLs.
- [x] **New-dependency gate**: `camera` justified in Complexity Tracking (a custom capture overlay is impossible with `image_picker`'s system UI).

## Project Structure

### Documentation (this feature)

```text
specs/021-reels-video-feed/
├── plan.md              # This file (v4)
├── research.md          # R1–R8 (v1) + R9–R14 (v2) + R15–R19 (v3) + R20 (v4) + R21–R24 (v5: capture, safe-path trimmer handoff, mention overlay, followed-users endpoint)
├── data-model.md        # ERD v4 — reel_reports/reel_reposts, hidden status, 3 status writers, feed composition + v5 note (no ERD change; FollowedUser client entity)
├── quickstart.md        # + §13/§14 US11/US12 verification + §15 US13 camera-first walkthrough (v5)
├── contracts/
│   └── reels-api.md     # + endpoints 25–30 (report, repost ×2, following feed, admin moderation) + endpoint 31 (followed-users list, v5)
├── checklists/
│   └── requirements.md  # Spec quality checklist (re-validated through v5)
└── tasks.md             # Phase 2 (/speckit-tasks — extend for v5 scope, T163+)
```

### Source Code

**Backend** (`/Volumes/Zeyad/Documents/work/Node js/chat-app-backend`) — v3 delta:

```text
src/modules/reels/
├── schemas/reel.schema.ts             # + status enum (default pending_moderation), publishedAt?, moderation subdoc; + {status, createdAt} indexes
├── schemas/notification-event.schema.ts # + 'reelRejected' type (actorId nullable for system events)
├── reels.controller.ts                # + POST / (multipart upload), DELETE /:id  (Multer diskStorage → uploads/reels/)
├── reels.service.ts                   # + status filter in every read; owner-visibility branch; delete cascade; publish/reject transitions
├── reels-db.repository.ts             # + create/updateStatus/delete methods; status-filtered queries
├── reels-moderation.processor.ts      # NEW — BullMQ worker: provider call → publish (notifyMentions) | reject (soft-delete + reelRejected push)
├── moderation/
│   ├── moderation-provider.ts         # NEW — interface: analyze(videoPath, description) → {verdict, flaggedSource?, categories?, providerRef}
│   ├── sightengine.provider.ts        # NEW — video + text moderation via REST (axios), direct file upload
│   └── stub.provider.ts               # NEW — dev/test: clean unless filename/description contains a flag marker
├── reels-notifications.service.ts     # + reelRejected event (system-originated, actorId null) + push
├── reels-seed.service.ts              # seeded reels created/backfilled as status 'published'
└── dto/create-reel.dto.ts             # NEW — description validation (≤2200)
src/app.module.ts                      # BullMQ queue registration for 'reels-moderation' (BullModule already configured)
```

**Flutter app** (this repo) — v3 delta:

```text
lib/
├── core/
│   ├── routing/app_router.dart              # + /reels/upload route; reelRejected push route → own profile
│   └── services/push_notification_service.dart  # + reelRejected tap-routing
└── features/reels/
    ├── data/
    │   ├── datasources/reels_remote_datasource.dart  # + uploadReel (dio multipart + onSendProgress + CancelToken), deleteReel
    │   └── models/reel_model.dart                    # + status parsing
    ├── domain/
    │   ├── entities/reel.dart                        # + ReelStatus enum, status field
    │   └── repositories/reels_repository.dart        # + uploadReel, deleteReel signatures
    └── presentation/
        ├── bloc/upload_cubit.dart                    # NEW — pick/record → (trim) → compose → uploading(progress) → done/error
        ├── pages/
        │   ├── upload_reel_screen.dart               # NEW — source choice, description input, submit
        │   └── reel_trimmer_screen.dart              # NEW — WhatsApp-Status-style ≤60 s segment selector (video_editor UI)
        └── widgets/
            ├── reels_my_profile_header.dart          # + "+" upload entry (avatar | + | search)
            ├── reel_status_badge.dart                # NEW — Processing / Removed overlay for own grid + owner reel view
            └── (creator_profile_screen.dart)         # own grid: status badges, delete menu (confirmation)

test/features/reels/                                  # + upload_cubit_test, status badge widget test
```

**Structure Decision**: v3 stays additive inside the v1/v2 layout on both sides. Moderation is backend-internal (worker + provider under the reels module); the Flutter app only ever sees the `status` field on owner-facing DTOs.

**Backend v4 delta** (`chat-app-backend/src/modules/reels/`):

```text
├── schemas/reel.schema.ts             # + status 'hidden', reportsCount (default 0), adminRestored (default false)
├── schemas/reel-report.schema.ts      # NEW — unique {videoId, reporterId}; {videoId}; {reporterId, createdAt} (daily limit)
├── schemas/reel-repost.schema.ts      # NEW — unique {videoId, reposterId}; {reposterId, createdAt}; {videoId}
├── dto/report-reel.dto.ts             # NEW — reason enum + conditional customReason (≤500)
├── admin-key.guard.ts                 # NEW — x-admin-key header vs ADMIN_API_KEY env
├── reels.controller.ts                # + POST /:id/report, POST|DELETE /:id/repost, GET /following + GET /moderation/hidden (before /:id), PATCH /:id/moderation
├── reels.service.ts                   # + report (daily limit → 429) + threshold hide (adminRestored-immune), repost toggle, following feed, For You merge/dedup/repostedBy, admin transitions (restore sets adminRestored) + hidden list, delete cascade + reports/reposts
└── reels-db.repository.ts             # + report/repost writes, two-leg For You query (R20 cursor), following query
```

**Flutter v4 delta** (`lib/features/reels/`):

```text
├── data/
│   ├── datasources/reels_remote_datasource.dart  # + reportReel, repostReel, unrepostReel, feedScope-aware feed fetch
│   └── models/reel_model.dart                    # + viewerReposted, repostedBy parsing; status 'hidden'
├── domain/
│   ├── entities/reel.dart / reel_status.dart     # + ReelReposter entity, viewerReposted, repostedBy; ReelStatus.hidden
│   └── repositories/reels_repository.dart        # + report/repost/unrepost + following feed signatures
└── presentation/
    ├── bloc/reels_feed_bloc.dart                 # + feedScope (forYou | following); pagination dedup by reel id
    ├── bloc/reels_interaction_cubit.dart         # + optimistic repost map (saves pattern)
    ├── pages/reels_feed_screen.dart              # + Following | For You top toggle; one bloc per tab, exclusive playback
    └── widgets/
        ├── reel_more_button.dart                 # extend: render for ALL viewers → Save (relocated) + Report (non-owner) / Delete (owner)
        ├── report_reasons_sheet.dart             # NEW — presets + Other w/ TextField
        ├── repost_button.dart                    # NEW — action-column primary Repost toggle (Save's former slot; hidden/disabled on own reels)
        ├── save_button.dart                      # RETIRED from the action column (logic reused inside the more-options sheet)
        ├── repost_badge.dart                     # NEW — "[Name] reposted" / "You reposted" above reel_creator_header; not tappable
        └── reel_status_badge.dart                # + "Under review" (hidden)
```

**Backend v5 delta** (`chat-app-backend/src/modules/reels/`): `reels.controller.ts` + `GET /me/following` (declared before `/:id`); `reels.service.ts` + `getFollowingUsers` (block-filtered followee hydration); `reels-db.repository.ts` + follows-by-follower cursor query. No schema/env changes.

**Flutter v5 delta** (`lib/`):

```text
├── core/routing/app_router.dart                   # + /reels/capture ("+" lands here); post-details is pushed directly by the trimmer (no /reels/upload route — B3, avoids a camera-screen flash between "Next" and the post screen)
└── features/reels/
    ├── data/
    │   ├── datasources/reels_remote_datasource.dart  # + getFollowingUsers (cursor)
    │   └── models/followed_user_model.dart           # NEW
    ├── domain/
    │   ├── entities/followed_user.dart               # NEW — id / username / name / avatarUrl
    │   └── repositories/reels_repository.dart        # + getFollowingUsers signature
    └── presentation/
        ├── bloc/capture_cubit.dart                   # NEW — idle → recording(elapsed, cap) → captured(path) | permissionDenied
        ├── bloc/mention_suggestions_cubit.dart       # NEW — hidden | loading | active(query, matches)
        ├── pages/
        │   ├── reel_capture_screen.dart              # NEW — preview, record toggle, gallery, flip/flash, Video|15s|30s|60s
        │   ├── reel_trimmer_screen.dart              # maxDuration param + "Next" CTA + safe-path input (R22)
        │   └── upload_reel_screen.dart               # REBUILT as post-details: description + thumbnail + Post
        └── widgets/
            ├── record_button.dart                    # NEW — red toggle + progress ring
            ├── capture_duration_selector.dart        # NEW — Video | 15s | 30s | 60s
            └── mention_suggestions_overlay.dart      # NEW — OverlayPortal panel anchored below the field (revised — field sits near the screen top, FR-082)

test/features/reels/                                  # + capture_cubit_test, mention_suggestions_cubit_test, overlay + trimmer-param widget tests
```

## Binding v3 design rules (from spec FR-060–FR-067 + clarifications)

1. **Fail-closed pipeline (FR-066)**: the ONLY transition to `published` is a clean provider verdict recorded by the worker. Provider errors/timeouts → BullMQ retry (5 attempts, exponential backoff starting 30 s); exhausted jobs stay `pending_moderation` and are re-enqueued by a sweep on boot/interval. Missing provider credentials → warning log, jobs wait (dev uses the stub provider); never auto-publish. The worker logs verdict latency (upload → verdict) on every transition so the SC-018 ≤5-minute bound is observable in production.
2. **Status filter (FR-061)**: `reels.service.ts` applies `status: 'published'` to feed (all variants), single reel, profile grids, search, hashtag feeds, liked/saved lists, and share/comment/like/view/save writes (engagement on non-published → 404 — FR-064). Exception: caller == creator sees own reels of any status (single fetch + own profile grid), with `status` in the DTO. Seed data is `published` at creation; a startup backfill sets `status: 'published'` on any pre-v3 doc missing the field.
3. **Publish-time mentions (FR-063)**: `notifyMentions` (T102) is invoked exclusively from the worker's publish transition. Upload parses/stores `mentions[]`/`hashtags[]` (existing util) but sends nothing. The `(type, actorId, recipientId, reelId)` dedup index guarantees exactly-once even if a job retries after a partial publish. At publish time the mention fan-out re-checks the block relationship (either direction) between uploader and each mentioned user — a block created between upload and verdict suppresses that mention notification (FR-052/FR-059 spirit applied to fan-out).
4. **Rejection path (FR-064)**: worker sets `status: 'rejected'`, stores the moderation result (embedded subdoc: verdict, flaggedSource video|description, categories, providerRef, completedAt), leaves the media file on disk but unreachable through any API (soft delete; retention/purge job explicitly out of scope), writes a `reelRejected` notification event (system-originated: `actorId: null`, self-skip rule bypassed for system types) and pushes to the owner. Tap → owner profile (`/reels/profile/:selfId`).
5. **Upload contract (FR-060/060a)**: multipart `video` (mp4/mov/webm mimetypes, ≤100 MB Multer cap — chat pattern, higher limit), optional `thumbnail` (jpg/png ≤2 MB), `description` (trimmed ≤2200). Client enforces ≤60 s (camera capture via `image_picker` `maxDuration`; gallery >60 s → mandatory trimmer). **Server independently enforces the duration cap** (FR-060a): the upload handler parses container metadata (lightweight parser, e.g. `music-metadata` — no ffmpeg) and rejects duration > 61 s (1 s tolerance for container rounding) with 400; unparseable duration → 400 (fail-closed, official clients always produce parseable mp4/mov). Server also rejects >100 MB/wrong type with 400; no partial reel on any failure (file cleanup in a catch — FR-060). Response: owner ReelDto with `status: 'pending_moderation'`.
6. **Thumbnail**: extracted client-side during the trim/export ffmpeg session (first-frame `-frames:v 1`); for untrimmed ≤60 s picks, a single ffmpeg frame-grab runs before upload. No server-side ffmpeg dependency.
7. **Delete cascade (FR-067)**: owner check (403 otherwise) → delete reel doc + relation docs (`reel_likes/saves/views/shares/comments`) → `$inc` creator `totalLikes: -reel.likesCount` → remove reel-scoped notification events → unlink media files. Single-pass sequential writes (same no-transaction posture as R9); orphan tolerance acceptable (counts self-heal only via this path, so cascade order puts counter adjustment before doc deletion).
8. **Queue hygiene**: job payload is `{ reelId }` only (worker re-reads the doc — idempotent re-processing); jobs deduplicated by `jobId: reelId`; a deleted reel's in-flight job no-ops (doc gone). Redis unavailability at enqueue → upload still succeeds, reel stays pending, sweep re-enqueues (fail-closed, never fail-open).

## Binding v4 design rules (from spec FR-068–FR-078 + 2026-07-05 clarifications)

9. **Exactly-once hide (FR-070/SC-021)**: the report handler first checks the caller's daily count (`reel_reports` on `{reporterId, createdAt}` ≥ today) against `REEL_REPORT_DAILY_LIMIT` (Joi-validated, default 20) → `429` recording nothing. Otherwise the threshold check runs on the value returned by the `$inc` on `reportsCount` (performed only on a real `reel_reports` insert — the unique index makes duplicates no-ops); the hide itself is `findOneAndUpdate({_id, status: 'published', adminRestored: {$ne: true}}, {status: 'hidden'})` — concurrent reports at the boundary race harmlessly (one wins, others no-op), and an admin-restored reel is permanently immune. Threshold from `REEL_REPORT_AUTOHIDE_THRESHOLD` env (Joi-validated, default 25). The report response never reveals count or transition.
10. **Three status writers only** (data-model v4): moderation worker (`pending → published|rejected`), report service (`published → hidden`), admin endpoint (`hidden → published|rejected`) — every transition a guarded `findOneAndUpdate` with a status precondition. Admin restore sets `adminRestored: true` (permanent auto-hide immunity — "one auto-hide per reel ever"; `reportsCount` retained for audit). No other code path may write `status`.
11. **For You merge (FR-076, R20)**: two legs — global (v1 catalog-loop behavior) + reposts by followees∪self ordered by repost `createdAt` desc. Service-side dedup per page (repost-attributed instance wins; most recent followed reposter attributed); the opaque cursor packs both legs' positions (R20 decides encoding — resolve before T-tasks freeze the DTO). `ReelsFeedBloc` drops already-loaded reel ids as the cross-page backstop (verify the v1 looping feed already tolerates repeats). Reposter-edge block filter composes with the existing blockSet on every injected item (FR-078).
12. **v4 surfaces stay silent (FR-072/FR-073)**: no new push types — auto-hide, admin restore/reject, and reposts notify no one in v1. The `hidden` status reaches only the owner's DTOs (label "Under review"); `reportsCount` is never serialized into any DTO.

## Binding v5 design rules (from spec FR-079–FR-084 + 2026-07-06 clarifications)

13. **Capture lifecycle (FR-079/FR-080)**: single continuous clip — no segmented recording. A timer auto-stops at the selected cap (±0.5 s, SC-025); sub-1 s takes are discarded with a notice; a lifecycle pause stops the recording safely (a ≥1 s segment proceeds to the trimmer, per the interrupted-recording edge case). Permission denial renders the FR-079 explanation state with an open-settings action — never a black preview or crash. The 15s/30s/60s selector is disabled while recording; the flash control is hidden on the front camera.
14. **Safe-path handoff (R22)**: every capture/pick is copied to `<appDocs>/reels_tmp/<uuid>.mp4` before the trimmer opens; `reels_tmp` is purged on every flow exit (post, back-out, abandon). No partial/phantom reel on any exit path (FR-060 carried).
15. **Trimmer contract (FR-081)**: `maxDuration` = the capture-time cap for recordings, 60 s for gallery picks; the CTA reads "Next"; back = discard confirmation → camera. Straight-to-trimmer — no preview/confirm step between stopping a recording and the trimmer (clarified).
16. **Post-details + mentions (FR-082/FR-083)**: description + preview thumbnail + Post, nothing else. The suggestion overlay lists followed users only, is fetched **once per screen visit** (never per keystroke), filters in memory, inserts `@username ` on tap, and never blocks typing (empty/failed list = no overlay). Mention notification semantics are untouched — they still fire exactly once, at publish (FR-063); the overlay changes composition convenience only.

## Phase 2 preview — v4 (for /speckit-tasks, not executed here)

Suggested order: **(1)** ERD v4 re-approval (FR-056 gate — `reel_reports`/`reel_reposts`, `hidden`, `reportsCount`, 3-writer state machine) → **(2)** schemas + `hidden` status + visibility regression (e2e: hidden invisible to non-owners on every surface, owner sees "Under review") → **(3)** report endpoint + DTO + daily limit (429) + threshold hide (unit: exactly-once under concurrency, duplicate idempotency, adminRestored immunity) → **(4)** admin guard + moderation endpoint + hidden-list endpoint (restore sets adminRestored; 401/404/409 paths) → **(5)** repost toggle endpoints → **(6)** following feed + For You two-leg merge/dedup/`repostedBy` (R20 cursor first) → **(7)** Flutter domain/data delta (entities, models, repository, datasource) → **(8)** action-column layout swap (Repost button in, Save into the extended more-options sheet) + reasons sheet + repost badge → **(9)** feed tabs (`feedScope` blocs, toggle UI, exclusive playback, per-tab resume) + "Under review" badge → **(10)** i18n (en/ar) + tests + quickstart §13 + full regression.

## Phase 2 preview — v5 (for /speckit-tasks, not executed here)

Suggested order: **(1)** FR-056 gate — stakeholder acknowledgment of the data-model v5 no-ERD-change note → **(2)** backend `GET /me/following` + unit/e2e (ordering, pagination, block filter — contracts §31) → **(3)** Flutter domain/data delta (`FollowedUser` entity/model, datasource + repository methods) → **(4)** `camera` dependency + capture screen + `CaptureCubit` (record toggle, cap auto-stop, permission states, lifecycle teardown) → **(5)** safe-path copy + trimmer `maxDuration`/"Next" (R22) → **(6)** post-details rebuild + mention overlay + `MentionSuggestionsCubit` → **(7)** routing swap (`/reels/capture` as the "+" destination) + i18n (en/ar) → **(8)** tests + quickstart §15 walkthrough + v1 performance-gate regression (fold the device pass into the outstanding T136/T162 session).

## Complexity Tracking

> Constitution deviations that must be justified (v1/v2 rows carry over unchanged)

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `Bloc` (not Cubit) for `ReelsFeedBloc` (II) | v1: pagination transformers (`droppable`) | carried over — unchanged |
| Network-only feed, no sqflite mirror (III) | v1/v2: ephemeral streamed media | carried over — unchanged |
| `media_kit` streaming instead of VIII-C file pattern | v1: stakeholder mandate | carried over — unchanged |
| **No offline upload queue (III) — v3** | An upload is a foreground, connectivity-dependent creation act; failed uploads surface an explicit retry (FR-060) | Persisting queued videos + background retry adds storage, lifecycle, and duplicate-upload risk for a v1 creator flow; WhatsApp-style resumable uploads are a future feature |
| **Two new Flutter packages (`video_editor`, `ffmpeg_kit_flutter_new`) — v3** | FR-060a mandates in-app WhatsApp-Status-style trimming; actual video cutting requires an ffmpeg binding (media_kit cannot cut files) | Server-side trimming rejected: uploads the full-length source (bandwidth, 100 MB cap conflicts) and adds a server ffmpeg dependency; platform-channel native trimmers are 2× custom code |
| **Report/repost network-only, no offline queue (III) — v4** | Same posture as every reels engagement write since v1: optimistic UI + revert on failure (FR-037/FR-073); reporting/reposting offline has no meaningful semantics on ephemeral streamed content | Queuing reports/reposts for replay adds storage + duplicate-risk for actions the user can simply retry; carried deviation, no new machinery |
| **Two live `ReelsFeedBloc` instances (one per tab) — v4** | FR-074 demands per-tab resume position and instant tab switching; a single re-scoped bloc would refetch and lose position on every switch | A merged two-scope state in one bloc entangles pagination/cursors of independent feeds and violates the bloc-per-logical-unit rule (II) more than a second instance does |
| **One new Flutter package (`camera`) — v5** | FR-079 mandates a custom full-screen capture UI (record toggle overlay, 15s/30s/60s selector, flip/flash) — `image_picker`'s system camera cannot host any custom UI | `camerawesome` rejected (opinionated built-in UI fights the strict reference layout, larger binary); platform-channel native capture rejected (2× per-platform code — same reasoning as the v3 trimmer row) |

## Phase 2 preview — v3 (delivered as T109–T136)

Suggested order: **(1)** ERD re-approval (FR-056 gate — status field + moderation subdoc + `reelRejected`) → **(2)** schema changes + seed/backfill to `published` + status filter across all reads (e2e: non-owner never sees non-published) → **(3)** upload endpoint + create-reel DTO + Multer config (no mention sends) → **(4)** BullMQ queue + processor + provider abstraction (stub first, Sightengine second) + publish/reject transitions + `reelRejected` push → **(5)** delete endpoint + cascade → **(6)** Flutter domain/data delta (status, upload, delete) → **(7)** trimmer + upload screens + `UploadCubit` + top-bar entry → **(8)** own-profile badges + delete UI + push routing + i18n → **(9)** e2e/regression + quickstart walkthrough.
