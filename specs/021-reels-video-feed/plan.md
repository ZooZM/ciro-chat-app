# Implementation Plan: Reels / Short Videos Feed

**Branch**: `021-reels-video-feed` | **Date**: 2026-07-03 (v3 — re-planned after the upload + automated content moderation update and its clarification session) | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/021-reels-video-feed/spec.md`

## Summary

v1 (feed, overlay, profiles, follow, share sheet, deep links — US1–US6) and v2 (real MongoDB, shared identity + blocking, descriptions/hashtags/mentions, views, saves/liked lists, own profile, search, FCM notifications — US7–US9) are **fully implemented** (tasks T001–T108 complete). This v3 plan covers only the delta added by the 2026-07-03 spec update and clarifications — **US10: reel upload with automated explicit/NSFW content moderation** (App Store UGC compliance, FR-060–FR-067):

1. **Upload endpoint** — `POST /api/reels` (multipart: video ≤60 s + optional thumbnail + description) following the backend's existing Multer `diskStorage` pattern (chat/status controllers); creates the reel with `status: 'pending_moderation'` and enqueues a moderation job. Description parsing reuses `reels-text.util.ts`; **mention notifications do NOT fire here** — they move to the publish transition (FR-063), giving `notifyMentions` (built in T102, currently caller-less) its live caller.
2. **Moderation status state machine** — `reels.status ∈ {pending_moderation, published, rejected}`; every public read path gains a `status: 'published'` filter (seeded catalog is backfilled/created as `published`); owner-facing reads include own pending/rejected reels with status. Non-owner fetch of a non-published reel → 404 (unknown-reel path, FR-061).
3. **Background moderation worker** — BullMQ (`@nestjs/bullmq` + Redis, already dependencies) queue `reels-moderation`; processor calls a `ModerationProvider` abstraction (primary: **Sightengine** video + text endpoints — accepts direct upload of the locally stored file, no cloud-bucket prerequisite; a `stub` provider for dev/tests). Clean → `published` + `notifyMentions`; flagged (video OR description) → `rejected` + soft-delete (media hidden, retained on disk) + `reelRejected` notification event + push (FR-062–FR-064). Fail-closed: provider failure keeps `pending_moderation`, BullMQ retries with exponential backoff (FR-066).
4. **Owner deletion** — `DELETE /api/reels/:id` (owner-only, any status): cascade relations, counter adjustments, media file removal; deep link then 404s (FR-067).
5. **Flutter upload flow** — "+" entry in the Reels top bar → record (camera, `image_picker` `maxDuration: 60s`) or pick from gallery; >60 s sources open a WhatsApp-Status-style trimmer; description input; `dio` multipart with progress. Own profile grid gains status badges ("Processing" / "Removed due to policy violations") and owner delete; push tap-routing gains `reelRejected` (FR-060/FR-060a/FR-065).

## Technical Context

**Language/Version**: Dart (Flutter, SDK ^3.9.2) frontend; TypeScript / NestJS 11 (Express platform) backend
**Primary Dependencies**: Flutter existing: `media_kit` stack, `flutter_bloc` 9, `get_it`/`injectable`, `dio`, `go_router`, `fpdart`, `equatable`, `cached_network_image`, `image_picker` (video record/pick — already present), `firebase_messaging`. **New Flutter packages (v3)**: `video_editor` (trim UI) + `ffmpeg_kit_flutter_new` (trim export + thumbnail frame extraction) — see R16; exact pins verified at implementation time. Backend existing: `@nestjs/mongoose` + `mongoose` 9, `@nestjs/bullmq` + `bullmq` + `ioredis` (registered in `app.module.ts`), Multer via `@nestjs/platform-express`, `firebase-admin`. **New backend dependency**: one lightweight container-metadata parser for server-side duration validation (e.g., `music-metadata` — no ffmpeg); Sightengine itself is plain REST via existing `@nestjs/axios`
**Storage**: MongoDB (v2, unchanged) + local-disk media under `uploads/reels/` served statically (existing `main.ts` static-assets pattern; CDN swap remains a data-value change). Redis required at runtime for the BullMQ moderation queue (`REDIS_URL` already in env)
**Testing**: Backend — Jest unit (moderation processor state transitions, provider stub, publish-time `notifyMentions`, delete cascade) + e2e on `mongodb-memory-server` (status filtering on every read surface, owner-vs-other visibility, upload → pending → publish/reject flows with the stub provider). Flutter — `bloc_test`/`mocktail` (`UploadCubit` progress/failure, status-badge rendering); existing 33 reels tests stay green
**Target Platform**: iOS + Android; backend Node.js (docker-compose local Mongo + Redis)
**Project Type**: Mobile app + API backend (this Flutter repo + `chat-app-backend`)
**Performance Goals**: v1/v2 gates unchanged (SC-001..SC-016) plus: upload response never blocked by moderation (FR-062), moderation verdict ≤5 min for ≤60 s videos (SC-018), zero unmoderated public exposure (SC-017)
**Constraints**: fail-closed moderation (never publish without an explicit clean verdict — FR-066); `status: 'published'` filter on EVERY non-owner read path, enforced server-side only (FR-061); mention notifications fire exactly once, at publish, never at upload (FR-063); upload cap 60 s / 100 MB, longer sources trimmed client-side (FR-060a); rejected media soft-deleted (hidden, retained) not purged (Assumption)
**Scale/Scope**: Backend — 1 schema change (reel status + embedded moderation subdoc) + 2 endpoints (upload, delete) + 1 BullMQ processor + 1 provider abstraction (Sightengine + stub) + status filter across ~9 read paths + seed backfill. Flutter — 2 new screens (upload/compose, trimmer), 1 new cubit (`UploadCubit`), top-bar "+" entry, status badges + delete on own profile, 1 new push route, i18n keys (en/ar)

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

## Project Structure

### Documentation (this feature)

```text
specs/021-reels-video-feed/
├── plan.md              # This file (v3)
├── research.md          # R1–R8 (v1) + R9–R14 (v2) + R15–R19 (v3 moderation/upload decisions)
├── data-model.md        # ERD v3 — reel status state machine + moderation result (FR-056 re-approval)
├── quickstart.md        # + US10 verification (upload, moderation stub, rejection push)
├── contracts/
│   └── reels-api.md     # + endpoints 21–24 (upload, delete, moderation pipeline, reelRejected push)
├── checklists/
│   └── requirements.md  # Spec quality checklist (passing, re-validated 2026-07-03)
└── tasks.md             # Phase 2 (/speckit-tasks — regenerate for v3 scope)
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

