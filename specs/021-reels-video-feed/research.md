# Research: Reels / Short Videos Feed

**Feature**: `021-reels-video-feed` | **Date**: 2026-07-02 (R1–R8 from plan v1; R9–R14 added for the core-architecture v2 scope; R15–R19 added 2026-07-03 for the upload + content-moderation v3 scope)

> **Supersession note (v2)**: R4's in-memory `ReelsMockStore` decision is **superseded by R9** (clarified: real database this phase). R4's module layout, controller paths, guard usage, and repository-interface decisions remain valid — only the storage binding changes.

## R1. Video playback engine: `media_kit` (stakeholder mandate)

**Decision**: Use `media_kit` (+ `media_kit_video`, `media_kit_libs_video`) for all reels playback. Do NOT use `video_player` for this feature.

**Rationale**:
- Stakeholder hard constraint: hardware-accelerated, high-performance playback.
- `media_kit` is backed by libmpv: hardware decode by default, precise buffer control (`bufferSize`), and `Player.open(media, play: false)` performs real network pre-buffering without rendering — exactly what the N+1 preload needs.
- Fully asynchronous initialization: `Player()` construction is cheap; `open()` returns a `Future` and buffering happens on native threads, never on the Dart UI thread. `VideoController` attaches to a GPU texture, so swiping stays on the raster thread at native refresh rate.
- Existing constitution rule VIII-C (`DefaultCacheManager().getSingleFile` → `VideoPlayerController.file`) exists to prevent re-downloading with `video_player`; it is scoped to chat media bubbles. Reels streams (progressive playback of feed content) cannot wait for a full file download, so that rule does not transfer. Deviation recorded in plan Complexity Tracking.

**Setup facts**:
- `MediaKit.ensureInitialized()` must run in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
- One `Player` + one `VideoController` per prepared reel; `player.dispose()` is async and releases the native decoder.
- Configure `PlayerConfiguration(bufferSize: 8 * 1024 * 1024)` (≈ first seconds of a short video) to cap per-player memory.

**Alternatives considered**:
- `video_player` (already in pubspec): rejected — stakeholder explicitly forbade it; weaker buffer control; ExoPlayer/AVPlayer instance churn causes jank on rapid swipes.
- `better_player` / `chewie`: wrappers over `video_player`; same rejection.

## R2. Sliding window: 3 controllers max + N+2 network prefetch

**Problem**: Two stakeholder constraints appear to conflict — "pre-buffer N+1 **and N+2**" vs "maximum of **3** active controllers (Current, Next, Previous)".

**Decision**: Two-tier preparation, reconciling both:
- **Tier 1 — Player window (max 3 controllers)**: `{N-1, N, N+1}` hold live `Player` instances. `N` plays; `N-1`/`N+1` are opened with `play: false` (buffered, paused at frame 0). Anything leaving the window is disposed immediately.
- **Tier 2 — Network prefetch (no controller)**: `N+2` gets an HTTP range request for its first ~1 MB via `DefaultCacheManager` (`downloadFile` with range headers / partial fetch helper). When the user swipes and `N+2` becomes `N+1`, its `Player.open()` is served partly from warm HTTP cache and the OS socket cache, so promotion to a live controller is near-instant.

A `ReelsPlayerPool` class (data-source-level service, injected into the feed bloc) owns the window: `syncWindow(currentIndex, reels)` computes the target set, disposes evictees first (fire-and-forget `unawaited(player.dispose())` so disposal never blocks a frame), then creates/promotes members. Disposal of a `Player` happens off the UI thread inside libmpv; Dart-side we only drop references — no GC-visible pause.

**Rationale**: Satisfies the 3-controller memory cap and the N+2 pre-buffer requirement simultaneously; memory stays bounded at ~3 × bufferSize + 1 MB prefetch regardless of session length (FR-013, SC-003).

**Alternatives considered**:
- 4 live players (N-1..N+2): rejected — violates the explicit 3-controller cap; decoder instances are the expensive resource on low-end Android.
- No N+2 prefetch: rejected — violates the explicit N+2 pre-buffer constraint; fast swipes would hit cold starts.

## R3. State management split (stakeholder mandate refined)

