# API Contracts: Reels / Short Videos Feed

**Feature**: `021-reels-video-feed` | **Date**: 2026-07-02 (v2 — endpoints 13–19 added; ReelDto extended; block filtering applies to every read) / 2026-07-03 (v3 — endpoints 21–24: upload, delete, moderation pipeline, `reelRejected` push; `ReelDto.status`; visibility filter on every read)

**v3 cross-cutting rules**:
- **Visibility filter (FR-061)**: every read endpoint serves only `status: 'published'` reels — EXCEPT when the caller is the reel's creator, who also sees their own `pending_moderation`/`rejected` reels (single fetch + own profile grid). Non-owner fetch of a non-published reel → `404` (identical to unknown — deep links follow FR-043).
- **`ReelDto` gains `status`** (`"pending_moderation" | "published" | "rejected"`): always present; non-published reels only ever reach their owner.
- **Engagement writes require `published`**: like/comment/share/save/view on a non-published reel → `404` (FR-064).

All endpoints require `Authorization: Bearer <accessToken>` (`JwtAuthGuard`); the caller is `req.user.userId`. Media URLs may be relative — clients MUST resolve via `UrlUtils.resolveMediaUrl`.

**v2 cross-cutting rules**:
- **Block filtering (FR-052/053)**: every read endpoint excludes content from users in the caller's mutual block set (caller's `blockedUsers` ∪ users who blocked the caller). Blocked single-reel/profile fetches return `404` (indistinguishable from unknown — deep links then follow FR-043).
- **`ReelDto` extended** (applies to every endpoint returning reels): `+ description` (string), `+ hashtags` (string[]), `+ mentions` (`[{userId, username}]`), `+ viewsCount` (number), `+ viewerSaved` (bool); `creator` gains `username`.
- **NestJS route order**: static GET routes (`/liked`, `/saved`, `/search`) are declared **before** `/:id` in `ReelsController`.

**Response envelope (discovered during implementation)**: the backend's `GlobalResponseInterceptor` wraps every controller return value as `{ success: true, message: string, data: T }`, and `GlobalExceptionFilter` wraps errors as `{ success: false, error, message, statusCode }`. The JSON bodies below (endpoints 1–8) are the `data` payload — Flutter datasource calls MUST unwrap `response.data['data']`. The only exception is endpoint 10 (store-redirect page), which bypasses the envelope entirely via `@Res()` and returns raw HTML.

## 1. GET `/api/reels` — paginated video feed

**Query**: `cursor` (optional, opaque — last item id of the previous page), `limit` (optional, default 10, max 25)

**200 Response**:

```json
{
  "items": [
    {
      "id": "reel-17",
      "videoUrl": "https://.../BigBuckBunny.mp4",
      "thumbnailUrl": "/uploads/reels/thumbs/reel-17.jpg",
      "createdAt": "2026-06-30T14:05:00.000Z",
      "creator": {
        "id": "mock-user-3",
        "name": "Lina K",
        "avatarUrl": "/uploads/reels/avatars/lina.jpg",
        "viewerFollowing": false
      },
      "description": "Golden hour over the Nile 🌅 #travel #cairo with @omar",
      "hashtags": ["travel", "cairo"],
      "mentions": [{ "userId": "u-omar", "username": "omar" }],
      "viewsCount": 15400,
      "likesCount": 1240,
      "commentsCount": 87,
      "sharesCount": 12,
      "viewerLiked": true,
      "viewerSaved": false
    }
  ],
  "nextCursor": "reel-24"
}
```

`nextCursor: null` → end of feed. Unknown `cursor` → `400`.

**Query variants** (same response shape, finite, newest-first, `nextCursor: null` terminated):
- `?creatorId=<id>` — creator-scoped feed (v1)
- `?hashtag=<tag>` — hashtag feed (v2, FR-047a): exact match on the normalized tag (no `#`), case-insensitive

## 2. GET `/api/reels/:id` — single reel (deep links)

Fetches one reel by id for deep-link entry (`https://ciro.chat/reels/<id>` → app route `/reels/:id`).

**200 Response**: a single `ReelDto` (same shape as feed items).

**Errors**: `404` unknown/deleted reel → client shows friendly error and falls back to the regular feed (FR-043).

## 3. POST `/api/reels/:id/like` — toggle like

**Body**: none (toggle semantics)

**200 Response**: `{ "liked": true, "likesCount": 1241 }`

**Errors**: `404` unknown reel. Rapid repeat calls are safe: each call flips persisted state and returns the resulting truth; client reconciles to the last response.

## 4. GET `/api/reels/:id/comments` — fetch comments

**Query**: `cursor` (optional), `limit` (default 20)

**200 Response**:

```json
{
  "items": [
    {
      "id": "c-901",
      "authorId": "mock-user-5",
      "authorName": "Omar",
      "authorAvatarUrl": "/uploads/reels/avatars/omar.jpg",
      "text": "This is amazing 🔥",
      "createdAt": "2026-07-01T10:12:00.000Z"
    }
  ],
  "nextCursor": null,
  "commentsCount": 87
}
```

Ordering: newest first. **Errors**: `404` unknown reel.

## 5. POST `/api/reels/:id/comments` — add comment

**Body**: `{ "text": "Nice edit!" }` — trimmed, 1–500 chars (`400` otherwise)

**201 Response**:

```json
{
  "comment": {
    "id": "c-902",
    "authorId": "<callerId>",
    "authorName": "<caller name>",
    "authorAvatarUrl": "...",
    "text": "Nice edit!",
    "createdAt": "2026-07-02T09:00:00.000Z"
  },
  "commentsCount": 88
}
```

**Errors**: `404` unknown reel, `400` empty/too-long text.

## 6. POST `/api/reels/:id/share` — record a share event

Called only when the user sends the reel to a chat in-app or taps Copy Link (NOT on share-sheet open/dismiss or native-sheet shares).

**Body**: none

**200 Response**: `{ "sharesCount": 13 }`

**Errors**: `404` unknown reel. Each call appends one share event (no toggle semantics).

## 7. GET `/api/users/:id/profile` — creator profile + video grid

**200 Response**:

```json
{
  "user": {
    "id": "mock-user-3",
    "name": "Lina K",
    "avatarUrl": "/uploads/reels/avatars/lina.jpg",
    "bio": "Filmmaker. Cairo → Berlin."
  },
  "stats": { "followers": 5230, "following": 180, "totalLikes": 89000 },
  "videos": [
    { "id": "reel-17", "thumbnailUrl": "/uploads/reels/thumbs/reel-17.jpg" }
  ],
  "viewer": { "following": true, "isSelf": false }
}
```

`videos` ordered `createdAt` desc (grid order = feed order for creator-scoped feed). **Errors**: `404` unknown user.

## 8. POST `/api/users/:id/follow` — toggle follow

**Body**: none (toggle semantics)

**200 Response**: `{ "following": true, "followersCount": 5231 }`

**Errors**: `404` unknown user; `400` `{ "message": "Cannot follow yourself" }` when `:id == callerId` (FR-031).

## 9. Feed looping (clarified 2026-07-02)

When `GET /api/reels` exhausts the catalog, the mock store cycles back to the start with a namespaced cursor (e.g., `cycle2:reel-3`) so `nextCursor` is never `null` on the main feed. The creator-scoped variant (`creatorId` param) stays finite and does terminate with `nextCursor: null`.

## 10. GET `/reels/:id` — store-redirect fallback page (public, no auth)

Browser-facing route (NOT under `/api`) for reel links opened without the app. Returns a minimal HTML page that redirects by user agent: iOS → App Store listing, Android → Google Play listing, other → basic page linking both stores. Store URLs come from backend config/env (placeholders until the app is published). Must be excluded from `JwtAuthGuard`.

## 11. Reel-share chat message (existing chat pipeline, new subtype)

In-app sharing does not add a REST endpoint — it sends a message through the existing chat send flow with:

```json
{
  "type": "reelShare",
  "content": "https://ciro.chat/reels/reel-17",
  "metadata": {
    "reelId": "reel-17",
    "thumbnailUrl": "/uploads/reels/thumbs/reel-17.jpg",
    "creatorName": "Lina K",
    "deepLink": "https://ciro.chat/reels/reel-17"
  }
}
```

Clients render this as a rich preview card (thumbnail, creator name, play badge); tap → in-app `/reels/:id`. Older/unknown clients can fall back to showing `content` as a tappable link. Delivery/status/offline-queue semantics are the standard message rules (constitution IX), unchanged.

## 12. Creator-scoped feed (derived, no new endpoint)

The creator feed (grid tap → vertical feed starting at video X) is served client-side from `GET /api/users/:id/profile` `videos` + per-item hydration from the already-fetched profile payload; full `ReelDto`s for a creator can be obtained via `GET /api/reels?creatorId=<id>` (optional query param on endpoint 1, same response shape, same pagination).

## Backend module layout (NestJS)

```
src/modules/reels/
├── reels.module.ts
├── reels.controller.ts        # @Controller('api/reels')  — endpoints 1–6
├── reels-users.controller.ts  # @Controller('api/users')  — endpoints 7–8
├── reels-redirect.controller.ts # @Controller('reels')    — endpoint 10 (public store-redirect page)
├── reels.service.ts           # business rules, toggle semantics, validation
├── reels.repository.ts        # abstract ReelsRepository (interface/token)
├── mock/
│   ├── reels-mock.store.ts    # in-memory relational store + query helpers
│   └── reels-seed.ts          # seed users/videos/likes/comments/follows
└── dto/
    ├── feed-query.dto.ts
    └── create-comment.dto.ts
```