## Binding v3 design rules (from spec FR-060–FR-067 + clarifications)

1. **Fail-closed pipeline (FR-066)**: the ONLY transition to `published` is a clean provider verdict recorded by the worker. Provider errors/timeouts → BullMQ retry (5 attempts, exponential backoff starting 30 s); exhausted jobs stay `pending_moderation` and are re-enqueued by a sweep on boot/interval. Missing provider credentials → warning log, jobs wait (dev uses the stub provider); never auto-publish. The worker logs verdict latency (upload → verdict) on every transition so the SC-018 ≤5-minute bound is observable in production.
2. **Status filter (FR-061)**: `reels.service.ts` applies `status: 'published'` to feed (all variants), single reel, profile grids, search, hashtag feeds, liked/saved lists, and share/comment/like/view/save writes (engagement on non-published → 404 — FR-064). Exception: caller == creator sees own reels of any status (single fetch + own profile grid), with `status` in the DTO. Seed data is `published` at creation; a startup backfill sets `status: 'published'` on any pre-v3 doc missing the field.
3. **Publish-time mentions (FR-063)**: `notifyMentions` (T102) is invoked exclusively from the worker's publish transition. Upload parses/stores `mentions[]`/`hashtags[]` (existing util) but sends nothing. The `(type, actorId, recipientId, reelId)` dedup index guarantees exactly-once even if a job retries after a partial publish. At publish time the mention fan-out re-checks the block relationship (either direction) between uploader and each mentioned user — a block created between upload and verdict suppresses that mention notification (FR-052/FR-059 spirit applied to fan-out).
4. **Rejection path (FR-064)**: worker sets `status: 'rejected'`, stores the moderation result (embedded subdoc: verdict, flaggedSource video|description, categories, providerRef, completedAt), leaves the media file on disk but unreachable through any API (soft delete; retention/purge job explicitly out of scope), writes a `reelRejected` notification event (system-originated: `actorId: null`, self-skip rule bypassed for system types) and pushes to the owner. Tap → owner profile (`/reels/profile/:selfId`).
5. **Upload contract (FR-060/060a)**: multipart `video` (mp4/mov/webm mimetypes, ≤100 MB Multer cap — chat pattern, higher limit), optional `thumbnail` (jpg/png ≤2 MB), `description` (trimmed ≤2200). Client enforces ≤60 s (camera capture via `image_picker` `maxDuration`; gallery >60 s → mandatory trimmer). **Server independently enforces the duration cap** (FR-060a): the upload handler parses container metadata (lightweight parser, e.g. `music-metadata` — no ffmpeg) and rejects duration > 61 s (1 s tolerance for container rounding) with 400; unparseable duration → 400 (fail-closed, official clients always produce parseable mp4/mov). Server also rejects >100 MB/wrong type with 400; no partial reel on any failure (file cleanup in a catch — FR-060). Response: owner ReelDto with `status: 'pending_moderation'`.
6. **Thumbnail**: extracted client-side during the trim/export ffmpeg session (first-frame `-frames:v 1`); for untrimmed ≤60 s picks, a single ffmpeg frame-grab runs before upload. No server-side ffmpeg dependency.
7. **Delete cascade (FR-067)**: owner check (403 otherwise) → delete reel doc + relation docs (`reel_likes/saves/views/shares/comments`) → `$inc` creator `totalLikes: -reel.likesCount` → remove reel-scoped notification events → unlink media files. Single-pass sequential writes (same no-transaction posture as R9); orphan tolerance acceptable (counts self-heal only via this path, so cascade order puts counter adjustment before doc deletion).
8. **Queue hygiene**: job payload is `{ reelId }` only (worker re-reads the doc — idempotent re-processing); jobs deduplicated by `jobId: reelId`; a deleted reel's in-flight job no-ops (doc gone). Redis unavailability at enqueue → upload still succeeds, reel stays pending, sweep re-enqueues (fail-closed, never fail-open).