**Decision**:
- **`ReelsFeedBloc`** (a `Bloc`): pagination (cursor-based), page-change events, sliding-window orchestration via `ReelsPlayerPool`. Events: `ReelsFeedStarted`, `ReelsPageChanged(index)`, `ReelsNextPageRequested`, `ReelsRefreshRequested`, `ReelsItemRetryRequested(index)`. Uses `droppable()` transformer on pagination (concurrent fetches forbidden) — this stream-transformation need is why a full Bloc is used instead of the constitution-preferred Cubit (justified in Complexity Tracking).
- **`ReelsInteractionCubit`**: optimistic like/comment-count/follow state, keyed by id: `Map<String, LikeState>` + `Map<String, FollowState>` (follow keyed by **creatorId** so overlay and profile stay consistent — FR-030). Emits `Equatable` states; failures revert the optimistic entry (FR-037).
- **`CommentsCubit`**: per-bottom-sheet, created on open, closed with the sheet — fetch list, post comment.
- **`CreatorProfileCubit`**: profile + video grid loading.

**UI granularity rules** (FR-014, SC-006):
- The `PageView.builder` `itemBuilder` returns a `ReelPage` widget that is `const`-constructible from the reel entity; the video surface (`Video(controller: ...)`) is NOT wrapped in any BlocBuilder.
- Every dynamic element is its own leaf widget with `BlocSelector` selecting one value: `_LoveButton` (`BlocSelector<ReelsInteractionCubit, _, LikeState>` for that reel id), `_CommentCount`, `_FollowButton` (selects by creatorId), `_BufferIndicator` (listens to `player.stream.buffering`, a native stream — no bloc at all), `_PlayPauseOverlay` (listens to `player.stream.playing`).
- Tapping Love therefore rebuilds exactly one ~48px icon widget; the video texture repaints independently on the raster thread.

