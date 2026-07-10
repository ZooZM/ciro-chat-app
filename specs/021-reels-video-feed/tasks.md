# Tasks: Reels / Short Videos Feed — v4 (user reporting + reposting / feed tabs) + v5 (camera-first creation)

**Input**: Design documents from `/specs/021-reels-video-feed/` (plan.md v4, spec.md US11–US12 + FR-068–FR-078 + 2026-07-05 clarifications, research.md R20, data-model.md v4 ERD, contracts/reels-api.md endpoints 25–30, quickstart.md §13–§14). **v5 input**: plan.md v5 + "Phase 2 preview — v5", spec.md US13 + FR-079–FR-084 + 2026-07-06 clarifications, research.md R21–R24, data-model.md v5 note, contracts §31, quickstart §15
**Prerequisites**: v1 (US1–US6, T001–T069), v2 (US7–US9 + notifications, T071–T108), and v3 (US10 upload + moderation, T109–T136) are **implemented and verified** — their checklists are superseded by this file. This file tracks the v4 delta only; IDs continue from T137.

**Tests**: Included — plan.md mandates Jest unit/e2e (backend, `mongodb-memory-server`) and `bloc_test`/`mocktail` (Flutter).

**Organization**: v4 has two user stories — **US11** (report a reel with auto-hide, P11) and **US12** (repost + Following/For You tabs, P12). They are independent after the shared Phase 2 schema work: US11 owns the report/hide/admin pipeline; US12 owns the repost relation, feed composition, and tab UI. The action-column layout swap (Repost replaces Save; Save moves into the 3-dots sheet — clarified 2026-07-05) is split so each story stays independently shippable: US11 adds Save to the sheet, US12 removes Save from the column. **v5** adds a single story — **US13** (camera-first creation, P13) — as Phases 6–8 below (T163+).

**Repos**: Flutter = this repo. Backend = `/Volumes/Zeyad/Documents/work/Node js/chat-app-backend` (paths prefixed `backend:`).

**v5 Status**: 15/16 tasks (T163–T178) complete — implemented 2026-07-06. Backend: `GET /me/following` implemented (T166); reels unit suite 58/58 green (T167); reels e2e suite could not run this session (`mongodb-memory-server` cannot download its binary — no network access in this sandbox; the new e2e block is written and typechecks but is unverified against a live Mongo). Flutter: full camera-first flow implemented (capture screen, safe-path trimmer handoff, minimal post-details, mention overlay, routing swap); reels test suite 90/90 green (61 pre-v5 + 29 new); `flutter analyze` zero new issues. One implementation-time correction: the mention overlay is anchored *below* the description field, not above (R23 revised — the field sits near the screen top per FR-082, and anchoring above pushed the panel off-screen; caught by `mention_suggestions_overlay_test.dart`). T178 (consolidated device walkthrough) **supersedes and absorbs** the outstanding T136 (v3) and T162 (v4) — **not run this session, no simulator/device available**, consistent with how T136/T162 were themselves deferred; this is the only remaining v5 task.

**Status**: 25/26 v4 tasks (T137–T161) are complete. Backend: 56/56 reels unit tests + 35/35 reels e2e tests pass (24 pre-v4 + 7 US11 + 4 US12); full backend suite shows only pre-existing failures in unrelated modules (video/chat/auth/status — zero diff this session, confirmed pre-existing). Flutter: 61/61 reels tests pass (49 pre-v4/US11 + 12 US12); `flutter analyze` shows zero new issues project-wide (6 pre-existing info-level lints in reels blocs, unrelated to v4). T162 (on-device walkthrough) could not be executed — no simulator/device available in this session; see its entry below for what to verify before merge, alongside the still-outstanding v3 T136.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US11 / US12) — story phases only

---

## Phase 1: Setup (v4)

**Purpose**: Approval gate, environment, shared strings

