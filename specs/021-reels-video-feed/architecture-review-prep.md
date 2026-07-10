# Reels — Architecture Review Prep

> Staff-engineer briefing for the technical architecture review with the Laravel backend team.
> Grounded in the actual code on both sides (NestJS backend + Flutter client), not the pitch framing.

---

## ⚠️ Read this first: brief vs. reality

The original brief describes a different architecture than the one that's actually built. If you assert the brief verbatim, a competent architect will dismantle it in two questions. Here's the truth.

| The brief says | The code actually does | Verdict |
|---|---|---|
| NestJS Reels **microservice**, independent from Laravel | **NestJS modular monolith** — `reels` is one module beside `auth`, `chat`, `users`, `payment`, `status` in **one** NestJS app | ❌ Reframe |
| **Multi-tenant**, `app_id` isolation via JWT claims / headers | Zero `app_id`/`tenant` anywhere (grepped clean). Single-tenant app | ❌ Not present |
| Cache `user_id, name, avatar_url` in Reels DB to avoid **sync HTTP calls to Laravel** | **Shared MongoDB.** Reels stores only `creatorId` (an ObjectId ref) and does a **read-time batch join** on the shared `User` collection | ❌ Reframe |
| **Eventual consistency** via **webhooks/events** for user updates | **Strong consistency** — no copy, no webhook, no sync job. Name/avatar changes are live instantly | ❌ Not present |
| Client **+** server FFmpeg, `+faststart`, defense-in-depth remux | Both exist and are real | ✅ Accurate |
| Sightengine AI, 25-report auto-hide, `pending`/`hidden` states, daily rate limits | All real | ✅ Accurate |
| Zero-latency playback via N+1/N+2 pre-caching | Real (3 live players + 1MB range-warm on N+2) | ✅ Accurate (nuance below) |

**How to position it honestly and still look strong:** Don't claim microservices/multi-tenancy you don't have. Claim a **modular monolith with strict module boundaries** and a **clean-architecture Flutter client**, and say the seams are drawn so reels *can* be extracted into a service later (the repository pattern + provider abstractions make that a refactor, not a rewrite). That's a defensible senior story. Claiming a distributed system you can't diagram is the trap.

---

## Pillar 1 — System Architecture (the real one)

**What it is:** A single **NestJS 11** (Express) application, MongoDB via Mongoose, Redis for queues. The `reels` module is internally layered:

- **Controller** (`reels.controller.ts`) — HTTP, Multer disk-storage upload, route ordering (static routes above `:id`).
- **Service** (`reels.service.ts`) — orchestration, block-set computation, notifications.
- **Repository** (`reels-db.repository.ts`, behind a `REELS_REPOSITORY` DI token) — all Mongo access.
- **Provider abstractions** — `ModerationProvider` interface with `sightengine` + `stub` implementations.

**Identity:** A shared JWT (`JwtAuthGuard` → Passport `jwt` strategy) protects the whole controller; `req.user.userId` is the caller. Same auth as the rest of the app — not a per-service token, not a tenant claim.

**The "why" to say in the meeting:**
- *Why a modular monolith?* One deploy, one datastore, transactional simplicity, no network hop or eventual-consistency tax for a feature that's read-heavy and identity-coupled. The module boundary (repository token + provider interfaces) means extraction to a service is a later, mechanical step if scale demands it.
- *Why the repository behind a DI token?* It's the extraction seam — swap the Mongo repo for an HTTP client and the service layer doesn't change. **This is your microservice-readiness argument, and it's honest.**

If they ask "how would reels talk to a Laravel core?" — today it shares the datastore; the boundary that would become a REST/gRPC contract is the `ReelsRepository` interface, and identity would move from a shared JWT to a validated cross-service token.

---

## Pillar 2 — Data & Identity (strong consistency, not eventual)

The reel document stores **only** `creatorId`. On every feed read, the repository collects the page's creator IDs and does one batched lookup on the shared collection:

```
.find({ _id: { $in: creatorIds } }).select('_id name username avatarUrl')
```

then stitches `{ name, username, avatarUrl }` onto each reel (missing → `'Unknown'`). Mentions are resolved to real users at write time and stored as `{userId, username}` subdocs.

**The "why" — and it's a *better* story than the brief's:**
- *Why no denormalized copy / no webhooks?* It's one database — there are no cross-service HTTP calls to avoid in the first place. A read-time join gives **strong consistency for free**: a user renames or changes their avatar and every reel reflects it on the next read, with **zero sync lag, zero webhook to fail, zero stale-avatar bug.** The brief's "eventual consistency" would be *more* complex and *worse* here.
- *When would you flip to the brief's model?* Only after extracting reels into its own service/DB — then you'd denormalize a user snapshot and sync via events, trading consistency for decoupling. Say that explicitly; it shows you understand the tradeoff rather than cargo-culting it.