**Rationale**: Matches the stakeholder's `ReelsFeedBloc` / `ReelsInteractionBloc (or separate Cubits)` instruction, the constitution's Cubit preference (Cubits everywhere a Bloc isn't strictly needed), and the zero-rebuild-of-player requirement. media_kit's own `player.stream.*` streams let playback-state UI bypass bloc entirely — the most granular possible rebuild.

**Alternatives considered**:
- One combined ReelsBloc: rejected — a like toggle would emit feed state, risking PageView-scope rebuilds (explicitly forbidden).
- Per-reel Cubit instances for likes: rejected — churn of bloc instances during fast swipes; id-keyed maps in one long-lived cubit are cheaper and survive window disposal.

## R4. Backend reality: NestJS, not plain Express

**Finding**: The "Node.js & Express" backend is actually a **NestJS** app (`@nestjs/platform-express`, so Express under the hood) with Mongoose, `JwtAuthGuard` in `src/common/guards/`, and module-per-feature layout under `src/modules/`. There is **no global `/api` prefix** (existing routes: `/status/feed`, `/users/...`).

**Decision**: Implement a new self-contained **`reels` module** (`src/modules/reels/`) following the existing NestJS conventions:
- `ReelsController` with `@Controller('api/reels')` and `ReelsUsersController` with `@Controller('api/users')` — honoring the stakeholder's exact endpoint paths without introducing a global prefix (which would break every existing client route).
- `@UseGuards(JwtAuthGuard)` on both controllers; `req.user.userId` identifies the caller (same pattern as `StatusController`).
- **Mock relational data layer**: `ReelsMockStore` — an injectable provider holding in-memory arrays (`users`, `videos`, `likes`, `comments`, `follows`) with foreign-key-style references and helper query methods (joins, counts). It implements a `ReelsRepository` interface so a Mongoose implementation can replace it later without touching service/controller code (FR-033).
- Seed data generated at module init: ~8 mock creators (reusing real user ids where possible), ~40 videos pointing exclusively at publicly hosted sample MP4s (clarified — no backend-hosted video assets in v1), seeded likes/comments/shares/follows.
- Main feed pagination loops the catalog when exhausted (namespaced cycle cursor, `nextCursor` never null); creator-scoped feed stays finite (clarified).

**Rationale**: "Express endpoints" are delivered (NestJS routes ARE Express routes); consistency with the existing codebase beats introducing a parallel raw-Express app. Repository-interface + in-memory store fulfills "relational mock data laying the ground for real DB integration".

**Alternatives considered**:
- Raw Express router mounted in `main.ts`: rejected — bypasses guards, DI, validation pipes; inconsistent with every other module.
- Extending the existing `users` module for profile/follow: rejected for v1 — mock store must stay self-contained; `api/users/...` paths keep the public contract right while implementation lives in the reels module.

## R5. API contract details

**Decision** (full schemas in `contracts/reels-api.md`):
- `GET /api/reels?cursor=<id>&limit=10` — cursor pagination (stable under prepends, standard for infinite feeds), returns `{ items: ReelDto[], nextCursor: string|null }`. Each `ReelDto` embeds creator summary + counts + `viewer` flags (`liked`, `following`) so the first frame renders with zero extra requests.
- `POST /api/reels/:id/like` — toggles; returns `{ liked, likesCount }` (idempotent-by-state, safe under rapid taps — last response wins).
- `GET /api/reels/:id/comments?cursor&limit` / `POST /api/reels/:id/comments { text }` — returns comment page / created `CommentDto` + new `commentsCount`.
- `GET /api/users/:id/profile` — `{ user: {id, name, avatarUrl, bio}, stats: {followers, following, totalLikes}, videos: ReelThumbDto[], viewer: {following, isSelf} }`.
- `POST /api/users/:id/follow` — toggles; returns `{ following, followersCount }`; `400` on self-follow (FR-031).
- Video/thumbnail URLs may be relative → Flutter resolves via `UrlUtils.resolveMediaUrl` (constitution VIII-A).

## R6. Flutter-side supporting choices

| Concern | Decision | Rationale / Alternative rejected |
|---|---|---|
| Share flow (clarified, then expanded 2nd update) | Custom `showModalBottomSheet`, two rows. Top: horizontal scrollable recent chats (circular avatar + name) from the existing chat repository, capped ~10, one tap sends the reel's deep link as a normal text chat message. Bottom: prominent Copy Link (`Clipboard.setData` + confirmation) then a single "Share via…" opening the OS share sheet via `share_plus` (clarified — no per-app branded icons). In-app send transmits a **reel-share message subtype** (clarified): existing chat send pipeline with `type: 'reelShare'` + metadata `{reelId, thumbnailUrl, creatorName, deepLink}`, rendered in chat as a rich preview card (thumbnail + creator name + play badge) that navigates to `/reels/:id` on tap. `POST /api/reels/:id/share` fired only on in-app send or Copy Link; sheet content composed from already-cached chat data so it renders instantly without touching the video | Per-app scheme integrations rejected by clarification; plain-text link bubble rejected by clarification — stakeholder chose the rich card |
| Compact counters (1.2K) | `intl` `NumberFormat.compact()` — already a dependency | Hand-rolled formatter rejected; intl handles locales |
| Reels tab UX (clarified) | New tab inserted after Calls (index 4 of 6; Calls retained per clarification — original "replace Calls" superseded). Tab renders `ReelsFeedScreen` as body; nav bar stays visible, dark-themed while on Reels (user-confirmed). Creator-grid taps push a full-screen `/reels/creator/:id?start=<videoId>` go_router route | Replacing the Calls tab rejected by stakeholder clarification; immersive nav-hiding rejected — one-tap tab escape kept |
| Tab visibility → playback stop (FR-004) | `ReelsFeedScreen` gets `onVisibilityChanged` from the parent tab switch (`_currentIndex != 3` → `ReelsFeedPaused` event) + `WidgetsBindingObserver` for app lifecycle + `RouteAware` for pushed routes | Relying only on `dispose()` rejected: `IndexedStack`-like tab bodies may keep state alive |
| Comment sheet | `showModalBottomSheet(isScrollControlled: true)` + `DraggableScrollableSheet`; video keeps playing behind (FR-019) | Full comments screen rejected — spec demands lightweight sheet |
| Micro-animation on Love | Implicit `AnimatedScale`/`TweenAnimationBuilder` inside `_LoveButton` only | Lottie/rive rejected — dependency weight for one icon |
| Localization | New keys (`nav_reels`, `reels_*`) in `assets/translations/*.json` via easy_localization, matching `nav_calls` pattern | Hardcoded strings violate existing i18n convention |
| Offline behavior | Network-only feed with explicit error/empty states + retry (FR-034); no sqflite persistence for reels v1 | Constitution offline-first deviation, justified in plan Complexity Tracking: ephemeral streamed media ≠ relational chat data; caching video bytes handled by HTTP cache/prefetch |
| Testing | `bloc_test` + `mocktail` for blocs/cubits (window math, optimistic revert); repository tests with mocked Dio; backend: Jest unit tests for `ReelsService` + e2e for the 5 endpoints | Widget-level FPS assertions rejected as flaky; SC-002 verified manually with DevTools performance overlay |

## R7. Deep linking (`https://ciro.chat/reels/:id`)

**Decision**: Use go_router's native deep-link handling (Flutter Router API receives OS-delivered links on cold and warm start — no extra package) plus platform configuration:
- **Route**: `/reels/:id` in `app_router.dart` → `ReelsFeedScreen(initialReelId: id)`. The same route serves in-app link taps from chat messages (URL launcher interception → internal `context.go`) — no browser round-trip (FR-042).
- **Android**: `intent-filter` with `android:autoVerify="true"` for `https://ciro.chat/reels` in `AndroidManifest.xml`; requires `assetlinks.json` hosted at `ciro.chat/.well-known/` (deployment dependency, out of app scope). Dev fallback: custom scheme `cirochat://reels/:id` in a second intent filter; test via `adb shell am start -a android.intent.action.VIEW -d "https://ciro.chat/reels/reel-1"`.
- **iOS**: Associated Domains entitlement `applinks:ciro.chat`; requires hosted `apple-app-site-association`. Dev fallback: `CFBundleURLTypes` custom scheme; test via `xcrun simctl openurl booted "https://ciro.chat/reels/reel-1"`.
- **Auth gating**: the existing go_router auth redirect keeps the target location; after login the router proceeds to `/reels/:id` (FR-043) — verify the current redirect preserves `state.uri`.
- **Feed seeding**: `ReelsFeedBloc` accepts `initialReelId`; it fetches `GET /api/reels/:id` (skeleton shown — shimmer placeholder widget, FR-041), inserts the reel at index 0, then paginates the regular feed behind it. Unknown id / fetch failure → friendly error + fall back to normal feed start.
- **Link generation**: `Reel.deepLinkUrl` derived client-side from a single constant (`ReelsConstants.deepLinkBase + id`); base configurable via `.env` like `API_URL` (constitution VIII-B analog), so no backend field is needed.
- **App-not-installed fallback (clarified)**: the backend serves an unauthenticated `GET /reels/:id` HTML page that user-agent-sniffs and redirects iOS → App Store, Android → Google Play, other → basic page with both store links. Store URLs are env config (placeholders until published). The production domain must route `/reels/:id` browser traffic to the backend.
- **Tab return (clarified)**: `ReelsFeedBloc` + `ReelsPlayerPool` live for the app session (not per tab visit); leaving the tab pauses, returning resumes the same index (FR-004a). Fresh feed only on app restart or explicit refresh.

**Alternatives considered**: `app_links`/`uni_links` packages rejected as redundant — the Flutter engine already forwards app/universal links to the Router; a package would only add a parallel stream to reconcile. Firebase Dynamic Links rejected — deprecated by Google.

## R8. Performance verification plan (SC-001, SC-002, SC-006)

- Run with `flutter run --profile` + Performance Overlay; swipe 50 videos; assert no raster/UI thread bars exceed frame budget.
- DevTools timeline: confirm no `Player.open`/`dispose` work appears on the UI thread event lane.
- Memory: DevTools memory view across 100-video session — flat native + Dart heap after window stabilizes (3 players).
- Like-tap rebuild scope: Flutter Inspector "Track widget rebuilds" — only `_LoveButton` subtree rebuilds.

---

# v2 research (core backend architecture, own profile, search, notifications)

## R9. Real database: Mongoose/MongoDB behind the existing `ReelsRepository` (supersedes R4 storage)

**Decision**: Implement `reels-db.repository.ts` (Mongoose) as the `ReelsRepository` binding; retire `ReelsMockStore`. New collections: `reels`, `reel_likes`, `reel_saves`, `reel_views`, `reel_shares`, `reel_comments`, `follows`, `notification_events`. Extend the existing `users` collection (see R10). Seed idempotently at boot (`reels-seed.service.ts`, guarded by a count check) with ~8 demo creators and ~40 reels on public sample MP4 URLs (unchanged from v1 clarification).

**Rationale**:
- Clarified stakeholder decision: real DB this phase, seeded with demo content.
- The backend already runs MongoDB via `@nestjs/mongoose` + `mongoose` 9 for every other module (users, chat, status) — introducing any other engine would be gratuitous.
- The v1 repository interface was designed for exactly this swap (FR-033): controllers/service and the public API contract do not change; existing Flutter code keeps working.
- **Counter strategy (FR-055)**: denormalized counter fields (`likesCount`, `commentsCount`, `sharesCount`, `viewsCount` on reels; `followersCount`, `followingCount`, `totalLikes` on users) updated with atomic `$inc` in the same repository method as the relation write. Toggle direction derives from the relation-write result (`upsertedCount`/`deletedCount` of the unique-indexed relation doc), so rapid double-taps cannot drift counters. Multi-document consistency (e.g., like → reel.likesCount + creator.totalLikes) uses ordered sequential writes; MongoDB transactions rejected for v1 (local docker Mongo is standalone, not a replica set — transactions unavailable; drift risk is accepted and self-healing on next toggle).
- Cursor pagination maps to `_id`-based `$lt` cursors (`createdAt` desc, `_id` tiebreak); main-feed catalog looping keeps the namespaced `cycleN:` cursor scheme from v1.

**Alternatives considered**: keeping the mock store with a "design-only" ERD — rejected by clarification. PostgreSQL/Prisma — rejected: second database engine in a Mongo codebase. `mongoose-autopopulate`/aggregation-computed counts — rejected: violates FR-055 (no count scans on read).

## R10. Shared identity & blocking: extend `users`, reuse `blockedUsers`

**Finding**: The existing `User` schema already has `name`, `avatarUrl` (present on documents and projected in `users.repository.ts`), and — critically — `blockedUsers: ObjectId[]`. It lacks `username`, `bio`, and the counter fields. No REST endpoint writes `blockedUsers` today (only reads in `users.service.ts`).

**Decision**:
- Add to `user.schema.ts`: `username` (string, `unique: true, sparse: true`, lowercase, auto-generated from `name` + discriminator during seed/backfill), `bio` (string, default ''), `followersCount`/`followingCount`/`totalLikes` (number, default 0).
- Blocking reuses `User.blockedUsers` as the single source of truth (clarified: chat and Reels share one identity and one block list). New `POST /api/users/:id/block` toggle endpoint (in `reels-users.controller.ts`) `$addToSet`/`$pull`s the caller's array; self-block → 400.
- **Mutual exclusion query**: per request, `blockSet = caller.blockedUsers ∪ reverseBlocks(callerId)`; reverse lookup served by an index on `blockedUsers` (multikey). All reels reads filter `creatorId ∉ blockSet` (and comment lists filter authors); single-reel/profile fetches for blocked parties return 404 so deep links follow the unknown-reel path (FR-053).

**Alternatives considered**: separate `reels_blocks` collection — rejected: two block lists diverge and the spec says chat/Reels share blocking. Separate ReelsProfile collection 1:1 with users — rejected by clarification (option A chosen).

## R11. Descriptions, hashtags, mentions, and search

**Decision**:
- `reels.description` (string ≤ 2200 chars); parsed **at write time** into `hashtags: string[]` (lowercased, `#` stripped, deduped, multikey index) and `mentions: [{ userId, username }]` (only `@username`s that resolve to existing users; unresolved stay plain text — FR-047). Parsing lives in `reels.service.ts` (shared by seeder and the future upload path).
- **Search** (FR-057): two parallel endpoints — `GET /api/reels/search?q=` (matches any element of `hashtags` by case-insensitive escaped-substring regex) and `GET /api/users/search?q=` (matches `username` or `name` the same way). Substring regexes can't use the B-tree beyond prefix anchoring; **accepted for v1 scale** (seeded catalog + early real data), documented as the first thing to revisit (Atlas Search / text index) when data grows. Both endpoints block-filter (R10) and paginate.
- **Hashtag feed** (FR-047a): `GET /api/reels?hashtag=<tag>` — reuses the feed endpoint exactly like `creatorId` does: finite, newest-first, `nextCursor: null` at end, exact-match on the indexed `hashtags` array (fast multikey equality, no regex).
- **Flutter rendering**: `reel_description.dart` builds a `RichText` with styled `TextSpan`s; `#tag`/`@mention` spans get `TapGestureRecognizer`s (mention → `/reels/creator/:userId`, hashtag → hashtag feed route). Recognizers are created in `initState`/`build`-memoized and **disposed in `dispose()`** (constitution V). Descriptions collapse to 2 lines with a "more" toggle — expanding rebuilds only the description leaf.
- **Search UX**: `SearchCubit` (Cubit, Equatable state `{status, videos, users, query}`) debounces 350 ms, cancels stale requests by query token, no-ops whitespace. Entry: search icon in the new Reels top bar; route `/reels/search`.

**Alternatives considered**: Mongo `$text` index — rejected: whole-word semantics, no substring. Client-side hashtag filtering — rejected: unbounded transfer + block-filter must be server-side. `flutter_linkify`-style packages — rejected: trivial to do with TextSpans, no dependency weight.

## R12. Views: dedup per user per reel

**Decision**: `reel_views` collection with unique compound index `(userId, videoId)`; `POST /api/reels/:id/view` performs insert-if-absent; only an actual insert `$inc`s `reels.viewsCount` (clarified default: one view per user per reel, counted at playback start). Response `{ viewsCount }`; duplicate calls return the current count unchanged. Flutter fires it once per reel per session (in-memory `Set<String>` guard in `ReelsInteractionCubit`) as fire-and-forget (`debugPrint` on failure — constitution VII silent-failure rule; a lost view never disrupts playback).

**Alternatives considered**: view on N-seconds-watched — rejected: spec default is playback start; watch-time analytics out of scope. Unlogged bulk counter — rejected: dedup requires the relation row, and "watched history" becomes free later.

## R13. Saves & liked lists; own-profile surface

**Decision**:
- `reel_saves` mirrors `reel_likes` exactly (unique `(userId, videoId)`, toggle + `$inc reels.savesCount`? — **no**: saves are private, no public counter (FR-049), so no counter field; just the relation + `viewer.saved` flag).
- `GET /api/reels/liked` and `GET /api/reels/saved` return standard `ReelDto` pages (newest-relation-first cursor on the relation collection, join to reels, block-filtered) — **declared before `:id` routes**.
- Overlay gains `save_button.dart` (bookmark icon) — `BlocSelector` on `ReelsInteractionCubit.saves[reelId]`, optimistic toggle + revert, identical pattern to Love (FR-049).
- **Own profile (US7/US8)**: the existing `CreatorProfileScreen` gains self-mode: when `viewer.isSelf`, render a `TabBar` (Videos | Liked | Saved) above the 3-column grid; Liked/Saved tabs lazy-fetch their endpoints. Follow button already hidden for self (v1 FR-031). The top-left avatar icon on the Reels screen (`reels_top_bar.dart`) navigates to `/reels/creator/<currentUserId>` — reusing the route, screen, and cubit; zero new navigation machinery. Current user id/avatar come from the existing auth session (`AuthCubit`/secure storage), avatar rendered with `CachedNetworkImage` + person-placeholder fallback (FR-044).

**Alternatives considered**: dedicated `/reels/me` screen — rejected: duplicates `CreatorProfileScreen`; tabs are conditional rendering. Persisting liked/saved lists to sqflite — rejected: same network-only deviation rationale as the feed.

## R14. Push notifications end-to-end (FCM) — reuse `NotificationsModule`

**Finding**: The backend already has `src/modules/notifications/` — `PushService` (firebase-admin initialised from `FIREBASE_SERVICE_ACCOUNT` env, `sendPush(token, {title, body, data})`) and `DeviceTokensRepository` (per-user token list). The Flutter app already runs `PushNotificationService` (FCM token registration, foreground/tap streams, constitution V-B teardown).

**Decision**:
- New `reels-notifications.service.ts` in the reels module, injected with `PushService` + `DeviceTokensRepository` + `notification_events` model. On qualifying action (follow ON, like ON, mention at reel creation): (1) insert `notification_events` row (durable record), (2) fan out `sendPush` to each of the recipient's tokens with localizable title/body and **data payload** `{ type: 'newFollower'|'reelLike'|'reelMention', reelId?, actorId }`. Skip when `actorId == recipientId` (FR-054). Unlike/unfollow never notifies; re-like after unlike does not re-notify (dedup: skip if an event row with same `(type, actorId, recipientId, reelId)` exists).
- Delivery failures are logged and swallowed (`PushService` already does this) — the event row still exists; SC-014's 10 s bound applies only when a reachable token exists.
- **Flutter**: extend the existing `PushNotificationService` tap handler routing: `reelLike`/`reelMention` → `/reels/:reelId`; `newFollower` → `/reels/creator/:actorId`. Cold-start taps go through the same go_router deep-link path as reel URLs (R7). No new packages; no notification-center UI (out of scope per Assumptions).

**Alternatives considered**: BullMQ queue for fan-out (already a dependency) — rejected for v1: token counts per user are tiny; inline async fan-out after response is sufficient; queue is the documented scale-up path. Socket-delivered in-app notifications — rejected: spec requires push, notification center out of scope.

---

# v3 research (upload + automated content moderation)

## R15. Moderation provider: Sightengine behind a `ModerationProvider` abstraction

**Decision**: Primary provider **Sightengine** (video moderation + text moderation endpoints), called from the background worker via plain REST (`@nestjs/axios`, already a dependency). Abstracted behind a `ModerationProvider` interface (`analyze(videoPath, description) → { verdict: 'clean'|'flagged', flaggedSource?: 'video'|'description', categories?: string[], providerRef?: string }`) with a **`stub` provider** for dev/tests (returns clean unless the filename or description contains a designated flag marker — makes e2e reject-paths testable offline). Selected via `MODERATION_PROVIDER` env (`sightengine` | `stub`); credentials `SIGHTENGINE_API_USER`/`SIGHTENGINE_API_SECRET`.

**Rationale**:
- **The deciding constraint is media location**: uploaded reels live on the backend's local disk (`uploads/reels/`, the app's existing static-serving pattern). AWS Rekognition's video API **requires the file in S3**; Google Video Intelligence prefers GCS (inline bytes are size-limited well below a 100 MB cap). Sightengine accepts a **direct multipart upload or a URL** — no cloud-bucket prerequisite, so the pipeline works in dev and prod without new storage infrastructure.
- One provider covers **both** modalities the clarified spec requires (video frames + description text) in the same integration.
- Short (≤60 s) videos fit Sightengine's synchronous/short-video flow; the worker gets a verdict in one round-trip in the common case, comfortably inside SC-018's 5-minute bound.
- The interface keeps FR-062's provider examples honest: swapping to Rekognition/Video Intelligence later means one new class plus the (then-required) cloud media storage, no pipeline changes.
- Default provider categories/thresholds (nudity, explicit/sexual content) are used as the flag boundary per the spec Assumption; category details are recorded in the moderation result for audit.