- [X] T137 ⚠️ GATE (FR-056 re-triggered): v4 ERD delta approved by stakeholder (2026-07-05) — `reel_reports` + `reel_reposts` collections, `hidden` status value, `reportsCount`/`adminRestored` fields, three-writer state machine, feed-composition rules (data-model.md v4). Backend implementation proceeds.
- [X] T138 [P] backend: `REEL_REPORT_AUTOHIDE_THRESHOLD` (number, default 25), `REEL_REPORT_DAILY_LIMIT` (number, default 20), `ADMIN_API_KEY` (string, required in production, no default) added to `.env.example` + `app.module.ts`'s Joi validation schema
- [X] T139 [P] Flutter: v4 localization keys in `assets/translations/en.json` + `ar.json` — `reels.report_*` (sheet title, 5 reasons, custom-reason hint, submit, confirmation, rate-limit notice), `reels.status_under_review`, `reels.repost` / `reels.unrepost`, `reels.reposted_by` / `reels.you_reposted`, `reels.tab_following` / `reels.tab_for_you`, `reels.following_empty_*`

---

## Phase 2: Foundational (blocks both stories — schema + status machinery)

**Purpose**: v4 schema fields and collections exist; `hidden` behaves like every other non-published status on all existing surfaces (zero query changes — the `status: 'published'` filter from v3 already excludes it). After this phase all v1–v3 behavior is unchanged.

- [X] T140 backend: `schemas/reel.schema.ts` — `ReelStatus.HIDDEN` enum value, `reportsCount` (number, default 0), `adminRestored` (boolean, default false); NEW `schemas/reel-report.schema.ts` (`videoId`, `reporterId`, `reason` enum `spam|nudity|violence|hate_speech|other`, `customReason?`, timestamps; indexes: `{videoId, reporterId}` unique, `{videoId}`, `{reporterId, createdAt}`); NEW `schemas/reel-repost.schema.ts` (`videoId`, `reposterId`, timestamps; indexes: `{videoId, reposterId}` unique, `{reposterId, createdAt}`, `{videoId}`); both registered in `reels.module.ts`. Follow the ObjectId-typing convention from the v3 debt note (always pass `Types.ObjectId` via `toObjectId()`)
- [X] T141 backend: e2e regression in `test/reels.e2e-spec.ts` (`hidden visibility` describe block) — a reel set to `hidden` directly in the DB is invisible to non-owners on single-fetch/feed/profile-grid/search/hashtag and its engagement actions 404 (existing FR-064 rule); the owner sees it with `status: 'hidden'`. All pre-existing v1–v3 suites stay green unchanged
- [X] T142 [P] Flutter: `ReelStatus.hidden` added to `lib/features/reels/domain/entities/reel_status.dart` + parsing in `reel_model.dart` (unknown statuses still default safely); `reel_status_badge.dart` gains the "Under review" case (`reels.status_under_review`), rendering nothing for `published` as before; badge widget test extended (4 states)

**Checkpoint**: schemas exist, `hidden` is a first-class invisible status everywhere, no user-facing change yet.

---

## Phase 3: User Story 11 — Report a Reel with Auto-Hide (P11)

**Goal**: 3-dots sheet gains Save (relocated) + Report; reasons sheet (presets + Other w/ required text); backend records reports (one per user per reel, ≤20/day), auto-hides at the threshold exactly once, admin lists/restores/rejects hidden reels, restore grants permanent auto-hide immunity (FR-068–FR-072).

**Independent Test**: quickstart.md §13 (report flow + auto-hide) and §14 (rate limit) with `REEL_REPORT_AUTOHIDE_THRESHOLD=3`: report from 3 accounts → reel vanishes publicly, owner sees "Under review"; admin list shows it with reasons; restore → visible again + immune to further mass-reporting; duplicate and over-limit reports record nothing.

### Backend track