## Complexity Tracking

> Constitution deviations that must be justified (v1/v2 rows carry over unchanged)

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `Bloc` (not Cubit) for `ReelsFeedBloc` (II) | v1: pagination transformers (`droppable`) | carried over — unchanged |
| Network-only feed, no sqflite mirror (III) | v1/v2: ephemeral streamed media | carried over — unchanged |
| `media_kit` streaming instead of VIII-C file pattern | v1: stakeholder mandate | carried over — unchanged |
| **No offline upload queue (III) — v3** | An upload is a foreground, connectivity-dependent creation act; failed uploads surface an explicit retry (FR-060) | Persisting queued videos + background retry adds storage, lifecycle, and duplicate-upload risk for a v1 creator flow; WhatsApp-style resumable uploads are a future feature |
| **Two new Flutter packages (`video_editor`, `ffmpeg_kit_flutter_new`) — v3** | FR-060a mandates in-app WhatsApp-Status-style trimming; actual video cutting requires an ffmpeg binding (media_kit cannot cut files) | Server-side trimming rejected: uploads the full-length source (bandwidth, 100 MB cap conflicts) and adds a server ffmpeg dependency; platform-channel native trimmers are 2× custom code |

## Phase 2 preview (for /speckit-tasks, not executed here)

Suggested order: **(1)** ERD re-approval (FR-056 gate — status field + moderation subdoc + `reelRejected`) → **(2)** schema changes + seed/backfill to `published` + status filter across all reads (e2e: non-owner never sees non-published) → **(3)** upload endpoint + create-reel DTO + Multer config (no mention sends) → **(4)** BullMQ queue + processor + provider abstraction (stub first, Sightengine second) + publish/reject transitions + `reelRejected` push → **(5)** delete endpoint + cascade → **(6)** Flutter domain/data delta (status, upload, delete) → **(7)** trimmer + upload screens + `UploadCubit` + top-bar entry → **(8)** own-profile badges + delete UI + push routing + i18n → **(9)** e2e/regression + quickstart walkthrough.