Registered in `app.module.ts` as `ReelsModule`. ~~Swapping mock → Mongoose later~~ **v2: the swap happens now** — `reels-db.repository.ts` (Mongoose) replaces the mock binding in `reels.module.ts`; controllers/service and all v1 contracts above stay byte-identical (FR-033).

---

# v2 endpoints (13–19)

## 13. POST `/api/reels/:id/view` — record a view (FR-048)

Called once per reel per session when playback starts. Fire-and-forget client-side.

**Body**: none

**200 Response**: `{ "viewsCount": 15401 }` — deduplicated per user per reel (unique index); repeat calls return the unchanged count.

**Errors**: `404` unknown/blocked reel.

## 14. POST `/api/reels/:id/save` — toggle save/bookmark (FR-049)

**Body**: none (toggle semantics)

**200 Response**: `{ "saved": true }` — no public counter (saves are private).

**Errors**: `404` unknown/blocked reel. Rapid repeats safe (last response wins, unique index prevents drift).

## 15. GET `/api/reels/liked` — caller's Liked Videos (FR-051)

**Query**: `cursor`, `limit` (default 10, max 25)

**200 Response**: `{ items: ReelDto[], nextCursor }` — ordered by like recency (newest like first), owner-only by construction (caller-scoped), block-filtered.

## 16. GET `/api/reels/saved` — caller's Saved Videos (FR-050)

Same shape/rules as 15, ordered by save recency.

## 17. GET `/api/reels/search?q=<string>` — search reels by hashtag (FR-057)

**Query**: `q` (required, trimmed; whitespace-only → `400`), `cursor`, `limit`

**200 Response**: `{ items: ReelDto[], nextCursor }` — reels having ≥1 hashtag containing `q` (case-insensitive substring, regex-escaped), newest first, block-filtered.

## 18. GET `/api/users/search?q=<string>` — search users by name (FR-057)

**Query**: `q` (required), `cursor`, `limit`

**200 Response**:

```json
{
  "items": [
    { "id": "u-3", "username": "lina.k", "name": "Lina K", "avatarUrl": "/uploads/...", "viewerFollowing": false }
  ],
  "nextCursor": null
}
```

Matches `username` OR `name` (case-insensitive substring). Excludes the mutual block set and the caller themself. The Search screen calls 17 + 18 in parallel.

## 19. POST `/api/users/:id/block` — toggle block (FR-052)

Writes the **existing** `User.blockedUsers` array (shared chat+Reels block list).

**Body**: none (toggle semantics)

**200 Response**: `{ "blocked": true }`

**Errors**: `404` unknown user; `400` `{ "message": "Cannot block yourself" }`. Side effect: from the next fetch, all reels surfaces mutually exclude the two parties (FR-053). UI entry point: option on the Creator Profile screen.

## 20. Push notification payloads (no REST endpoint — FCM, FR-054)

Sent via the existing `NotificationsModule` (`PushService`, per-user device tokens) after the `notification_events` row is written. `notification.title/body` are human-readable; clients route on `data`:

| Event | `data.type` | Extra `data` | Tap destination |
|---|---|---|---|
| New follower | `newFollower` | `actorId` | `/reels/creator/:actorId` |
| New like on your reel | `reelLike` | `reelId`, `actorId` | `/reels/:reelId` |
| Mentioned in a description | `reelMention` | `reelId`, `actorId` | `/reels/:reelId` |

No self-events; re-like/re-follow after undo does not re-notify (unique event index). Unreachable device / disabled notifications → event row persists, delivery silently skipped.

---

# v3 endpoints (21–24) — upload & content moderation

## 21. POST `/api/reels` — upload a new reel (FR-060/FR-060a)

**Content-Type**: `multipart/form-data`

| Part | Type | Rules |
|---|---|---|
| `video` | file | required; `video/mp4`, `video/quicktime`, `video/webm`; ≤ 100 MB (Multer cap); ≤ 60 s enforced client-side (camera `maxDuration` / mandatory trimmer) **AND server-side** — container-metadata duration parse, > 61 s (1 s tolerance) or unparseable → `400` (FR-060a) |
| `thumbnail` | file | optional; `image/jpeg`/`image/png` ≤ 2 MB (client extracts first frame during trim/export) |
| `description` | text | optional; trimmed, ≤ 2200 chars; hashtags/mentions parsed server-side at write time (existing util) — **no mention notifications fire here** (FR-063) |

**201 Response**: the owner's `ReelDto` with `"status": "pending_moderation"` (counts 0, `viewerLiked/Saved` false). The reel is immediately visible on the owner's own profile grid with a Processing badge; invisible everywhere else.