**Alternatives considered**: AWS Rekognition Content Moderation — rejected for v1: S3 prerequisite conflicts with local-disk media; strong candidate when CDN/S3 hosting lands. Google Video Intelligence (`EXPLICIT_CONTENT_DETECTION`) + Natural Language `moderateText` — rejected for v1: GCS preference/inline size limits, and two separate APIs for video vs text. Self-hosted NSFW models (open-source classifiers) — rejected: operational burden and accuracy liability for a compliance-critical path.

## R16. Flutter trim/record/pick pipeline (FR-060/FR-060a)

**Decision**:
- **Record**: `image_picker` (already in pubspec) `pickVideo(source: ImageSource.camera, maxDuration: Duration(seconds: 60))` — the OS camera enforces the cap natively; no trimming needed.
- **Pick**: `pickVideo(source: ImageSource.gallery)`; probe duration (media_kit `Player.open(play: false)` already available); ≤60 s → proceed directly, >60 s → **mandatory trimmer screen**.
- **Trimmer**: `video_editor` package for the WhatsApp-Status-style trim UI (draggable window over a thumbnail timeline, 60 s max window) with **`ffmpeg_kit_flutter_new`** (maintained fork of the discontinued `ffmpeg_kit_flutter`) executing the actual cut (`-ss/-to -c copy` stream copy when container allows, re-encode fallback). Exact package pins verified against pub.dev at implementation time (both are the de-facto standard pairing; noted as the one open verification).
- **Thumbnail**: extracted client-side in the same ffmpeg step (`-frames:v 1` at the trim start) and uploaded alongside the video — no server-side ffmpeg, consistent with the backend's zero-media-processing posture.
- **Upload**: `dio` `FormData` multipart with `onSendProgress` driving the `UploadCubit` progress state; `CancelToken` cancelled on route disposal (constitution V). Failure → explicit retry state; the backend guarantees no phantom reel (FR-060).