**Sharing / deep links:** reels are shared by `reelId` deep link (there's a redirect controller). A share is recorded as a lightweight `reel_shares` relation + counter — it does **not** touch the social graph (follows/blocks). This part of the brief *is* accurate: sharing is a content-addressed link, not a social-graph operation.

**Blocking** is enforced server-side on every read via a **mutual block set**: your `blockedUsers` **∪** everyone who blocked you (reverse index lookup), applied as a `$nin` creator filter — never trusted to the client.

---

## Pillar 3 — Upload & Video Pipeline (strongest, fully accurate pillar)

**Flutter camera-first flow:** custom in-app `camera` capture → `Video|15s|30s|60s` cap with timer auto-stop → every source (capture *or* gallery) is copied to a **space-free temp path** (`reels_tmp/<uuid>.mp4`, working around a real `video_editor` 3.0.0 iOS bug, OSStatus -17913) → trimmer with "Next" → post-details (description + mention autocomplete) → `dio` multipart upload with progress + `CancelToken`.

**Client-side FFmpeg** (`reel_video_export.dart`) runs the *same* normalize on trimmed and untrimmed clips:

```
-c:v libx264 -preset veryfast -crf 28 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart
scale='min(720,iw)':-2
```

- **`+faststart`** relocates the MP4 `moov` atom to the front so a progressively-downloaded clip can start decoding before the tail arrives (without it: brutal first-play stutter that vanishes once cached).
- **≤720px + CRF 28** caps resolution/bitrate so a heavy source can't outrun the player's buffer on first pass — and shrinks upload bandwidth.
- Client normalize failing **never blocks posting** — it falls back to the raw file, because…

**Server-side defense-in-depth** (`reels.controller.ts`) — real, worth emphasizing:

1. **Independent duration enforcement (never trust the client):** it walks the MP4 ISO-BMFF boxes directly (`moov`→`mvhd`, pure JS, reads only header slices) to read duration, with `music-metadata` as a fallback for WebM/wav. >61s → 400. It **hand-rolls the atom parse** specifically because `music-metadata` reports `undefined` for video-only clips (a muted screen recording) and would wrongly reject them.
2. **`remuxFaststart`** — a lossless `-c copy -movflags +faststart` remux via `@ffmpeg-installer/ffmpeg`, so *any* path that skipped client normalization (old build, direct API call) still gets a faststart file. Best-effort: on failure it serves the original rather than failing the upload.
3. **No partial reel** — any failure `unlink`s the uploaded files in a catch.

**Why say this:** the pipeline is *fail-open for the user, fail-safe for the platform* — the user can always post, but the server independently guarantees the duration cap and the faststart layout regardless of client behavior. Textbook defense-in-depth.

---

## Pillar 4 — Moderation & Reporting (accurate)

**AI moderation (Sightengine, async):** upload creates the reel as `pending_moderation` and returns immediately — the response **never waits on the verdict**. A **BullMQ** job (`jobId = reelId`, 5 attempts, exponential backoff from 30s) calls the `ModerationProvider`:

- **Video:** `video/check-sync.json` with models `nudity-2.1,offensive-2.0`, flagged at prob ≥ 0.5.
- **Text (description):** `text/check.json` with `nudity_sexual_content`.
- **Clean →** `published` + fires `notifyMentions` (mentions notify **exactly once, at publish** — never at upload). **Flagged →** `rejected` + soft-delete + `reelRejected` push.

**Fail-closed is the headline:** the *only* path to `published` is an explicit clean verdict. Provider error/timeout → throw → BullMQ retry; exhausted jobs **stay pending** (a boot/interval sweep re-enqueues). Missing credentials → jobs wait, never auto-publish. Redis down at enqueue → upload still succeeds, reel stays pending, sweep recovers it.

**Community moderation state machine** — four statuses, **exactly three status writers**, each a guarded `findOneAndUpdate`:

| Writer | Transition |
|---|---|
| Moderation worker | `pending → published \| rejected` |
| Report service | `published → hidden` (at threshold) |
| Admin endpoint | `hidden → published \| rejected` |

- **25-report auto-hide** (`REEL_REPORT_AUTOHIDE_THRESHOLD`, default 25): unique `{videoId, reporterId}` index makes duplicate reports idempotent; the `$inc` that crosses the threshold fires `findOneAndUpdate({_id, status:'published', adminRestored:{$ne:true}}, {status:'hidden'})` — concurrent boundary reports race harmlessly (one wins).
- **Daily rate limit** (`REEL_REPORT_DAILY_LIMIT`, default 20): checked before insert → `429`, records nothing.
- **`adminRestored`** = permanent auto-hide immunity ("one auto-hide per reel ever"); a restored reel keeps counting reports for audit but can only leave `published` via explicit admin action.
- **Visibility:** one filter — `status:'published' OR creatorId==viewer` — hides `pending/rejected/hidden` from everyone but the owner (who sees badges: "Processing" / "Under review" / "Removed"). Non-owner fetch of a non-published reel → 404. Report count is **never** serialized to non-owner DTOs.

**Why:** UGC + App Store compliance demands *zero unmoderated public exposure* (fail-closed) plus a *community* backstop (crowd reports) that can't be weaponized (rate limit + idempotent unique reporter + admin immunity).

---

## Pillar 5 — Feed, Playback & Social (incl. Flutter search)

**Zero-latency playback** (`reels_player_pool.dart`): a strict sliding window of **3 live `media_kit` players — `{current-1, current, current+1}`** (8MB buffer each), evict-before-create so memory is bounded regardless of session length. All player ops are **fire-and-forget** so a swipe never blocks on video I/O. On top, `reels_prefetch_service.dart` fires a **1MB HTTP Range request for N+2** to warm DNS/TLS/CDN before its player is even created.

> Nuance: it's not "N+1 and N+2 buffered videos" — it's **N±1 fully live/decoding** + **N+2 network-warmed** (a lighter, cheaper tier). That precision lands better than the brief's version.

**Feeds:**

- **For You** (`GET /api/reels`): two-leg merge — global catalog + reposts by (followees ∪ self) ordered by repost recency — deduped one-instance-per-reel, block-filtered on both the creator edge *and* the reposter edge, opaque packed cursor.
- **Following** (`GET /api/reels/following`): followees' **original** reels only, no reposts, finite.
- Flutter runs **one `ReelsFeedBloc` per tab** (not one re-scoped bloc) so each tab keeps its own scroll position + cursor and switching is instant.

**Reposts:** explicit `POST`/`DELETE /:id/repost` (separate verbs, *not* a toggle), unique `{videoId, reposterId}`, no counter, no notification, surfaced as a non-tappable "[Name] reposted" badge above the creator header.

**Dynamic mentions:** parsed at write, resolved to existing users, stored as subdocs, **notified once at publish**. The compose-time `@` autocomplete overlay (`OverlayPortal`) fetches your followed users **once per screen visit** and filters **in memory** — it never hits the network per keystroke and never blocks typing.

**Flutter search** (`search_cubit.dart`): **350ms debounce**, runs **reels (hashtag substring)** and **users (name/username substring)** searches **in parallel**, drops stale responses via a monotonic **query token**, and degrades gracefully (empty results, not an error, unless *both* legs fail). Backend `searchReels`/`searchUsers` are block-filtered and status-filtered server-side.

---

## Quick answers to the questions they *will* ask

- **"Is this a microservice?"** → No — modular monolith, one Mongo, shared JWT. The `ReelsRepository` interface + `ModerationProvider` abstraction are the extraction seams if/when we split it out.
- **"How do you keep user data consistent across services?"** → We don't need to — single shared datastore, read-time join, strong consistency. Denormalization + event sync is the plan *only if* we extract reels into its own DB.
- **"What's your multi-tenancy story?"** → Single-tenant today. If we needed tenancy we'd add an `appId` discriminator on the shared collections and scope it in the guard — but nothing in the current code assumes it, so I won't claim it.
- **"What if moderation is down?"** → Fail-closed: nothing publishes without an explicit clean verdict; jobs retry then wait for a sweep.
- **"Trust the client on video length/format?"** → No — server re-derives duration from the MP4 atoms and re-guarantees faststart independently.

---

## Key file map

**Backend** (`chat-app-backend/src/modules/reels/`)
- `reels.controller.ts` — upload, duration parse, `remuxFaststart`, route ordering
- `reels.service.ts` — orchestration, block-set, notifications
- `reels-db.repository.ts` — Mongo access, creator batch-join, feed/search queries
- `reels-moderation.processor.ts` — BullMQ worker
- `moderation/sightengine.provider.ts` — video + text moderation
- `schemas/reel.schema.ts` — status state machine, counters, indexes

**Flutter** (`lib/features/reels/`)
- `presentation/services/reel_video_export.dart` — client FFmpeg normalize + safe-path copy
- `presentation/services/reels_player_pool.dart` — 3-player sliding window
- `data/datasources/reels_prefetch_service.dart` — N+2 range warm-up
- `presentation/bloc/search_cubit.dart` — debounced parallel search
- `presentation/bloc/reels_feed_bloc.dart` — per-tab feed