- [X] T143 [US11] backend: NEW `dto/report-reel.dto.ts` (`reason` enum; `customReason` trimmed ≤500, required iff `reason === 'other'`, forbidden otherwise) + `POST /:id/report` in `reels.controller.ts`; `ReelsService.reportReel`: own-reel → 400, non-published → 404, daily count via `reel_reports {reporterId, createdAt ≥ startOfDay}` ≥ `REEL_REPORT_DAILY_LIMIT` → 429 (nothing recorded), insert-if-absent (duplicate → `{reported: true, alreadyReported: true}` no-op), real insert → `$inc reportsCount` in `reels-db.repository.ts` and, when the post-inc value ≥ `REEL_REPORT_AUTOHIDE_THRESHOLD`, guarded hide `findOneAndUpdate({_id, status: 'published', adminRestored: {$ne: true}}, {status: 'hidden'})` (contracts §25, binding rule 9)
- [X] T144 [US11] backend: NEW `admin-key.guard.ts` (`x-admin-key` header vs `ADMIN_API_KEY` env → 401) + `PATCH /:id/moderation` (`{action: 'restore'|'reject'}`; guarded `findOneAndUpdate` precondition `status: 'hidden'` → 409 otherwise, 404 unknown; restore → `published` + `adminRestored: true`, `reportsCount` retained; reject → `rejected`, no push) + `GET /moderation/hidden` (cursor-paginated, newest-hidden-first, each item with creator, `reportsCount`, and its `reel_reports` list — contracts §29–30). Both routes declared before `/:id`
- [X] T145 [P] [US11] backend: unit tests in `reels.service.spec.ts` — duplicate report idempotency (count unchanged), daily-limit 429 records nothing, own-reel 400, non-published 404, threshold fires the hide exactly once under two concurrent boundary reports, `adminRestored` reel never re-hides, admin restore sets the flag / reject transitions / non-hidden 409, guard 401
- [X] T146 [US11] backend: e2e in `test/reels.e2e-spec.ts` (`reporting & auto-hide` describe block, threshold overridden to 3 via config) — 3 unique reports → hidden on every public surface + deep link 404 + owner sees "hidden"; engagement recorded before the hide survives; admin hidden-list contains the reel with reasons; restore → public again with prior counts, then 3 fresh reports do NOT re-hide (immunity); reject path → rejected presentation; 429 on the limit; wrong/missing admin key → 401

### Flutter track

- [X] T147 [P] [US11] Flutter: `ReportReason` enum in `lib/features/reels/domain/entities/report_reason.dart` + `reportReel(reelId, reason, {customReason})` through `reels_remote_datasource.dart` → `reels_repository.dart`/`reels_repository_impl.dart` (`Either<Failure, void>`; 429 mapped to a dedicated retryable `Failure` so the UI can show the rate-limit notice)
- [X] T148 [US11] Flutter: extend `reel_more_button.dart` — render for ALL viewers (drop the owner-only gate): sheet lists **Save/Unsave** (relocated per FR-068 — reuse the existing save toggle from `ReelsInteractionCubit`; `save_button.dart` stays in the column until US12 swaps it) + **Report** (non-owner) or **Delete** (owner, unchanged); NEW `report_reasons_sheet.dart` — 5 presets, selecting **Other** reveals a `TextField` (submission disabled while empty/whitespace, ≤500); submit → confirmation snackbar, failure → non-intrusive notice (rate-limit gets its own message), sheet dismissal never touches playback
- [X] T149 [P] [US11] Flutter: widget/bloc tests — `report_reasons_sheet_test.dart` (preset submit enabled, Other requires non-empty text, whitespace stays disabled), `reel_more_button_test.dart` (owner sees Save+Delete, non-owner sees Save+Report)

**Checkpoint**: US11 fully demoable per quickstart §13 report bullets + §14 — independent of US12.

---

## Phase 4: User Story 12 — Repost + Following/For You Tabs (P12)

**Goal**: dedicated Repost toggle in the action column (Save's former slot), repost relation on the backend, Following tab (followees' originals only), For You tab with followed-users' reposts injected (merged by repost recency, deduped, `repostedBy` badge, reposter-edge block filtering) (FR-073–FR-078).

**Independent Test**: quickstart.md §13 (repost + tabs bullets): A follows B; B reposts C's reel → it appears in A's For You with a "B reposted" badge (not tappable), absent from A's Following; B's own upload appears in A's Following; B sees "You reposted"; un-repost/block removes the injection; no reel appears twice in one session.

### Backend track