**Alternatives considered**: server-side trimming (upload full source + trim params) — rejected: full-length uploads fight the 100 MB cap and waste bandwidth; adds server ffmpeg. `video_trimmer` package — rejected: depends on the discontinued ffmpeg_kit line without the maintained fork. Platform-channel native trimmers (AVAssetExportSession / MediaCodec) — rejected: two custom native implementations for one screen.

## R17. Background job: BullMQ queue `reels-moderation` (fail-closed)

**Finding**: `@nestjs/bullmq`, `bullmq`, and `ioredis` are already dependencies and `BullModule` is already configured in `app.module.ts` (`REDIS_URL` in env) — the moderation worker rides existing infrastructure.

**Decision**:
- Queue `reels-moderation`, job payload `{ reelId }` only, `jobId: reelId` (dedup). The processor re-reads the reel doc — idempotent under retries; no-ops if the doc is gone (owner deleted it mid-review) or already decided.
- **Retry policy**: `attempts: 5`, exponential backoff from 30 s. Exhausted/failed jobs leave the reel `pending_moderation` (never fail-open); an on-boot + interval **sweep** re-enqueues any reel stuck in `pending_moderation` older than a threshold (also covers jobs lost to Redis restarts and uploads whose enqueue failed).
- **Transitions** (the worker is the only writer of `status`): clean → `status: 'published'`, `publishedAt: now`, then `notifyMentions` (existing T102 service — its designed live caller; the unique event index makes mention notifications exactly-once even across job retries). Flagged → `status: 'rejected'`, moderation result stored, `reelRejected` event + push (R18). Both transitions use a guarded update (`findOneAndUpdate` with `status: 'pending_moderation'` precondition) so a concurrent retry can't double-fire side effects.
- Missing/invalid provider credentials → processor logs a warning and fails the job (reel stays pending) — mirrors the existing `FIREBASE_SERVICE_ACCOUNT` degrade-with-warning pattern, but degrades **closed**, not open.