**Errors**: `400` wrong type / too large / over-length or unparseable duration / description too long. Any server failure cleans up stored files — **no partial/phantom reel is ever created** (FR-060). The upload response never waits on moderation (FR-062).

**Side effect**: a `reels-moderation` job is enqueued (BullMQ, `jobId = reelId`). If enqueueing fails (Redis down) the upload still succeeds and the pending sweep re-enqueues later — fail-closed, never fail-open.

## 22. DELETE `/api/reels/:id` — owner deletes own reel (FR-067)

Any status (published / pending / rejected). Owner-only.

**200 Response**: `{ "deleted": true }`

**Errors**: `404` unknown reel; `403` caller is not the creator.

**Cascade**: creator `totalLikes -= reel.likesCount` → relation docs (`reel_likes/saves/views/shares/comments`) deleted → reel-scoped `notification_events` deleted → reel doc deleted → media files unlinked. Deep link thereafter → `404` (unknown-reel path); other users' Liked/Saved lists no longer include it. An in-flight moderation job no-ops.

## 23. Moderation pipeline (internal — no REST endpoint)

BullMQ queue **`reels-moderation`** (Redis via existing `REDIS_URL`); payload `{ reelId }`; `attempts: 5`, exponential backoff from 30 s; boot/interval sweep re-enqueues stale `pending_moderation` reels (FR-066 fail-closed).

Processor (`reels-moderation.processor.ts`) → `ModerationProvider.analyze(videoPath, description)`:

| Provider (`MODERATION_PROVIDER` env) | Behavior |
|---|---|
| `sightengine` (production) | video moderation + text moderation via REST; direct multipart upload of the local file; env `SIGHTENGINE_API_USER`/`SIGHTENGINE_API_SECRET` |
| `stub` (dev/tests, default when unset) | verdict `clean` unless filename or description contains the flag marker (`nsfw-test`) — makes reject-path e2e testable offline |

Transitions (guarded `findOneAndUpdate` where `status: 'pending_moderation'` — exactly-once side effects under retries):
- **clean** → `status: 'published'`, `publishedAt: now`; **then** `notifyMentions` fires (FR-063 — the T102 service's live caller), re-checking the uploader↔mentioned-user block relationship at fan-out time (a block created between upload and verdict suppresses that mention). Publication is silent to the uploader (clarified).
- The worker logs verdict latency (upload → verdict) on every transition — SC-018 observability.
- **flagged** (video OR description — clarified) → `status: 'rejected'`; `moderation` subdoc stored (`verdict, flaggedSource, categories, providerRef, completedAt`); media file retained on disk but unreachable via any API (soft delete); `reelRejected` event + push (endpoint 24). No mention notifications ever fire for this reel.
- **provider error/timeout** → job retries; reel stays `pending_moderation`; **a reel is never published without an explicit clean verdict**.

## 24. `reelRejected` push notification (extends endpoint 20's table)

| Event | `data.type` | Extra `data` | Tap destination |
|---|---|---|---|
| Reel removed for policy violation | `reelRejected` | `reelId` | own profile (`/reels/profile/<selfId>`) — rejected reel visible there with its "Removed due to policy violations" badge |

System-originated: `notification_events.actorId = null` (the self-event skip applies only to actor-driven types). Recorded even if push delivery fails (FR-054 semantics). A clean publish sends **no** notification (clarified).

## v3 module layout delta

```
src/modules/reels/
├── reels-moderation.processor.ts   # NEW — BullMQ worker (queue 'reels-moderation')
├── moderation/
│   ├── moderation-provider.ts      # NEW — provider interface + DI token
│   ├── sightengine.provider.ts     # NEW — video + text REST calls
│   └── stub.provider.ts            # NEW — dev/test provider
├── dto/create-reel.dto.ts          # NEW — description validation
├── reels.controller.ts             # + POST / (Multer diskStorage → uploads/reels/), DELETE /:id
├── reels.service.ts                # + visibility filter, publish/reject transitions, delete cascade
└── schemas/reel.schema.ts          # + status, publishedAt, moderation subdoc, revised indexes
```

## v2 module layout delta

```
src/modules/reels/
├── schemas/                        # NEW — 8 Mongoose schemas (see data-model.md ERD)
├── reels-db.repository.ts          # NEW — Mongoose ReelsRepository (replaces mock binding)
├── reels-seed.service.ts           # NEW — idempotent demo seed
├── reels-notifications.service.ts  # NEW — event write + FCM fan-out
├── dto/search-query.dto.ts         # NEW
└── mock/                           # RETIRED after swap
src/modules/users/schemas/user.schema.ts  # + username, bio, followersCount, followingCount, totalLikes
```