- [X] T150 [US12] backend: `POST /:id/repost` + `DELETE /:id/repost` in `reels.controller.ts`; `ReelsService.toggleRepost`: self-repost → 400, non-published → 404, insert/delete `reel_reposts` with relation-write-outcome idempotency (repeat POST → 200 `{reposted: true}`, DELETE of nothing → quiet `{reposted: false}`) in `reels-db.repository.ts` (contracts §26–27)
- [X] T151 [US12] backend: `GET /following` in `reels.controller.ts` (declared before `/:id`, sibling to `/liked`/`/saved`) — original reels where `creatorId ∈ followees(caller)`, `status: 'published'`, block-filtered, `createdAt` desc, standard single-leg cursor, finite (`nextCursor: null`), `repostedBy` always null (contracts §28, FR-075)
- [X] T152 [US12] backend: For You injection in `ReelsService.getFeed`/`reels-db.repository.ts` — repost leg (`reel_reposts` where `reposterId ∈ followees(caller) ∪ {caller}`, repost `createdAt` desc) merged with the global leg per R20: base64 packed cursor `{g, r}`, per-page dedup (repost-attributed instance wins; most recent followed reposter attributed), `repostedBy {id, username, name, avatarUrl}` + `viewerReposted` hydration on `ReelDto`, reposter-edge mutual-block suppression, followed-state re-checked at query time (FR-076/FR-078)
- [X] T153 [P] [US12] backend: unit tests in `reels.service.spec.ts` — repost toggle idempotency, self-repost 400, non-published 404, merge dedup (same reel in both legs → one instance with `repostedBy`), multi-reposter attribution picks most recent, reposter-block suppression leaves the organic instance badge-less, own repost carries `repostedBy` = self
- [X] T154 [US12] backend: e2e in `test/reels.e2e-spec.ts` (`repost & feed tabs` describe block) — A follows B, B reposts C's reel: A's `GET /reels` page contains it exactly once with `repostedBy.username == B`; A's `GET /reels/following` contains B's originals only (no reposts); un-repost → gone from A's next fetch; A blocks B → injection suppressed; repost of a pending/hidden reel → 404; source reel hidden after repost → injected copy gone; C never gets a notification event

### Flutter track

- [X] T155 [P] [US12] Flutter: domain/data delta — NEW `ReelReposter` entity (`id`, `username`, `name`, `avatarUrl`) + `repostedBy?` and `viewerReposted` on `Reel`/`reel_model.dart` (tolerant of absent fields); `repostReel`/`unrepostReel` + `feedScope`-aware feed fetch (`forYou` default | `following` → `/reels/following`) through `reels_remote_datasource.dart` → repository (`Either<Failure, T>`)
- [X] T156 [US12] Flutter: NEW `repost_button.dart` — action-column primary Repost toggle (repeat glyph, e.g. `CupertinoIcons.arrow_2_squarepath`) in Save's former slot in `reel_interaction_overlay.dart` (`save_button.dart` removed from the column — its toggle now lives only in the T148 sheet); hidden/disabled on own reels; optimistic active state via a `reposts` map in `ReelsInteractionCubit` (same revert pattern as saves, FR-037)
- [X] T157 [US12] Flutter: NEW `repost_badge.dart` — const-leaf pill (repeat icon + "`[name]` reposted" / "You reposted") rendered directly above the creator name in `reel_creator_header.dart`/`reel_page.dart` when `reel.repostedBy != null`; NOT tappable (taps fall through to video pause/resume); no overlay rebuild coupling (FR-014)
- [X] T158 [US12] Flutter: feed tabs — Following | For You top toggle on `reels_feed_screen.dart` (For You default; must not obstruct own-profile icon, search entry, or status bar); `ReelsFeedBloc` gains a constructor `feedScope`; two bloc instances (one per tab), switching stops the outgoing tab's playback immediately and resumes the incoming tab's own position (FR-004/FR-004a/FR-009); pagination drops already-loaded reel ids **within the repost-injection window only** (R20 client backstop — verify the v1 catalog-loop repeats stay unaffected); Following empty state (`reels.following_empty_*`)
- [X] T159 [P] [US12] Flutter: tests — `repost_button` cubit/widget tests (toggle + revert-on-failure + hidden-on-own-reel), `repost_badge_test.dart` ("[name] reposted" vs "You reposted" vs absent), `reels_feed_bloc` feedScope test (following scope hits the following fetch; duplicate-id page dedup)

**Checkpoint**: US12 fully demoable per quickstart §13 repost/tab bullets — layout swap complete (column: Love/Comment/Share/Repost/3-dots; sheet: Save + Report/Delete).

---

## Phase 5: Polish & Cross-Cutting