**Alternatives considered**: inline post-response processing (`setImmediate`, like the notification fan-out) — rejected: moderation involves an external API with retries measured in minutes; losing the process loses the job, and FR-066 demands durable retry. New dedicated worker process — rejected: BullMQ processors run in-process in Nest; a separate deployable is premature. Mongo-polling scheduler without a queue — rejected: reinvents BullMQ's retry/backoff/dedup poorly (though the sweep keeps a thin slice of it as a safety net).

## R18. Status machine enforcement + `reelRejected` notification

**Decision**:
- `reels.status` (enum string, default `'pending_moderation'`) + embedded `moderation` subdoc (`verdict`, `flaggedSource`, `categories[]`, `providerRef`, `completedAt`) — 1:1 lifecycle with the reel, no separate collection to join (the spec's Moderation Result entity, embedded).
- **Read enforcement in one place**: `reels.service.ts` composes `visibilityFilter(viewer)` = `status: 'published'` OR (`creatorId == viewer` — owner sees own reels of any status) and applies it alongside the existing `blockSet` filter on every read; engagement writes (like/comment/share/save/view) hard-require `published` → 404 otherwise (FR-064). Non-owner single-fetch of pending/rejected → 404 = the deep-link unknown-reel path (FR-061/FR-043).
- **Feed index**: `{ status: 1, createdAt: -1, _id: -1 }` replaces the plain createdAt feed index (equality-prefix keeps the cursor pattern intact); `{ creatorId: 1, status: 1, createdAt: -1 }` for grids. Seeder creates reels as `published`; a startup backfill sets missing `status` to `'published'` on pre-v3 docs (idempotent `updateMany`).
- **`reelRejected`**: new `notification_events.type`. System-originated — `actorId: null` (schema loosened to optional; the self-event skip applies only to actor-driven types). Dedup index unaffected (`reelId` uniqueness per type/recipient). Push payload `{ type: 'reelRejected', reelId }`; Flutter tap-routes to the own profile (`/reels/profile/<selfId>`), where the rejected reel is visible with its badge.
- **Owner UI states (FR-065)**: `ReelDto.status` is always present (harmless — non-published reels only ever reach their owner); own-profile grid thumbnails get a `reel_status_badge.dart` overlay (Processing spinner-badge / "Removed" badge with the policy-violation string), and the owner's reel view shows a banner. Localized keys in `en`/`ar` (`reels.status_processing`, `reels.status_removed`).

**Alternatives considered**: separate `moderation_results` collection — rejected: nothing queries results independently of their reel. `isPublished` boolean + `rejectedAt` — rejected: three explicit states are the spec's contract and leave room for none. Filtering client-side — forbidden by FR-061 (server-side only).

## R19. Deletion cascade (FR-067)

**Decision**: `DELETE /api/reels/:id` — owner-only (`403` otherwise, `404` unknown). Service-level cascade in this order: (1) `$inc` creator `totalLikes: -reel.likesCount`; (2) delete relation docs (`reel_likes`, `reel_saves`, `reel_views`, `reel_shares`, `reel_comments` by `videoId`); (3) delete reel-scoped `notification_events`; (4) delete the reel doc; (5) unlink media files (video + thumbnail, best-effort). Sequential writes, same no-transaction posture as R9 (standalone Mongo); the guarded final doc-delete makes retries safe. In-flight moderation jobs no-op on the missing doc (R17). Client: delete menu (confirmation dialog) on own-profile grid items and the owner reel view; on success the grid refreshes and, if the deleted reel was rejected, its badge disappears with it.

**Alternatives considered**: soft-delete flag for owner deletions — rejected: the spec's soft-delete applies to *rejected* media (retention for audit); an owner deletion is a right-to-remove and fully cascades. Keeping engagement rows for analytics — rejected: private data hygiene beats hypothetical analytics; the spec says lists/counters must update.