- [X] T160 [P] `dart run build_runner build --delete-conflicting-outputs` (any new injectables registered) + `flutter analyze` — zero new issues (pre-existing warnings in unrelated modules tolerated, must show zero diff)
- [X] T161 Full regression — backend: complete reels unit + e2e suites green (v1–v3 blocks unchanged); Flutter: all reels tests green including the v3 59 (`reel_more_button` owner-only test updated by T149 is the only expected change); document any newly-discovered pre-existing failures exactly as T135 did
- [ ] T162 Manual on-device quickstart walkthrough — §13 + §14 end-to-end with two accounts and `REEL_REPORT_AUTOHIDE_THRESHOLD=3`, plus re-run of the v1 performance gates after the action-column swap and tab toggle (SC-012 ≤100 ms toggles, SC-022 no duplicates, SC-023 tab switch ≤2 s / never two audible videos). **NOT run this session — no simulator/device available**, consistent with how T136 flagged the same gap for v3. All automated coverage is green (backend: 56/56 reels unit + 35/35 reels e2e; Flutter: 61/61 reels tests; zero new `flutter analyze`/`tsc` issues) — recommended before merge, particularly:
  - The full report → auto-hide → admin restore/reject loop against the real `x-admin-key` header (automated tests drive it via supertest, never a real HTTP client + curl)
  - The action-column layout swap (Repost icon in Save's old slot; Save/Report/Delete in the 3-dots sheet) on a real screen size — confirm no visual crowding against the existing FR-002/FR-044 icons
  - Following ↔ For You tab switching on-device: confirm the outgoing video's audio actually stops within the FR-004 bound and the incoming tab's video starts within SC-023's 2 s bound (the player-pool `disposeAll()`-then-resync path is unit-tested via mocks, never against real `media_kit` players)
  - Repost badge legibility over bright/white video backgrounds (styled per the textual description in FR-077 — the stakeholder's reference image was never available)
  - ⚠️ Note: T136 (the v3 on-device walkthrough) is still outstanding — run both together before merge

---

# v5 delta: Camera-First Creation (US13) — added 2026-07-06

## Phase 6: Setup (v5)

**Purpose**: Approval gate, the one new dependency, platform permission plumbing, shared strings

- [X] T163 ⚠️ GATE (FR-056 re-triggered): stakeholder acknowledgment of the data-model.md v5 note — **no ERD change** (one read path over the existing `follows` `{followerId, createdAt}` index; no new collections, fields, or indexes). Backend work proceeds on acknowledgment.
- [X] T164 [P] Flutter: add `camera` to `pubspec.yaml` (`^0.11.x` — verify exact pin at install); iOS `ios/Runner/Info.plist` gains `NSCameraUsageDescription` + `NSMicrophoneUsageDescription`; Android `android/app/src/main/AndroidManifest.xml` gains `CAMERA` + `RECORD_AUDIO` permissions; `flutter pub get` + build sanity on both platforms
- [X] T165 [P] Flutter: v5 localization keys in `assets/translations/en.json` + `ar.json` — `reels.capture_*` (permission explanation title/body + open-settings action, discard-confirmation title/body, too-short notice, `video` / `15s` / `60s` selector labels), `reels.trim_next`, post-details strings (description hint, Post CTA) — reuse existing `reels.upload_*` keys where they fit

---

## Phase 7: User Story 13 — Camera-First Reel Creation (P13)

**Goal**: The "+" entry opens a full-screen in-app camera (red record toggle with 15s/60s auto-stop, gallery thumbnail, flip/flash only); every source lands directly in the trimmer (`maxDuration` = capture cap, "Next" CTA, space-free temp path); minimal post-details screen (description + preview + Post) with an `@`-mention suggestion overlay fed by the new followed-users endpoint (FR-079–FR-084).

**Independent Test**: quickstart.md §15 — capture-screen exactness, 15s auto-stop → straight to trimmer, permission-denial state, trimmer "Next" + `maxDuration` bounds, post-details minimalism, `@` overlay filter/insert/dismiss, submit → "Processing" (US10 loop unchanged), abandon → no phantom reel + empty `reels_tmp`.

### Backend track

- [X] T166 [US13] backend: `GET /me/following` in `reels.controller.ts` (declared before `/:id`, sibling to `/liked`/`/saved`) + `ReelsService.getFollowingUsers` + follows-by-follower cursor query in `reels-db.repository.ts` — ordered `follows.createdAt` desc (existing `{followerId, createdAt}` index), `limit` default 50 / max 100, hydrate followees to `{id, username, name, avatarUrl}`, filter mutually blocked users defensively (contracts §31, R24; ObjectId-typing convention via `toObjectId()`)
- [X] T167 [P] [US13] backend: tests — unit in `reels.service.spec.ts` (most-recently-followed ordering, block filtering, empty list) + e2e in `test/reels.e2e-spec.ts` (`followed-users list` describe block: auth required, cursor pagination, blocked followee excluded)

### Flutter track

- [X] T168 [P] [US13] Flutter domain/data: NEW `lib/features/reels/domain/entities/followed_user.dart` (Equatable — `id`/`username`/`name`/`avatarUrl`) + NEW `data/models/followed_user_model.dart` (tolerant parsing) + `getFollowingUsers` (cursor) through `reels_remote_datasource.dart` → `reels_repository.dart`/`reels_repository_impl.dart` (`Either<Failure, T>`)
- [X] T169 [US13] Flutter: NEW `presentation/bloc/capture_cubit.dart` — `idle → recording(elapsed, cap) → captured(path) | permissionDenied` (Cubit + Equatable + constructor DI); single continuous clip, timer-driven auto-stop at the 15s/60s cap, sub-1 s takes discarded back to `idle` with a notice, lifecycle pause stops recording safely (≥1 s segment → `captured`) (binding rule 13)
- [X] T170 [US13] Flutter: NEW `presentation/pages/reel_capture_screen.dart` + `widgets/record_button.dart` (red toggle + progress ring) + `widgets/capture_duration_selector.dart` (`Video | 15s | 60s`, disabled while recording) — full-screen `CameraPreview`, gallery thumbnail bottom-left (`image_picker.pickVideo`), flip + flash top-right only (flash hidden on the front camera), permission pre-flight via `permission_handler` rendering the explanation + open-settings state (FR-079/FR-080, R21); `WidgetsBindingObserver` + route-pop teardown of the `CameraController` (constitution V)
- [X] T171 [US13] Flutter: safe-path handoff + trimmer changes in `presentation/pages/reel_trimmer_screen.dart` — copy every capture/pick to `<appDocs>/reels_tmp/<uuid>.mp4` before the trimmer opens (R22 — `video_editor` 3.0.0 iOS space-path bug), `_maxDuration` const → `maxDuration` constructor param (capture cap for recordings, 60 s for gallery), CTA reads "Next" (`reels.trim_next`), back = discard confirmation → camera, `reels_tmp` purged on every flow exit (binding rules 14–15)
- [X] T172 [US13] Flutter: rebuild `presentation/pages/upload_reel_screen.dart` as the post-details step — description input (top-left) + selected-segment preview thumbnail (top-right) + prominent Post button (bottom); source-choice UI removed; `UploadCubit` submit/progress/error machine untouched (FR-082)
- [X] T173 [US13] Flutter: NEW `presentation/bloc/mention_suggestions_cubit.dart` (`hidden | loading | active(query, matches)`) + NEW `widgets/mention_suggestions_overlay.dart` — `OverlayPortal` + `CompositedTransformFollower` panel anchored above the description field; active-token regex on the text before the cursor; case-insensitive username/full-name filter over the once-per-visit-fetched following list; tap inserts `@username ` and collapses; collapses on space / `@` deletion / blur / route pop; empty or failed list = no overlay, typing never blocked (FR-083, R23, binding rule 16)
- [X] T174 [US13] Flutter: routing + entry swap — `/reels/capture` route in `core/routing/app_router.dart` (declared with the other static 2-segment reels paths, before `/reels/:id`); the Reels top-bar "+" entry navigates to capture; flow wiring capture → trimmer → post-details (`/reels/upload`) with route-scoped cubit/controller disposal
- [X] T175 [P] [US13] Flutter tests — `capture_cubit_test.dart` (auto-stop at cap, sub-second discard, permission-denied state, lifecycle stop), `mention_suggestions_cubit_test.dart` (token filter / insert / dismiss, failed-fetch silence), widget tests: `mention_suggestions_overlay_test.dart` (filter + insert + keyboard-safe anchoring), trimmer `maxDuration` bound test, post-details renders exactly description/preview/Post

**Checkpoint**: US13 fully demoable per quickstart §15 (device-only items deferred to T178).

---

## Phase 8: Polish & Cross-Cutting (v5)

- [X] T176 [P] `dart run build_runner build --delete-conflicting-outputs` (new injectables registered) + `flutter analyze` — zero new issues project-wide (pre-existing lints tolerated, zero diff)
- [X] T177 Full regression — backend: reels unit suite 58/58 green (56 pre-v5 + 2 new `getFollowingUsers` tests, T166/T167); reels e2e suite **could not run this session** — `mongodb-memory-server` cannot download its MongoDB binary in this sandbox (no network access), confirmed environment-wide by an untouched, pre-existing e2e test timing out identically; the new `followed-users list` e2e block (T167) is written and typechecks cleanly but is unverified against a live/in-memory Mongo — flag for the T178 device/CI session. Full backend unit suite (excl. e2e): 181 passed, 39 failed across 4 suites (video/chat/auth/status) — **zero diff**, same four modules the v4 regression already documented as pre-existing, confirmed untouched this session. Flutter: reels suite 90/90 green (61 pre-v5 + 29 new — capture_cubit 11, mention_suggestions_cubit 7, mention_suggestions_overlay 6, reel_trimmer_screen 3, upload_reel_screen 2); full project suite 197/208 passed — 11 failures all in `test/features/map/` (network-image fetch, no real network access in this sandbox), zero diff, unrelated to reels; `flutter analyze` zero new issues (T176). One implementation-time fix found by testing: `mention_suggestions_overlay.dart`'s panel was anchored *above* the field per R23's original wording, which pushed it off-screen given FR-082 places the description field near the screen top — corrected to anchor *below* (research.md/plan.md updated to match).
- [ ] T178 **Consolidated manual on-device walkthrough** — supersedes and absorbs the outstanding **T136 (v3)** and **T162 (v4)**; requires a real device (camera + mic) and two accounts:
  - **v5 (quickstart §15)**: capture-screen exactness vs `images_ui/camera_preview_ui.jpeg`; 15s auto-stop → straight to trimmer; permission-denial explanation state; flip/flash (flash hidden on front); trimmer `maxDuration` bounds + "Next"; iOS space-path gallery regression; post-details minimalism vs `images_ui/final_step_ui.jpeg`; `@` overlay ≤300 ms filter/insert; submit → "Processing"; abandon → no phantom reel, `reels_tmp` empty
  - **v5 bug-fix regressions (2026-07-07)**: (B1) record button flips to the recording shape immediately on tap, and a fast double-tap at start never crashes or double-starts; (B2) tap-record-then-immediately-stop (very short clip) does not crash — the platform stop is padded to a safe minimum and the clip still discards as "too short"; (B3) tapping "Next" goes straight from the trimmer's export-loading to the post screen with **no camera-screen flash**, and back-out from post returns to the trimmer (not the camera)
  - **v3 backlog (T136, §12)**: upload → trim → moderation (stub + Sightengine) → badges/push → delete; Redis-down fail-closed recovery against the real BullMQ worker
  - **v4 backlog (T162, §13–§14)**: report → auto-hide → admin restore/reject with the real `x-admin-key`; action-column layout on a real screen size; Following ↔ For You audio/timing bounds; repost badge legibility over bright video
  - **Performance gates**: v1 gates + v4 gates + **v5**: SC-024 (camera ≤2 s, record feedback ≤200 ms), SC-025 (auto-stop ±0.5 s, zero >60 s uploads), SC-026 (overlay ≤300 ms, no input lag), SC-027 (≤5-tap flow)

---

## Dependencies

- **T137 (ERD approval) gates all backend tasks** (T140–T146, T150–T154). Flutter i18n/domain scaffolding (T139, T142) may proceed in parallel with the gate at the team's risk.
- Phase 2 (T140–T142) blocks both story phases.
- **US11** (T143–T149) and **US12** (T150–T159) are independent of each other after Phase 2 — either can ship alone. Suggested order: US11 first (P11 priority; safety feature), US12 second.
- Within US11: T143 → T144 (service before admin ops on the same files) → T146; T145/T147/T149 parallel-friendly; T148 depends on T147.
- Within US12: T150 → T151 → T152 (same controller/service/repo files, escalating merge complexity) → T154; T153/T155/T159 parallel-friendly; T156–T158 depend on T155; T158 depends on T152's cursor contract (R20) being frozen.
- Phase 5 last (within v4).
- **v5**: T163 (FR-056 ack) gates the backend tasks (T166–T167); T164/T165/T168 may proceed in parallel with the gate at the team's risk. T164 → T169 → T170 → T174 (capture chain); T165 → T171/T172 (i18n keys used by trimmer/post-details); T168 + T172 → T173 (the overlay lives on the post-details screen and needs the data layer); T174 depends on T170–T172 (wires the full flow). T167/T175 parallel-friendly as their targets land. Phase 8 last; **T178 replaces T136 + T162 — run it, not them**.

## Parallel example (after T137 + Phase 2)

```
Backend dev:  T143 → T144 → T146        (US11 pipeline)
Backend dev2: T150 → T151 → T152 → T154 (US12 pipeline — different service methods, coordinate on reels.service.ts merges)
Flutter dev:  T147 + T148 (US11 UI)  ∥  T155 → T156/T157/T158 (US12 UI)
Tests:        T145, T149, T153, T159 as their targets land
```

## Implementation strategy

**MVP**: Phase 1 + Phase 2 + US11 (T137–T149) — community reporting with auto-hide is the safety-critical half and independently valuable. US12 (repost + tabs) follows as the second increment. Each checkpoint above is a demoable, regression-tested state.

**v5**: single-story increment — Phases 6–7 (T163–T175) deliver US13 end-to-end; Phase 8 closes with the consolidated regression (T176–T177) and the device walkthrough (T178) that also clears the T136/T162 backlog. Suggested MVP within v5 if needed: capture → trimmer → post-details on the existing submit path (T164, T169–T172, T174) ships without mentions; T166–T168 + T173 add the mention overlay as the second slice.

### Parallel example (v5, after T163)

```
Backend dev:  T166 → T167
Flutter dev:  T164 → T169 → T170 → T174
Flutter dev2: T165 → T171 → T172 → T173   (T168 first, in parallel with T165)
Tests:        T167, T175 as their targets land
```

---

## Carried-over technical debt (from v1–v3, still open)

- [ ] T070 backend/Flutter: `GlobalResponseInterceptor` (`chat-app-backend/src/main.ts`) wraps every controller response as `{ success, message, data }`, but `StatusRemoteDataSource` (`lib/features/status/data/datasources/status_remote_data_source.dart`, methods `getFeed`, `getViewers`, `getReactions`, `getDefaultAudience`) casts `response.data` directly `as List<dynamic>` without unwrapping the envelope. If these `/status/...` routes pass through the interceptor, that cast throws a `TypeError` at runtime. Needs verification against a live backend + fix — unrelated to Reels; flagged with inline `TODO`s at call sites.
- [ ] T136 (v3): manual on-device quickstart walkthrough for US10 (upload → trim → moderation → badge/push → delete; `video_editor`/`ffmpeg_kit_flutter_new` on both platforms; Redis-down fail-closed recovery against the real BullMQ worker; v1 performance gates after the top-bar "+"). Never run — no simulator/device was available in the v3 session. ~~Fold into T162's device session.~~ **Superseded 2026-07-06: folded, together with T162, into T178 (v5 consolidated device walkthrough) — run T178, not this.**
- **Pre-existing schema-typing quirk** (v3 note, unchanged): every `@Prop({ type: Types.ObjectId })` field in the reels module resolves to Mongoose `Mixed` under `mongoose@^9.4.1` + `@nestjs/mongoose@^11.0.4`, so automatic string→ObjectId casting does not apply — always pass real `Types.ObjectId` instances (`toObjectId()` helper). T140's new schemas must follow this convention. Root-cause investigation remains out of scope.
- **Local dev Redis** (v3 note): `npm run docker:local:up` provisions Mongo + Redis; a stray Homebrew Redis from the v3 session may still be running locally.
